const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("lexer.zig").Token;
const ArrayList = std.ArrayList;

pub const Writer = struct {
    buffer: ArrayList(u8),
    tokens: ArrayList(Token),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .buffer = ArrayList(u8).init(allocator),
            .tokens = ArrayList(Token).init(allocator),
        };
    }
    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
        self.tokens.deinit();
    }
    pub fn flush(self: *Self) ArrayList(u8) {
        return self.buffer;
    }
    pub fn write(self: *Self, token: Token) void {
        switch (token) {
            .literal => |literal| {
                self.buffer.appendSlice(literal) catch unreachable;
            },
            .double_quote_start => {
                self.buffer.appendSlice("``") catch unreachable;
            },
            .double_quote_end => {
                self.buffer.appendSlice("''") catch unreachable;
            },
            .single_quote_start => {
                self.buffer.appendSlice("`") catch unreachable;
            },
            .single_quote_end => {
                self.buffer.appendSlice("'") catch unreachable;
            },
            .ltex_single_quote_start => {
                self.buffer.appendSlice("`") catch unreachable;
            },
            .ltex_single_quote_end => {
                self.buffer.appendSlice("' ") catch unreachable;
            },
            .ltex_double_quote_start => {
                self.buffer.appendSlice("``") catch unreachable;
            },
            .ltex_double_quote_end => {
                self.buffer.appendSlice("'' ") catch unreachable;
            },
            else => {
                //std.debug.print("{}\n", .{token});
            },
        }
    }
};
