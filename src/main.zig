const std = @import("std");
const http = std.http;
const Client = http.Client;
const time = std.time;
const Allocator = std.mem.Allocator;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const calloc = gpa.allocator();

pub fn main() !void {
    // get token and gist id from env
    const token = std.os.getenv("GH_TOKEN") orelse "";
    const gist_id = std.os.getenv("GIST_ID") orelse "";

    // build the uri with the gist_id
    //
    // for reference:
    //      https://docs.github.com/en/rest/gists/gists?apiVersion=2022-11-28#update-a-gist
    const location = try std.fmt.allocPrint(calloc, "https://api.github.com/gists/{s}", .{gist_id});
    defer calloc.free(location);
    const uri = try std.Uri.parse(location);

    // build the bearer string for the authorization header
    const bearer = try std.fmt.allocPrint(calloc, "Bearer {s}", .{token});
    defer calloc.free(bearer);

    // our http client, this can make multiple requests (and is even threadsafe, although individual requests are not).
    var client = Client{ .allocator = calloc };

    // these are the headers we'll be sending to the server
    var headers = http.Headers{ .allocator = calloc };
    try headers.append("accept", "*/*");
    try headers.append("authorization", bearer);
    defer headers.deinit();

    // make the connection and set up the request
    var req = try client.request(.PATCH, uri, headers, .{});
    defer req.deinit();

    req.transfer_encoding = .chunked;

    // send the request and headers to the server.
    try req.start();

    // build the payload with the help of a config.json file
    const config = try readConfig(calloc, "config.json");
    // TODO: convert epoch unix timestamp to datetime
    var payload = std.fmt.allocPrint(calloc, "{{\"description\":\"ZIGZIG\",\"files\":{{\"NEWS.md\":{{\"content\":\"{s}\\n> unix ts {d}\"}}}}", .{ config.content, time.timestamp() }) catch "format failed";
    defer calloc.free(payload);

    try req.writer().writeAll(payload);
    try req.finish();

    // wait for the server to send a response
    try req.wait();

    std.debug.print("gist updated successfully: {u}", .{req.response.status});
}

fn readConfig(allocator: Allocator, path: []const u8) !Config {
    const data = try std.fs.cwd().readFileAlloc(allocator, path, 512);
    defer allocator.free(data);
    return try std.json.parseFromSlice(Config, allocator, data, .{});
}

const Config = struct {
    content: []const u8,
};

// TODO: test
