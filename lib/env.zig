const std = @import("std");
const testing = std.testing;

const EnvError = error{
    NotFound,
};

pub const GH_TOKEN = "GH_TOKEN";
pub const GIST_ID = "GIST_ID";

pub fn get(name: []const u8) error{NotFound}![]const u8 {
    const env = std.os.getenv(name);

    if (env == null) {
        return EnvError.NotFound;
    }

    return env.?;
}

test "error - env var does not exist" {
    _ = get("") catch |err| {
        try testing.expect(err == EnvError.NotFound);
    };
}

test "ok - env var does exist" {
    const actual = get("GIST_ID");
    try testing.expect(std.mem.eql(u8, "d0313228583992554c58c626b7df7f2f", try actual));
}
