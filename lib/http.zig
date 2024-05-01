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

        var list = std.ArrayList(u8).init(alloc);
        defer list.deinit();

        const fetch_options = http.Client.FetchOptions{
            .location = .{ .uri = joke_location_uri },
            .response_storage = .{
                .dynamic = &list,
            },
        };
        _ = try self.c.fetch(fetch_options);

        const body = list.toOwnedSlice();

        return body;
    }

    /// putGist performs a put request to update a github gist.
    pub fn putGist(self: *Client, alloc: Allocator, gist_id: []const u8, token: []const u8, payload: []u8) !http.Status {
        const gist_location = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ update_gist_location, gist_id });
        defer alloc.free(gist_location);

        const update_gist_location_uri = try std.Uri.parse(gist_location);
        const bearer = try std.fmt.allocPrint(alloc, "Bearer {s}", .{token});
        defer alloc.free(bearer);

        const headers = http.Client.Request.Headers{
            .authorization = .{ .override = bearer },
        };

        const fetch_options = http.Client.FetchOptions{
            .method = .PATCH,
            .location = .{ .uri = update_gist_location_uri },
            .headers = headers,
            .payload = payload,
        };
        const res = try self.c.fetch(fetch_options);

        return res.status;
    }
};

// TODO: test
