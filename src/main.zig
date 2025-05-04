const std = @import("std");
const testing = std.testing;
const print = std.debug.print;
const lib = @import("google-generative-ai-zig_lib");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = std.process.getEnvVarOwned(allocator, "API_KEY") catch |err| {
        std.debug.panic("env var API_KEY must be set", .{});
        return err;
    };
    defer allocator.free(api_key);

    const genAI = lib.GoogleGenerativeAI.init(api_key);
    const model = genAI.getGenerativeModel("gemini-2.0-flash");

    var session = model.startChat(allocator);
    defer session.deinit();

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    while (true) {
        try stdout.writeAll("Enter a line of text: ");

        const msg = try stdin.readUntilDelimiterAlloc(allocator, '\n', 1024);

        const resp = try session.sendMessage(msg);
        print("{s}\n", .{resp});
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
}

test "fuzz example" {
    const global = struct {
        fn testOne(input: []const u8) anyerror!void {
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(global.testOne, .{});
}
