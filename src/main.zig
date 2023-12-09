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
    //
    // for reference:
    //      https://documenter.getpostman.com/view/16443297/TzkyLee7#c55ef73d-6983-4528-97d0-eb62af3c45b6
    const joke_location = "https://backend-omega-seven.vercel.app/api/getjoke";
    const joke_uri = try std.Uri.parse(joke_location);

    var headers = http.Headers{ .allocator = alloc };
    try headers.append("accept", "*/*");

    // make the connection and set up the request
    var joke_req = try client.request(http.Method.GET, joke_uri, headers, .{});

    // send the request and headers to the server.
    try joke_req.start(http.Client.Request.StartOptions{});
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
    try req.start(http.Client.Request.StartOptions{});

    // convert epoch unix timestamp to datetime
    const dateTime = timestamp2DateTime(time.timestamp());
    const timestamp = try dateTime2String(alloc, dateTime);

    var payload = std.fmt.allocPrint(
        alloc,
        \\ {{
        \\ "files":{{
        \\      "NEWS.md":{{
        \\          "content":"{s}\n* {s}\n\n> {s}"
        \\      }}
        \\ }}
    ,
        .{ question, punchline, timestamp },
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

// date time handling
// being used to convert a unix timestamp to a datetime struct
const TimeOffset = struct {
    from: i64,
    offset: i16,
};

const timeOffsets_Berlin = [_]TimeOffset{
    TimeOffset{ .from = 2140045200, .offset = 3600 }, // Sun Oct 25 01:00:00 2037
    TimeOffset{ .from = 2121901200, .offset = 7200 }, // Sun Mar 29 01:00:00 2037
    TimeOffset{ .from = 2108595600, .offset = 3600 }, // Sun Oct 26 01:00:00 2036
    TimeOffset{ .from = 2090451600, .offset = 7200 }, // Sun Mar 30 01:00:00 2036
    TimeOffset{ .from = 2077146000, .offset = 3600 }, // Sun Oct 28 01:00:00 2035
    TimeOffset{ .from = 2058397200, .offset = 7200 }, // Sun Mar 25 01:00:00 2035
    TimeOffset{ .from = 2045696400, .offset = 3600 }, // Sun Oct 29 01:00:00 2034
    TimeOffset{ .from = 2026947600, .offset = 7200 }, // Sun Mar 26 01:00:00 2034
    TimeOffset{ .from = 2014246800, .offset = 3600 }, // Sun Oct 30 01:00:00 2033
    TimeOffset{ .from = 1995498000, .offset = 7200 }, // Sun Mar 27 01:00:00 2033
    TimeOffset{ .from = 1982797200, .offset = 3600 }, // Sun Oct 31 01:00:00 2032
    TimeOffset{ .from = 1964048400, .offset = 7200 }, // Sun Mar 28 01:00:00 2032
    TimeOffset{ .from = 1950742800, .offset = 3600 }, // Sun Oct 26 01:00:00 2031
    TimeOffset{ .from = 1932598800, .offset = 7200 }, // Sun Mar 30 01:00:00 2031
    TimeOffset{ .from = 1919293200, .offset = 3600 }, // Sun Oct 27 01:00:00 2030
    TimeOffset{ .from = 1901149200, .offset = 7200 }, // Sun Mar 31 01:00:00 2030
    TimeOffset{ .from = 1887843600, .offset = 3600 }, // Sun Oct 28 01:00:00 2029
    TimeOffset{ .from = 1869094800, .offset = 7200 }, // Sun Mar 25 01:00:00 2029
    TimeOffset{ .from = 1856394000, .offset = 3600 }, // Sun Oct 29 01:00:00 2028
    TimeOffset{ .from = 1837645200, .offset = 7200 }, // Sun Mar 26 01:00:00 2028
    TimeOffset{ .from = 1824944400, .offset = 3600 }, // Sun Oct 31 01:00:00 2027
    TimeOffset{ .from = 1806195600, .offset = 7200 }, // Sun Mar 28 01:00:00 2027
    TimeOffset{ .from = 1792890000, .offset = 3600 }, // Sun Oct 25 01:00:00 2026
    TimeOffset{ .from = 1774746000, .offset = 7200 }, // Sun Mar 29 01:00:00 2026
    TimeOffset{ .from = 1761440400, .offset = 3600 }, // Sun Oct 26 01:00:00 2025
    TimeOffset{ .from = 1743296400, .offset = 7200 }, // Sun Mar 30 01:00:00 2025
    TimeOffset{ .from = 1729990800, .offset = 3600 }, // Sun Oct 27 01:00:00 2024
    TimeOffset{ .from = 1711846800, .offset = 7200 }, // Sun Mar 31 01:00:00 2024
    TimeOffset{ .from = 1698541200, .offset = 3600 }, // Sun Oct 29 01:00:00 2023
    TimeOffset{ .from = 1679792400, .offset = 7200 }, // Sun Mar 26 01:00:00 2023
    TimeOffset{ .from = 1667091600, .offset = 3600 }, // Sun Oct 30 01:00:00 2022
    TimeOffset{ .from = 1648342800, .offset = 7200 }, // Sun Mar 27 01:00:00 2022
    TimeOffset{ .from = 1635642000, .offset = 3600 }, // Sun Oct 31 01:00:00 2021
    TimeOffset{ .from = 1616893200, .offset = 7200 }, // Sun Mar 28 01:00:00 2021
    TimeOffset{ .from = 1603587600, .offset = 3600 }, // Sun Oct 25 01:00:00 2020
    TimeOffset{ .from = 1585443600, .offset = 7200 }, // Sun Mar 29 01:00:00 2020
    TimeOffset{ .from = 1572138000, .offset = 3600 }, // Sun Oct 27 01:00:00 2019
    TimeOffset{ .from = 1553994000, .offset = 7200 }, // Sun Mar 31 01:00:00 2019
    TimeOffset{ .from = 1540688400, .offset = 3600 }, // Sun Oct 28 01:00:00 2018
    TimeOffset{ .from = 1521939600, .offset = 7200 }, // Sun Mar 25 01:00:00 2018
    TimeOffset{ .from = 1509238800, .offset = 3600 }, // Sun Oct 29 01:00:00 2017
    TimeOffset{ .from = 1490490000, .offset = 7200 }, // Sun Mar 26 01:00:00 2017
    TimeOffset{ .from = 1477789200, .offset = 3600 }, // Sun Oct 30 01:00:00 2016
    TimeOffset{ .from = 0, .offset = 3600 }, //
};

pub const DateTime = struct { day: u8, month: u8, year: u16, hour: u8, minute: u8, second: u8 };

/// timestamp2DateTime converts a unix epoch timestamp to a DateTime object.
pub fn timestamp2DateTime(timestamp: i64) DateTime {
    // aus https://de.wikipedia.org/wiki/Unixzeit
    const unixtime: u64 = @intCast(timestamp);
    const SEKUNDEN_PRO_TAG = 86400; //*  24* 60 * 60 */
    const TAGE_IM_GEMEINJAHR = 365; //* kein Schaltjahr */
    const TAGE_IN_4_JAHREN = 1461; //*   4*365 +   1 */
    const TAGE_IN_100_JAHREN = 36524; //* 100*365 +  25 - 1 */
    const TAGE_IN_400_JAHREN = 146097; //* 400*365 + 100 - 4 + 1 */
    const TAGN_AD_1970_01_01 = 719468; //* Tagnummer bezogen auf den 1. Maerz des Jahres "Null" */

    var tagN: u64 = TAGN_AD_1970_01_01 + unixtime / SEKUNDEN_PRO_TAG;
    var sekunden_seit_Mitternacht: u64 = unixtime % SEKUNDEN_PRO_TAG;
    var temp: u64 = 0;

    // Schaltjahrregel des Gregorianischen Kalenders:
    // Jedes durch 100 teilbare Jahr ist kein Schaltjahr, es sei denn, es ist durch 400 teilbar.
    temp = 4 * (tagN + TAGE_IN_100_JAHREN + 1) / TAGE_IN_400_JAHREN - 1;
    var jahr: u16 = @intCast(100 * temp);
    tagN -= TAGE_IN_100_JAHREN * temp + temp / 4;

    // Schaltjahrregel des Julianischen Kalenders:
    // Jedes durch 4 teilbare Jahr ist ein Schaltjahr.
    temp = 4 * (tagN + TAGE_IM_GEMEINJAHR + 1) / TAGE_IN_4_JAHREN - 1;
    jahr += @intCast(temp);
    tagN -= TAGE_IM_GEMEINJAHR * temp + temp / 4;

    // TagN enthaelt jetzt nur noch die Tage des errechneten Jahres bezogen auf den 1. Maerz.
    var monat: u8 = @intCast((5 * tagN + 2) / 153);
    var monatu64: u64 = @intCast(monat);
    var tag: u8 = @intCast(tagN - (monatu64 * 153 + 2) / 5 + 1);
    //  153 = 31+30+31+30+31 Tage fuer die 5 Monate von Maerz bis Juli
    //  153 = 31+30+31+30+31 Tage fuer die 5 Monate von August bis Dezember
    //        31+28          Tage fuer Januar und Februar (siehe unten)
    //  +2: Justierung der Rundung
    //  +1: Der erste Tag im Monat ist 1 (und nicht 0).

    monat += 3; // vom Jahr, das am 1. Maerz beginnt auf unser normales Jahr umrechnen: */
    if (monat > 12) { // Monate 13 und 14 entsprechen 1 (Januar) und 2 (Februar) des naechsten Jahres
        monat -= 12;
        jahr += 1;
    }

    var stunde: u8 = @intCast(sekunden_seit_Mitternacht / 3600);
    var minute: u8 = @intCast(sekunden_seit_Mitternacht % 3600 / 60);
    var sekunde: u8 = @intCast(sekunden_seit_Mitternacht % 60);

    return DateTime{ .day = tag, .month = monat, .year = jahr, .hour = stunde, .minute = minute, .second = sekunde };
}

fn dateTime2String(alloc: Allocator, dt: DateTime) ![]u8 {
    var ts = try std.fmt.allocPrint(alloc, "{d}.{:0<2}.{:0<4} {:0<2}:{:0<2}:{:0<2}", .{ dt.day, dt.month, dt.year, dt.hour, dt.minute, dt.second });
    // defer alloc.free(ts);

    return ts;
}

test "GMT and localtime" {
    // Summer, CEST
    try std.testing.expectEqual(DateTime{ .year = 2020, .month = 8, .day = 28, .hour = 9, .minute = 32, .second = 27 }, timestamp2DateTime(1598607147));

    // Winter, CET
    try std.testing.expectEqual(DateTime{ .year = 2020, .month = 11, .day = 1, .hour = 5, .minute = 6, .second = 7 }, timestamp2DateTime(1604207167));
}
