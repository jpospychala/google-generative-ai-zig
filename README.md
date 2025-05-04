# ZIG API Bindings for Google Generative AI

Library for connecting to Google Gemini from Zig lang.

## Usage

```zig
    const lib = @import("google-generative-ai-zig_lib");

    const genAI = lib.GoogleGenerativeAI.init(api_key);
    const model = genAI.getGenerativeModel("gemini-2.0-flash");

    var session = model.startChat(allocator);

    while (true) {
        try stdout.writeAll("Speak to AI: ");

        const msg = try stdin.readUntilDelimiterAlloc(allocator, '\n', 1024);

        const response = try session.sendMessage(msg);
        print("{s}\n", .{response});
    }
```

