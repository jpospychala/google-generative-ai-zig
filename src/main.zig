const std = @import("std");
const testing = std.testing;
const print = std.debug.print;
const lib = @import("google-generative-ai-zig_lib");

// Example usage of google-gemini-ai in zig
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
