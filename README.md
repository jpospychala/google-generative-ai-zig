# ZIG API Bindings for Google Generative AI

Library for connecting to Google Gemini from Zig lang.

## Usage

```zig
    const lib = @import("google-generative-ai");

    const genAI = lib.GoogleGenerativeAI.init(api_key);
    const model = genAI.getGenerativeModel("gemini-2.5-flash");

    var session = model.startChat(allocator);

    while (true) {
        try stdout.writeAll("Speak to AI: ");

        const msg = try stdin.readUntilDelimiterAlloc(allocator, '\n', 1024);

        const response = try session.sendMessage(msg);
        print("{s}\n", .{response});
    }
```

## Install

Fetch
```
$ zig fetch --save git+https://github.com/jpospychala/google-generative-ai-zig.git
```

Add dependency to build.zig (to exe in following example)
```
exe.root_module.addImport("google-generative-ai", b.dependency("google_generative_ai_zig", .{}).module("google-generative-ai"));
```

