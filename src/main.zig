const std = @import("std");
const ArrayList = std.ArrayList;
const Lexer = @import("lexer.zig").Lexer;
const Writer = @import("writer.zig").Writer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        std.debug.print("Usage: requote <input>\n", .{});
        return;
    }
    const input_file = args[1];

    const file = try std.fs.cwd().openFile(input_file, .{});
    defer file.close();
    const input = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);
    const cleaned_input = try normalizeQuotes(allocator, input);
    defer allocator.free(cleaned_input);
    var lexer = try Lexer.init(allocator, cleaned_input);
    defer lexer.deinit();
    try lexer.lex();
    const tokens = lexer.finalize();
    var writer = Writer.init(allocator);
    defer writer.deinit();
    for (tokens.items) |token| {
        writer.write(token);
    }
    std.debug.print("output: {s}\n", .{writer.flush().items});
    const output_file = try std.fs.cwd().createFile("output.txt", .{});
    defer output_file.close();
    try output_file.writeAll(writer.flush().items);
}

pub fn normalizeQuotes(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buffer = try allocator.alloc(u8, input.len);
    var out_index: usize = 0;

    var it = std.unicode.Utf8Iterator{ .bytes = input, .i = 0 };
    while (it.nextCodepoint()) |cp| {
        const ch: u32 = cp;

        // Replace “smart” quotes with ASCII equivalents
        const normalized: u8 = switch (ch) {
            // Double quotes
            0x201C, // “
            0x201D, // ”
            0x275D, // ❝
            0x275E, // ❞
            0x301D, // 〝
            0x301E, // 〞
            0xFF02,
            => '"', // Fullwidth "

            // Single quotes
            0x2018, // ‘
            0x2019, // ’
            0x275B, // ❛
            0x275C, // ❜
            0xFF07,
            => '\'', // Fullwidth '

            else => @intCast(ch),
        };

        buffer[out_index] = normalized;
        out_index += 1;
    }

    return buffer;
}
