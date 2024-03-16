const std = @import("std");
const http = std.http;
const log = std.log;
const testing = std.testing;
const time = std.time;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Client = http.Client;
const datetime = @import("datetime");
const env = @import("env");
const zigist_http = @import("http");

const stdout = std.io.getStdOut().writer();

const ZigistError = error{
    FormatFailure,
    MissingEnvironmentVariable,
    ParseFailure,
    Internal,
};

const Joke = struct {
    type: []const u8,

    joke: ?[]const u8 = null,
    setup: ?[]const u8 = null,
    delivery: ?[]const u8 = null,
};

// TODO: refactor more
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

    var payload: []u8 = undefined;

    // convert epoch unix timestamp to datetime
    const dateTime = datetime.timestamp2DateTime(@intCast(time.timestamp()));
    const timestamp = try datetime.dateTime2String(alloc, dateTime);
    defer alloc.free(timestamp); // arena

    // TODO: builder pattern
    if (std.mem.eql(u8, parsedData.type, "single")) {
        var singleJoke: []u8 = undefined;
        if (containsNewLine(parsedData.joke.?)) {
            singleJoke = try substituteNewLines(alloc, parsedData.joke.?);
        } else {
            singleJoke = try splitStringIntoLines(alloc, parsedData.joke.?, false);
        }
        defer alloc.free(singleJoke); // arena

        payload = std.fmt.allocPrint(
            alloc,
            \\ {{
            \\ "files":{{
            \\      "NEWS.md":{{
            \\          "content":"{s}\n\n> {s}"
            \\      }}
            \\ }}
        ,
            .{ singleJoke, timestamp },
        ) catch {
            return ZigistError.FormatFailure;
        };

        log.info("single joke: {?s}\n", .{parsedData.joke});
    } else {
        const jokeSetup = try splitStringIntoLines(alloc, parsedData.setup.?, false);
        const jokeDelivery = try splitStringIntoLines(alloc, parsedData.delivery.?, true);
        defer alloc.free(jokeSetup); // arena
        defer alloc.free(jokeDelivery); // arena

        payload = std.fmt.allocPrint(
            alloc,
            \\ {{
            \\ "files":{{
            \\      "NEWS.md":{{
            \\          "content":"{s}\n* {s}\n\n> {s}"
            \\      }}
            \\ }}
        ,
            .{ jokeSetup, jokeDelivery, timestamp },
        ) catch {
            return ZigistError.FormatFailure;
        };

        log.info("setup: {?s}\n", .{parsedData.setup.?});
        log.info("delivery: {?s}\n", .{parsedData.delivery.?});
    }
    defer alloc.free(payload); // arena
    // TODO: print/render funcs
    try stdout.print("\n\npayload: {s}\n\n", .{payload});

    const resp = try client.putGist(alloc, gist_id, token, payload);

    try stdout.print("\n\n", .{});
    if (resp.status == http.Status.ok) {
        log.info("gist updated successfully: {u}\n", .{resp.status});
    } else {
        log.err("something went wrong: {u}\n", .{resp.status});
        log.err("response: reason: {s}\n", .{resp.reason});
        return ZigistError.Internal;
    }
}

// TODO: naming
fn substituteNewLines(alloc: Allocator, s: []const u8) ![]u8 {
    var list = std.ArrayList(u8).init(alloc);
    defer list.deinit();

    for (s) |c| {
        if (c == 34) {
            try list.append('\\');
        }
        if (c == '\n') {
            try list.append('\\');
            try list.append('n');
            continue;
        } else {
            try list.append(c);
        }
    }

    return list.toOwnedSlice();
}

// TODO: naming
fn splitStringIntoLines(alloc: Allocator, s: []const u8, punchline: bool) ![]u8 {
    var list = std.ArrayList(u8).init(alloc);
    defer list.deinit();

    var count: u32 = 0;
    for (s) |c| {
        if (c == 34) {
            try list.append('\\');
        }
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

fn containsNewLine(input: []const u8) bool {
    var containsNewL = false;
    var index: usize = 0;
    while (index < input.len) {
        if (input[index] == '\n') {
            containsNewL = true;
            break;
        }
        index += 1;
    }
    return containsNewL;
}

test "ok - substituteNewLines" {
    var alloc = testing.allocator;
    const joke =
        \\a string
        \\with
        \\new
        \\line characters
    ;

    const exp = try substituteNewLines(alloc, joke);
    defer alloc.free(exp);

    try testing.expect(std.mem.eql(u8, "a string\\nwith\\nnew\\nline characters", exp));
}

test "ok - splitStringIntoLines punchline" {
    var alloc = testing.allocator;
    const punchline = "a really really long punchline that needs to be split";

    const exp = try splitStringIntoLines(alloc, punchline, true);
    defer alloc.free(exp);

    try testing.expect(std.mem.eql(u8, "a really really long punchline that needs  \\n  to be split", exp));

    const punchline2 = "a really really long punchline that needs to be split multiple times, not only once ...crazy isn't it?";

    const exp2 = try splitStringIntoLines(alloc, punchline2, true);
    defer alloc.free(exp2);

    try testing.expect(std.mem.eql(u8, "a really really long punchline that needs  \\n  to be split multiple times, not only  \\n  once ...crazy isn't it?", exp2));
}

test "ok - splitStringIntoLines question" {
    var alloc = testing.allocator;

    const res = try splitStringIntoLines(alloc, "a really really totally crazy long sentence that needs to be split in multiple lines", false);
    defer alloc.free(res);

    try testing.expect(std.mem.eql(u8, "a really really totally crazy long sentence  \\nthat needs to be split in multiple lines", res));
}
