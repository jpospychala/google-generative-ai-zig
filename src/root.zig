const std = @import("std");
const http = std.http;
const json = std.json;
const testing = std.testing;
const types = @import("./types.zig");

pub const GoogleGenerativeAI = struct {
    key: []const u8,

    pub fn init(key: []const u8) @This() {
        return .{
            .key = key,
        };
    }

    pub fn getGenerativeModel(self: @This(), name: []const u8) GenerativeModel {
        return GenerativeModel.init(self, name);
    }
};

pub const GenerativeModel = struct {
    ai: GoogleGenerativeAI,
    name: []const u8,

    pub fn init(ai: GoogleGenerativeAI, name: []const u8) @This() {
        return .{
            .ai = ai,
            .name = name,
        };
    }

    pub fn startChat(self: @This(), allocator: std.mem.Allocator) !ChatSession {
        return ChatSession.init(self, allocator);
    }
};

pub const ChatSession = struct {
    model: GenerativeModel,
    arena: *std.heap.ArenaAllocator,
    chatHistory: std.ArrayList(types.Content),

    pub fn init(model: GenerativeModel, allocator: std.mem.Allocator) !@This() {
        const arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        return @This(){
            .model = model,
            .arena = arena,
            .chatHistory = std.ArrayList(types.Content).init(arena.allocator()),
        };
    }

    pub fn deinit(self: *@This()) void {
        const parentAlloc = self.arena.child_allocator;
        self.arena.deinit();
        parentAlloc.destroy(self.arena);
    }

    pub fn sendMessage(self: *@This(), msg: []const u8) ![]const u8 {
        const userContent = types.Content{
            .role = "user",
            .parts = &[_]types.Part{types.Part{
                .text = try self.arena.allocator().dupe(u8, msg),
            }},
        };

        try self.chatHistory.append(userContent);

        const req = types.GenerateContentRequest{
            .safetySettings = &[_][]u8{},
            .generationConfig = .{},
            .contents = self.chatHistory.items,
        };

        const replyP = try google_api_call(self.arena.allocator(), req, self.model, types.GenerateContentResponse);
        const reply = replyP.value;

        try self.chatHistory.append(reply.candidates[0].content);
        return reply.candidates[0].content.parts[0].text;
    }
};

pub fn google_api_call(arena: std.mem.Allocator, req: types.GenerateContentRequest, model: GenerativeModel, T: type) !json.Parsed(T) {
    const payload = try json.stringifyAlloc(arena, req, .{});

    const uriStr = try std.mem.concat(arena, u8, &[_][]const u8{
        "https://generativelanguage.googleapis.com/v1beta/models/",
        model.name,
        ":generateContent",
    });
    const uri = try std.Uri.parse(uriStr);

    const body = try http_api_call(arena, uri, payload, model.ai.key);

    return try json.parseFromSlice(T, arena, body, .{
        .ignore_unknown_fields = true,
    });
}

pub fn http_api_call(arena: std.mem.Allocator, uri: std.Uri, payload: []const u8, api_key: []const u8) ![]u8 {
    const http_debug = false;
    var client = http.Client{ .allocator = arena };

    const buf = try arena.alloc(u8, 1024 * 1024 * 4);
    const headers = [_]http.Header{
        .{ .name = "x-goog-api-client", .value = "genai-js/0.24.0" },
        .{ .name = "x-goog-api-key", .value = api_key },
    };
    var req = try client.open(.POST, uri, .{
        .server_header_buffer = buf,
        .headers = .{
            .content_type = .{ .override = "application/json" },
        },
        .extra_headers = &headers,
    });

    req.transfer_encoding = .{ .content_length = payload.len };

    try req.send();
    var wtr = req.writer();
    try wtr.writeAll(payload);
    try req.finish();
    try req.wait();

    if (http_debug) {
        var iter = req.response.iterateHeaders();
        while (iter.next()) |header| {
            std.debug.print("Name:{s}, Value:{s}\n", .{ header.name, header.value });
        }
    }

    try std.testing.expectEqual(req.response.status, .ok);

    var rdr = req.reader();
    return try rdr.readAllAlloc(arena, 1024 * 1024 * 4);
}

test "Session.sendMessage" {
    const api_key = try std.process.getEnvVarOwned(std.testing.allocator, "API_KEY");
    defer std.testing.allocator.free(api_key);
    const genAI = GoogleGenerativeAI.init(api_key);
    const model = genAI.getGenerativeModel("gemini-2.0-flash");

    var session = try model.startChat(std.testing.allocator);
    defer session.deinit();

    const resp = try session.sendMessage("1+1");
    try std.testing.expectEqualSlices(u8, "2\n", resp);
}
