const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Payload = error{
    InternalError,
};

pub const Joke = struct {
    id: i64,
    type: []const u8,

    setup: []const u8,
    punchline: []const u8,
};

pub fn payloadFromTypeTwopart(alloc: Allocator, parsedData: []Joke, timestamp: []u8) ![]u8 {
    const joke_setup = try splitStringIntoLines(alloc, parsedData[0].setup, false);
    const joke_punchline = try splitStringIntoLines(alloc, parsedData[0].punchline, true);
    defer alloc.free(joke_setup); // arena
    defer alloc.free(joke_punchline); // arena

    const payload = std.fmt.allocPrint(
        alloc,
        \\ {{
        \\ "files":{{
        \\      "NEWS.md":{{
        \\          "content":"{s}\n* {s}\n\n> {s}"
        \\      }}
        \\ }}
    ,
        .{ joke_setup, joke_punchline, timestamp },
    ) catch {
        return Payload.InternalError;
    };

    return payload;
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
    var contains_new_line = false;
    var index: usize = 0;
    while (index < input.len) {
        if (input[index] == '\n') {
            contains_new_line = true;
            break;
        }
        index += 1;
    }
    return contains_new_line;
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
