const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("lexer.zig").Token;
const ArrayList = std.ArrayList;

/// The Writer struct, responsible for generating the output string from tokens.
pub const Writer = struct {
    buffer: ArrayList(u8),

    const Self = @This();

    /// Initializes a new Writer.
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .buffer = ArrayList(u8).init(allocator),
        };
    }

    /// Deinitializes the Writer, freeing its buffers.
    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }

    /// Returns the final generated output.
    pub fn flush(self: *Self) ArrayList(u8) {
        return self.buffer;
    }

    /// Writes the string representation of a token to the buffer.
    pub fn write(self: *Self, token: Token) void {
        switch (token) {
            .literal => |literal| {
                self.buffer.appendSlice(literal) catch unreachable;
            },
            // Convert standard double quotes to LaTeX style.
            .double_quote_start => {
                self.buffer.appendSlice("``") catch unreachable;
            },
            .double_quote_end => {
                self.buffer.appendSlice("''") catch unreachable;
            },
            // Convert standard single quotes to LaTeX style.
            .single_quote_start => {
                self.buffer.appendSlice("`") catch unreachable;
            },
            .single_quote_end => {
                self.buffer.appendSlice("'") catch unreachable;
            },
            // Handle already LaTeX-style single quotes.
            .ltex_single_quote_start => {
                self.buffer.appendSlice("`") catch unreachable;
            },
            .ltex_single_quote_end => {
                self.buffer.appendSlice("' ") catch unreachable;
            },
            // Handle already LaTeX-style double quotes.
            .ltex_double_quote_start => {
                self.buffer.appendSlice("``") catch unreachable;
            },
            .ltex_double_quote_end => {
                self.buffer.appendSlice("'' ") catch unreachable;
            },
            // Ignore other token types like eof.
            else => {
                //std.debug.print("{}
            },
        }
    }
};
