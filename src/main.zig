const std = @import("std");
const clap = @import("clap");
const ArrayList = std.ArrayList;
const Lexer = @import("lexer.zig").Lexer;
const Writer = @import("writer.zig").Writer;

/// Global configuration for the application.
var config = struct {
    input_file: ?[]const u8 = null,
    output_file: ?[]const u8 = null,
    help: bool = false,
    version: bool = false,
    stdout: bool = false,
    read_stdin: bool = false,
}{};

/// Main entry point of the application.
pub fn main() !void {
    // Set up a general-purpose allocator.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // NOTE: Command-line argument parsing with 'clap' is currently commented out.
    const params = comptime clap.parseParamsComptime(
        \\-h, --help               Display this help and exit.
        \\-o, --output <string>    Write to FILE instead of stdout.
        \\-s, --stdout <string>    An option parameter which takes an enum.
        \\<string>...
        \\
    );
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
        // The assignment separator can be configured. `--number=1` and `--number:1` is now
        // allowed.
        .assignment_separators = "=:",
    }) catch |err| {
        // Report useful error and exit.
        try diag.reportToFile(.stderr(), err);
        return err;
    };
    defer res.deinit();

    // Allocate and process command-line arguments.
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Basic argument check.
    if (args.len == 1) {
        std.debug.print("Usage: requote <input>\n", .{});
        return;
    }
    const input_file = args[1];

    // Read the input file.
    const file = try std.fs.cwd().openFile(input_file, .{});
    defer file.close();
    const input = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    // Normalize "smart" quotes to standard ASCII quotes.
    const cleaned_input = try normalizeQuotes(allocator, input);
    defer allocator.free(cleaned_input);

    // Initialize the lexer and tokenize the input.
    var lexer = try Lexer.init(allocator, cleaned_input);
    defer lexer.deinit();
    try lexer.lex();
    const tokens = lexer.finalize();

    // Initialize the writer and generate the output string.
    var writer = Writer.init(allocator);
    defer writer.deinit();
    for (tokens.items) |token| {
        writer.write(token);
    }

    // Print the output to stdout and write to a file.
    std.debug.print("output: {s}\n", .{writer.flush().items});
    const output_file = try std.fs.cwd().createFile("output.txt", .{});
    defer output_file.close();
    try output_file.writeAll(writer.flush().items);
}

/// Replaces various Unicode "smart" quotes with their ASCII equivalents.
pub fn normalizeQuotes(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buffer = try allocator.alloc(u8, input.len);
    var out_index: usize = 0;

    var it = std.unicode.Utf8Iterator{ .bytes = input, .i = 0 };
    while (it.nextCodepoint()) |cp| {
        const ch: u32 = cp;

        // Replace "smart" quotes with ASCII equivalents
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
