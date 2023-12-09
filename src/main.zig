const std = @import("std");
const http = std.http;
const time = std.time;
const Allocator = std.mem.Allocator;
const Client = http.Client;

const ZigistError = error{
    MissingEnvironmentVariable,
};

const Joke = struct {
    question: []const u8,
    punchline: []const u8,
};

// TODO: refactor
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    // get token and gist id from env vars
    const token = Getenv("GH_TOKEN") catch |err| {
        return err;
    };
    const gist_id = Getenv("GIST_ID") catch |err| {
        return err;
    };

    var client = Client{ .allocator = alloc };

    // GET JOKE REQ
    const joke_location = "https://backend-omega-seven.vercel.app/api/getjoke";
    const joke_uri = try std.Uri.parse(joke_location);

    var joke_headers = http.Headers{ .allocator = alloc };
    try joke_headers.append("accept", "*/*");

    // make the connection and set up the request
    var joke_req = try client.request(http.Method.GET, joke_uri, joke_headers, .{});

    // send the request and headers to the server.
    try joke_req.start();
    // wait for the server to send a response
    try joke_req.wait();

    // read the entire response body, but only allow it to allocate 8kb of memory
    const body = joke_req.reader().readAllAlloc(alloc, 8192) catch unreachable;
    defer alloc.free(body);

    const parsedData = try std.json.parseFromSlice([]Joke, alloc, body, .{});
    const question = try std.fmt.allocPrint(alloc, "{s}", .{parsedData.value[0].question});
    const punchline = try std.fmt.allocPrint(alloc, "{s}", .{parsedData.value[0].punchline});

    // UPDATE GIST REQ

    // build the uri with the gist_id
    //
    // for reference:
    //      https://docs.github.com/en/rest/gists/gists?apiVersion=2022-11-28#update-a-gist
    const location = try std.fmt.allocPrint(alloc, "https://api.github.com/gists/{s}", .{gist_id});
    const uri = try std.Uri.parse(location);

    // build the bearer string for the authorization header
    const bearer = try std.fmt.allocPrint(alloc, "Bearer {s}", .{token});

    var headers = http.Headers{ .allocator = alloc };
    try headers.append("accept", "*/*");
    try headers.append("authorization", bearer);

    // make the connection and set up the request
    var req = try client.request(.PATCH, uri, headers, .{});

    req.transfer_encoding = .chunked;

    // send the request and headers to the server.
    try req.start();

    // TODO: convert epoch unix timestamp to datetime
    // TODO: split at 40 chars (do not make line longer than 40 chars)
    var payload = std.fmt.allocPrint(
        alloc,
        \\ {{
        \\ "files":{{
        \\      "NEWS.md":{{
        \\          "content":"# Random dev joke\n{s}\n* {s}\n\n> unix ts {d}"
        \\      }}
        \\ }}
    ,
        .{ question, punchline, time.timestamp() },
    ) catch "format failed";

    try req.writer().writeAll(payload);
    try req.finish();

    // wait for the server to send a response
    try req.wait();

    if (req.response.status == http.Status.ok) {
        std.debug.print("gist updated successfully: {u}", .{req.response.status});
    } else {
        std.debug.print("something went wrong: {u}", .{req.response.status});
    }
}

fn Getenv(name: []const u8) error{MissingEnvironmentVariable}![]const u8 {
    var env = std.os.getenv(name);

    if (env == null) {
        return ZigistError.MissingEnvironmentVariable;
    }

    return env.?;
}

test "error - env var does not exist" {
    _ = Getenv("") catch |err| {
        try std.testing.expect(err == ZigistError.MissingEnvironmentVariable);
        return;
    };
}

test "ok - env var does exist" {
    const actual = Getenv("GIST_ID");
    try std.testing.expect(std.mem.eql(u8, "d0313228583992554c58c626b7df7f2f", try actual));
}
