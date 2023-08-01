const std = @import("std");
const http = std.http;
const time = std.time;
const Allocator = std.mem.Allocator;
const Client = http.Client;

// TODO: refactor
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    // get token and gist id from env
    const token = std.os.getenv("GH_TOKEN") orelse "";
    const gist_id = std.os.getenv("GIST_ID") orelse "";

    // our http client, this can make multiple requests (and is even threadsafe, although individual requests are not).
    var client = Client{ .allocator = alloc };

    // GET JOKE REQ
    const joke_location = "https://backend-omega-seven.vercel.app/api/getjoke";
    const joke_uri = try std.Uri.parse(joke_location);

    // these are the headers we'll be sending to the server
    var joke_headers = http.Headers{ .allocator = alloc };
    try joke_headers.append("accept", "*/*");
    defer joke_headers.deinit();

    // make the connection and set up the request
    var joke_req = try client.request(.GET, joke_uri, joke_headers, .{});
    defer joke_req.deinit();

    // send the request and headers to the server.
    try joke_req.start();
    // wait for the server to send a response
    try joke_req.wait();

    // read the entire response body, but only allow it to allocate 8kb of memory
    const body = joke_req.reader().readAllAlloc(alloc, 8192) catch unreachable;
    defer alloc.free(body);

    const parsedData = try std.json.parseFromSlice([]Joke, alloc, body, .{});
    defer alloc.free(parsedData);
    const question = try std.fmt.allocPrint(alloc, "{s}", .{parsedData[0].question});
    defer alloc.free(question);
    const punchline = try std.fmt.allocPrint(alloc, "{s}", .{parsedData[0].punchline});
    defer alloc.free(punchline);

    // UPDATE GIST REQ

    // build the uri with the gist_id
    //
    // for reference:
    //      https://docs.github.com/en/rest/gists/gists?apiVersion=2022-11-28#update-a-gist
    const location = try std.fmt.allocPrint(alloc, "https://api.github.com/gists/{s}", .{gist_id});
    defer alloc.free(location);
    const uri = try std.Uri.parse(location);

    // build the bearer string for the authorization header
    const bearer = try std.fmt.allocPrint(alloc, "Bearer {s}", .{token});
    defer alloc.free(bearer);

    // these are the headers we'll be sending to the server
    var headers = http.Headers{ .allocator = alloc };
    try headers.append("accept", "*/*");
    try headers.append("authorization", bearer);
    defer headers.deinit();

    // make the connection and set up the request
    var req = try client.request(.PATCH, uri, headers, .{});
    defer req.deinit();

    req.transfer_encoding = .chunked;

    // send the request and headers to the server.
    try req.start();

    // TODO: convert epoch unix timestamp to datetime
    // TODO: create struct and use json.stringify
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
    defer alloc.free(payload);

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

const Joke = struct {
    question: []const u8,
    punchline: []const u8,
};

// TODO: test
