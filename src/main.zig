const std = @import("std");
const http = std.http;
const log = std.log;
const testing = std.testing;
const time = std.time;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Client = http.Client;

const ZigistError = error{
    MissingEnvironmentVariable,
};

const Joke = struct {
    question: []const u8,
    punchline: []const u8,
};

// TODO: refactor more
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

    var headers = http.Headers{ .allocator = alloc };
    try headers.append("accept", "*/*");

    // make the connection and set up the request
    var joke_req = try client.request(http.Method.GET, joke_uri, headers, .{});

    // send the request and headers to the server.
    try joke_req.start();
    // wait for the server to send a response
    try joke_req.wait();

    // read the entire response body, but only allow it to allocate 8kb of memory
    const body = joke_req.reader().readAllAlloc(alloc, 8192) catch unreachable;
    defer alloc.free(body);

    const parsedData = try std.json.parseFromSliceLeaky([]Joke, alloc, body, .{});
    var question = try std.fmt.allocPrint(alloc, "{s}", .{parsedData[0].question});
    var punchline = try std.fmt.allocPrint(alloc, "{s}", .{parsedData[0].punchline});

    // split into smaller parts
    question = try Conv(alloc, question, false);
    punchline = try Conv(alloc, punchline, true);

    // UPDATE GIST REQ

    // build the uri with the gist_id
    //
    // for reference:
    //      https://docs.github.com/en/rest/gists/gists?apiVersion=2022-11-28#update-a-gist
    const location = try std.fmt.allocPrint(alloc, "https://api.github.com/gists/{s}", .{gist_id});
    const uri = try std.Uri.parse(location);

    // build the bearer string for the authorization header
    const bearer = try std.fmt.allocPrint(alloc, "Bearer {s}", .{token});

    headers = http.Headers{ .allocator = alloc };
    try headers.append("accept", "*/*");
    try headers.append("authorization", bearer);

    // make the connection and set up the request
    var req = try client.request(.PATCH, uri, headers, .{});

    req.transfer_encoding = .chunked;

    // send the request and headers to the server.
    try req.start();

    // TODO: convert epoch unix timestamp to datetime
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
        log.info("gist updated successfully: {u}", .{req.response.status});
    } else {
        log.info("something went wrong: {u}", .{req.response.status});
    }
}

fn Conv(alloc: Allocator, s: []u8, punchline: bool) ![]u8 {
    var list = std.ArrayList(u8).init(alloc);
    defer list.deinit();

    var count: u32 = 0;
    for (s) |c| {
        if (c == 32 and count > 35) {
            try list.append(' ');
            try list.append(' ');
            try list.append('\\');
            try list.append('n');
            if (punchline) {
                try list.append(' ');
                try list.append(' ');
            }
            count = 0;
        } else {
            try list.append(c);
            count += 1;
        }
    }

    return list.toOwnedSlice();
}

fn Getenv(name: []const u8) error{MissingEnvironmentVariable}![]const u8 {
    var env = std.os.getenv(name);

    if (env == null) {
        return ZigistError.MissingEnvironmentVariable;
    }

    return env.?;
}

test "ok - conv punchline" {
    var alloc = testing.allocator;
    const punchline = try std.fmt.allocPrint(alloc, "a really really long punchline that needs to be split", .{});
    defer alloc.free(punchline);

    const exp = try Conv(alloc, punchline, true);
    defer alloc.free(exp);

    try testing.expect(std.mem.eql(u8, "a really really long punchline that needs  \\n  to be split", exp));

    const punchline2 = try std.fmt.allocPrint(alloc, "a really really long punchline that needs to be split multiple times, not only once ...crazy isn't it?", .{});
    defer alloc.free(punchline2);

    const exp2 = try Conv(alloc, punchline2, true);
    defer alloc.free(exp2);

    try testing.expect(std.mem.eql(u8, "a really really long punchline that needs  \\n  to be split multiple times, not only  \\n  once ...crazy isn't it?", exp2));
}

// XXX: create test string/slice without allocPrint
test "ok - conv question" {
    var alloc = testing.allocator;
    const question = try std.fmt.allocPrint(alloc, "a really really totally crazy long sentence that needs to be split in multiple lines", .{});
    defer alloc.free(question);

    const res = try Conv(alloc, question, false);
    defer alloc.free(res);

    try testing.expect(std.mem.eql(u8, "a really really totally crazy long sentence  \\nthat needs to be split in multiple lines", res));
}

test "error - env var does not exist" {
    _ = Getenv("") catch |err| {
        try testing.expect(err == ZigistError.MissingEnvironmentVariable);
    };
}

test "ok - env var does exist" {
    const actual = Getenv("GIST_ID");
    try testing.expect(std.mem.eql(u8, "d0313228583992554c58c626b7df7f2f", try actual));
}
