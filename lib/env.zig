const std = @import("std");
const testing = std.testing;

/// EnvError represents a not found error for an environment variable.
const EnvError = error{
    NotFound,
};

/// GH_TOKEN fetches the environment variable for the github token.
pub const GH_TOKEN = "GH_TOKEN";
/// GIST_ID fetches the environment variable for the github gist id.
pub const GIST_ID = "GIST_ID";

/// get fetches an environment variable by given name.
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

// TODO: find a way to make this independent of hard coded gist id
// std.os.setenv?
test "ok - env var does exist" {
    const actual = get("GIST_ID");
    try testing.expect(std.mem.eql(u8, "e35b7dfc8ec2c958a7f8f0c9938ffd60", try actual));
}
