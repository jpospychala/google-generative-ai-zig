pub const GenerateContentRequest = struct {
    safetySettings: [][]u8,
    generationConfig: GenerationConfig,
    contents: []Content,
};

pub const Content = struct {
    role: []const u8,
    parts: []const Part,
};

pub const Part = struct {
    text: []u8,
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
};

pub const UsageMetadata = struct {
    promptTokenCount: usize,
    candidatesTokenCount: usize,
    totalTokenCount: usize,
    promptTokensDetails: []TokensDetails,
};

pub const TokensDetails = struct {
    modality: []u8,
    tokenCount: usize,
};
