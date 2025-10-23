const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Writer = @import("writer.zig").Writer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const test_file = try std.fs.cwd().openFile("sample.txt", .{});
    defer test_file.close();
    const test_input = try test_file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(test_input);
    var lexer = try Lexer.init(allocator, test_input);
    defer lexer.deinit();
    try lexer.lex();
    const tokens = lexer.finalize();
    var writer =  Writer.init(allocator);
    defer writer.deinit();
    for (tokens.items) |token| {
        writer.write(token);
    }
    std.debug.print("output: {s}\n", .{writer.flush().items});

}
