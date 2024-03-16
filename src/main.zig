const std = @import("std");
const http = std.http;
const log = std.log;
const time = std.time;
const Allocator = std.mem.Allocator;
const datetime = @import("datetime");
const env = @import("env");
const zigist_http = @import("http");
const payload = @import("payload");
const Joke = payload.Joke;

const stdout = std.io.getStdOut().writer();

const ZigistError = error{
    Internal,
};

pub fn main() !void {
    // https://ziglang.org/documentation/master/#Choosing-an-Allocator
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    // const alloc = arena.allocator();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const token = env.get(env.GH_TOKEN) catch |err| {
        log.err("environment variable GH_TOKEN not found", .{});
        return err;
    };
    const gist_id = env.get(env.GIST_ID) catch |err| {
        log.err("environment variable GIST_ID not found", .{});
        return err;
    };

    var client = zigist_http.Client.init(alloc);
    defer client.deinit(); // arena

    const body = client.getJoke(alloc) catch |err| {
        log.err("request could not be finished", .{});
        return err;
    };

    defer alloc.free(body); // arena

    const joke = try std.json.parseFromSlice(Joke, alloc, body, .{ .ignore_unknown_fields = true });
    defer joke.deinit(); // arena

    const parsedData = joke.value;

    var p: []u8 = undefined;

    // convert epoch unix timestamp to datetime
    const dateTime = datetime.timestamp2DateTime(@intCast(time.timestamp()));
    const timestamp = try datetime.dateTime2String(alloc, dateTime);
    defer alloc.free(timestamp); // arena

    if (std.mem.eql(u8, parsedData.type, "single")) {
        p = payload.payloadFromTypeSingle(alloc, parsedData, timestamp) catch |err| {
            log.err("problem while parsing payload", .{});
            return err;
        };

        log.info("single joke: {?s}\n", .{parsedData.joke});
    } else {
        p = payload.payloadFromTypeTwopart(alloc, parsedData, timestamp) catch |err| {
            log.err("problem by parsing payload", .{});
            return err;
        };

        log.info("setup: {?s}\n", .{parsedData.setup.?});
        log.info("delivery: {?s}\n", .{parsedData.delivery.?});
    }
    defer alloc.free(p); // arena

    // TODO: print/render funcs
    try stdout.print("\n\npayload: {s}\n\n", .{p});

    const resp = try client.putGist(alloc, gist_id, token, p);

    try stdout.print("\n\n", .{});
    if (resp.status == http.Status.ok) {
        log.info("gist updated successfully: {u}\n", .{resp.status});
    } else {
        log.err("something went wrong: {u}\n", .{resp.status});
        log.err("response: reason: {s}\n", .{resp.reason});
        return ZigistError.Internal;
    }
}
