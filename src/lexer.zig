const std = @import("std");
const ArrayList = std.ArrayList;

/// Errors that can occur during lexing.
const LexerError = error{
    UnexpectedEndOfInput,
    UnexpectedCharacter,
    MissingDoubleQuote,
    MissingSingleQuote,
    MissingLtexSingleQuote,
    MissingLtexDoubleQuote,
};

/// Represents a token in the input source.
pub const Token = union(enum) {
    literal: []const u8,
    double_quote_start: void,
    double_quote_end: void,
    single_quote_start: void,
    single_quote_end: void,
    ltex_single_quote_start: void,
    ltex_single_quote_end: void,
    ltex_double_quote_start: void,
    ltex_double_quote_end: void,
    eof: void,
};

/// Checks if a character is whitespace.
fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '	' or c == '
' or c == '';
}

/// Checks if a character is a digit.
fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

/// The Lexer struct, responsible for tokenizing the input source.
pub const Lexer = struct {
    source: []const u8,
    start: usize,
    current: usize,
    tokens: ArrayList(Token),

    const Self = @This();

    /// Initializes a new Lexer.
    pub fn init(allocator: std.mem.Allocator, source: []const u8) !Self {
        return Self{
            .source = source,
            .current = 0,
            .start = 0,
            .tokens = ArrayList(Token).init(allocator),
        };
    }

    /// Deinitializes the Lexer, freeing the tokens list.
    pub fn deinit(self: *Self) void {
        self.tokens.deinit();
    }

    /// Returns true if the lexer has reached the end of the source.
    pub fn isAtEnd(self: *Self) bool {
        return self.current >= self.source.len;
    }

    /// Advances the lexer and returns the current character.
    pub fn next(self: *Self) LexerError!u8 {
        if (self.isAtEnd()) {
            return error.UnexpectedEndOfInput;
        }
        const c = self.source[self.current];
        self.current += 1;
        return c;
    }

    /// Performs the lexical analysis of the source code.
    pub fn lex(self: *Self) LexerError!void {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scan_tokens();
        }
        // If no tokens were generated, treat the whole source as a single literal.
        if (self.tokens.items.len == 0) {
            self.tokens.append(.{ .literal = self.source[0..self.current] }) catch unreachable;
        }
        // Append an end-of-file token.
        self.tokens.append(.{ .eof = {} }) catch unreachable;
    }

    /// Scans the next token from the source.
    pub fn scan_tokens(self: *Self) LexerError!void {
        const c = try self.next();

        switch (c) {
            // Handle LaTeX-style quotes (` and ``)
            '`' => {
                const prev_is_space = self.start == 0 or isWhitespace(self.source[self.start - 1]);
                const next_is_space = self.isAtEnd() or isWhitespace(try self.peek());
                if (prev_is_space or next_is_space) {
                    // Handle double LaTeX quotes (``)
                    if (try self.peek() == '`') {
                        self.tokens.append(.{ .ltex_double_quote_start = {} }) catch unreachable;
                        while (!self.isAtEnd()) {
                            const ch = try self.next();
                            const prev_char = self.source[self.current - 1];
                            // Look for the closing sequence ('')
                            if (ch == ''' and prev_char == ''') {
                                const literal = self.source[self.start + 2.. self.current - 1];
                                self.tokens.append(.{ .literal = literal }) catch unreachable;
                                self.tokens.append(.{ .ltex_double_quote_end = {} }) catch unreachable;
                                _ = try self.next();
                                _ = try self.next();
                                return;
                            }
                        }
                        return error.MissingLtexDoubleQuote;
                    }
                    // Handle single LaTeX quotes (`)
                    self.tokens.append(.{ .ltex_single_quote_start = {} }) catch unreachable;
                    while (!self.isAtEnd()) {
                        const ch = try self.next();
                        // Look for the closing quote (')
                        if (ch == ''') {
                            const literal = self.source[self.start + 1 .. self.current - 1];
                            self.tokens.append(.{ .literal = literal }) catch unreachable;
                            self.tokens.append(.{ .ltex_single_quote_end = {} }) catch unreachable;
                            _ = try self.next();
                            return;
                        }
                    }
                    return error.MissingLtexSingleQuote;
                }
            },
            // Handle standard double quotes (")
            '"' => {
                self.tokens.append(.{ .double_quote_start = {} }) catch unreachable;
                self.start = self.current;

                while (!self.isAtEnd()) {
                    const ch = try self.next();
                    if (ch == '"') {
                        const literal = self.source[self.start .. self.current - 1];
                        self.tokens.append(.{ .literal = literal }) catch unreachable;
                        self.tokens.append(.{ .double_quote_end = {} }) catch unreachable;
                        return;
                    }
                }
                return error.MissingDoubleQuote;
            },

            // Handle standard single quotes (')
            ''' => {
                // only treat as quote if surrounded by whitespace or punctuation
                const prev_is_space = self.start == 0 or isWhitespace(self.source[self.start - 1]);
                const next_is_space = self.isAtEnd() or isWhitespace(try self.peek());

                if (prev_is_space or next_is_space) {
                    self.tokens.append(.{ .single_quote_start = {} }) catch unreachable;
                    self.start = self.current;

                    while (!self.isAtEnd()) {
                        const ch = try self.next();
                        if (ch == ''') {
                            const literal = self.source[self.start .. self.current - 1];
                            self.tokens.append(.{ .literal = literal }) catch unreachable;
                            self.tokens.append(.{ .single_quote_end = {} }) catch unreachable;
                            return;
                        }
                    }
                    return error.MissingSingleQuote;
                } else {
                    // treat as literal (apostrophe inside word)
                    while (!self.isAtEnd()) {
                        const peek_res = try self.peek();
                        if (isWhitespace(peek_res) or peek_res == '"' or peek_res == ''' or peek_res == '`') break;
                        _ = try self.next();
                    }
                    const literal = self.source[self.start..self.current];
                    self.tokens.append(.{ .literal = literal }) catch unreachable;
                }
            },

            // Handle literals (any other text)
            else => {
                while (!self.isAtEnd()) {
                    const peek_res = try self.peek();
                    if (isWhitespace(peek_res) or peek_res == '"' or peek_res == ''' or peek_res == '`') break;
                    _ = try self.next();
                }
                const literal = self.source[self.start..self.current];
                self.tokens.append(.{ .literal = literal }) catch unreachable;
            },
        }
    }

    /// Returns the finalized list of tokens.
    pub fn finalize(self: *Self) ArrayList(Token) {
        return self.tokens;
    }

    /// Peeks at the current character without advancing the lexer.
    fn peek(self: *Self) LexerError!u8 {
        const idx = self.current;
        if (idx >= self.source.len) {
            return error.UnexpectedEndOfInput;
        }
        return self.source[idx];
    }

    /// Peeks at the next character without advancing the lexer.
    fn peek_next(self: *Self) LexerError!u8 {
        const idx = self.current + 1;
        if (idx >= self.source.len) {
            return error.UnexpectedEndOfInput;
        }
        return self.source[idx];
    }

    /// Returns the current character.
    fn currentChar(self: *Self) u8 {
        return self.source[self.current];
    }
};
