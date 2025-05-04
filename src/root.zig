const std = @import("std");
const http = std.http;
const json = std.json;
const print = std.debug.print;
const testing = std.testing;

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

    pub fn startChat(self: @This(), allocator: std.mem.Allocator) ChatSession {
        return ChatSession.init(self, allocator);
    }
};

pub const ChatSession = struct {
    model: GenerativeModel,
    allocator: std.mem.Allocator,
    chatHistory: std.ArrayList(*Content),

    pub fn init(model: GenerativeModel, allocator: std.mem.Allocator) @This() {
        return .{
            .model = model,
            .allocator = allocator,
            .chatHistory = std.ArrayList(*Content).init(allocator),
        };
    }

    pub fn deinit(self: @This()) void {
        self.chatHistory.deinit();
    }

    pub fn sendMessage(self: *@This(), msg: []u8) ![]const u8 {
        var parts = try self.allocator.alloc(Part, 1);
        parts[0].text = msg;
        var userContent = try self.allocator.create(Content);
        userContent.role = try self.allocator.dupe(u8, "user");
        userContent.parts = parts;

        try self.chatHistory.append(userContent);

        const reply = try google_api_call(self.allocator, self.chatHistory.items, self.model.ai.key);

        try self.chatHistory.append(reply);
        return reply.parts[0].text;
    }
};

pub const GenerateContentRequest = struct {
    safetySettings: [][]u8,
    generationConfig: GenerationConfig,
    contents: []*Content,
};

pub const Part = struct {
    text: []u8,
};

pub const Content = struct {
    role: []u8,
    parts: []Part,
};

pub const GenerationConfig = struct {};

pub const GenerateContentResponse = struct {
    candidates: []Candidate,
    usageMetadata: UsageMetadata,
    modelVersion: []u8,
};

pub const Candidate = struct {
    content: Content,
    finishReason: []u8,
    avgLogprobs: f32,
};

pub const UsageMetadata = struct {
    promptTokenCount: usize,
    candidatesTokenCount: usize,
    totalTokenCount: usize,
    promptTokensDetails: []TokensDetails,
    candidatesTokensDetails: []TokensDetails,
};

pub const TokensDetails = struct {
    modality: []u8,
    tokenCount: usize,
};

pub fn google_api_call(allocator: std.mem.Allocator, contents: []*Content, api_key: []const u8) !*Content {
    const payload = try mkReq(contents, allocator);
    defer allocator.free(payload);

    const body = try http_api_call(allocator, payload, api_key);
    defer allocator.free(body);

    const t = try json.parseFromSlice(GenerateContentResponse, allocator, body, .{
        .ignore_unknown_fields = true,
    });
    defer t.deinit();

    var copy = try allocator.create(Content);
    copy.role = try allocator.dupe(u8, t.value.candidates[0].content.role);
    copy.parts = try allocator.dupe(Part, t.value.candidates[0].content.parts);
    for (copy.parts, 0..) |p, i| {
        copy.parts[i].text = try allocator.dupe(u8, p.text);
    }

    return copy;
}

pub fn http_api_call(allocator: std.mem.Allocator, payload: []const u8, api_key: []const u8) ![]u8 {
    const http_debug = false;
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent");
    const buf = try allocator.alloc(u8, 1024 * 1024 * 4);
    defer allocator.free(buf);
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
    defer req.deinit();

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
    return try rdr.readAllAlloc(allocator, 1024 * 1024 * 4);
}

pub fn mkReq(contents: []*Content, allocator: std.mem.Allocator) ![]u8 {
    const safetySettings = [0][]u8{};

    const req = GenerateContentRequest{
        .safetySettings = &safetySettings,
        .generationConfig = .{},
        .contents = contents,
    };
    // Serialize JSON
    return try json.stringifyAlloc(allocator, req, .{ .whitespace = .indent_2 });
}
