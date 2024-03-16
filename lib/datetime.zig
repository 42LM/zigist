const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// DateTime represents a simple datetime struct.
pub const DateTime = struct {
    day: u8,
    month: u8,
    year: u16,
    hour: u8,
    minute: u8,
    second: u8,
};

/// timestamp2DateTime converts a unix epoch timestamp to a DateTime object.
pub fn timestamp2DateTime(ts: u64) DateTime {
    const SECONDS_PER_DAY = 86400;
    const DAYS_PER_YEAR = 365;
    const DAYS_IN_4YEARS = 1461;
    const DAYS_IN_100YEARS = 36524;
    const DAYS_IN_400YEARS = 146097;
    const DAYS_BEFORE_EPOCH = 719468;

    const seconds_since_midnight: u64 = @rem(ts, SECONDS_PER_DAY);
    var day_n: u64 = DAYS_BEFORE_EPOCH + ts / SECONDS_PER_DAY;
    var temp: u64 = 0;

    temp = 4 * (day_n + DAYS_IN_100YEARS + 1) / DAYS_IN_400YEARS - 1;
    var year: u16 = @intCast(100 * temp);
    day_n -= DAYS_IN_100YEARS * temp + temp / 4;

    temp = 4 * (day_n + DAYS_PER_YEAR + 1) / DAYS_IN_4YEARS - 1;
    year += @intCast(temp);
    day_n -= DAYS_PER_YEAR * temp + temp / 4;

    var month: u8 = @intCast((5 * day_n + 2) / 153);
    const day: u8 = @intCast(day_n - (@as(u64, @intCast(month)) * 153 + 2) / 5 + 1);

    month += 3;
    if (month > 12) {
        month -= 12;
        year += 1;
    }

    return DateTime{ .year = year, .month = month, .day = day, .hour = @intCast(seconds_since_midnight / 3600), .minute = @intCast(seconds_since_midnight % 3600 / 60), .second = @intCast(seconds_since_midnight % 60) };
}

pub fn dateTime2String(alloc: Allocator, dt: DateTime) ![]u8 {
    const ts = try std.fmt.allocPrint(alloc, "{:0>2}.{:0>2}.{:0>4} {:0>2}:{:0>2}:{:0>2}", .{ dt.day, dt.month, dt.year, dt.hour, dt.minute, dt.second });

    return ts;
}

test "datetime 2 string" {
    const alloc = testing.allocator;
    const actual = try dateTime2String(alloc, DateTime{ .year = 2023, .month = 8, .day = 4, .hour = 9, .minute = 3, .second = 2 });
    defer alloc.free(actual);

    try testing.expectEqualStrings("04.08.2023 09:03:02", actual);
}

test "GMT and localtime" {
    // summer, CEST
    try std.testing.expectEqual(DateTime{ .year = 2020, .month = 8, .day = 28, .hour = 9, .minute = 32, .second = 27 }, timestamp2DateTime(1598607147));

    // winter, CET
    try std.testing.expectEqual(DateTime{ .year = 2020, .month = 11, .day = 1, .hour = 5, .minute = 6, .second = 7 }, timestamp2DateTime(1604207167));
}
