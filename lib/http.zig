const std = @import("std");
const log = std.log;
const http = std.http;
const Allocator = std.mem.Allocator;

/// ClientError represents a client error.
const ClientError = error{
    InternalError,
};

/// Client wraps a zig std lib http client and
/// offers convenience methods to do http requests.
pub const Client = struct {
    c: http.Client,

    // for reference:
    //      https://github.com/15Dkatz/official_joke_api
    const joke_location = "https://official-joke-api.appspot.com/jokes/programming/random";
    // for reference:
    //      https://docs.github.com/en/rest/gists/gists?apiVersion=2022-11-28#update-a-gist
    const update_gist_location = "https://api.github.com/gists";

    pub fn init(alloc: Allocator) Client {
        return Client{ .c = http.Client{ .allocator = alloc } };
    }

    pub fn deinit(self: *Client) void {
        self.c.deinit();
    }

    /// getJoke performs a get request to fetch a joke.
    pub fn getJoke(self: *Client, alloc: Allocator) ![]u8 {
        const joke_location_uri = try std.Uri.parse(joke_location);
        var joke_req = try self.c.request(http.Method.GET, joke_location_uri, std.http.Headers{ .allocator = alloc }, .{});
        defer joke_req.deinit();

        try joke_req.start();
        try joke_req.wait();
        try joke_req.finish();

        // read the entire response body, but only allow it to allocate 8KB of memory
        const body = joke_req.reader().readAllAlloc(alloc, 8192) catch unreachable;
        return body;
    }

    /// putGist performs a put request to update a github gist.
    pub fn putGist(self: *Client, alloc: Allocator, gist_id: []const u8, token: []const u8, payload: []u8) !http.Client.Response {
        const gist_location = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ update_gist_location, gist_id });
        defer alloc.free(gist_location);

        const update_gist_location_uri = try std.Uri.parse(gist_location);
        const bearer = try std.fmt.allocPrint(alloc, "Bearer {s}", .{token});
        defer alloc.free(bearer);

        var headers = http.Headers{ .allocator = alloc };
        try headers.append("authorization", bearer);
        try headers.append("transfer-encoding", "chunked");
        defer headers.deinit();

        var req = try self.c.request(.PATCH, update_gist_location_uri, headers, .{});
        defer req.deinit();

        req.transfer_encoding = .chunked;

        try req.start();

        try req.writer().writeAll(payload);
        try req.finish();

        try req.wait();

        return req.response;
    }
};

// TODO: test
