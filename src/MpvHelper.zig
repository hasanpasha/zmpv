const std = @import("std");
const Mpv = @import("./Mpv.zig");
const MpvRenderContext = @import("./MpvRenderContext.zig");
const MpvRenderParam = MpvRenderContext.MpvRenderParam;

/// Create an `Mpv` instance and set options if provided
pub fn create_and_set_options(allocator: std.mem.Allocator, options: []const struct { []const u8, []const u8 }) !Mpv {
    const instance = try Mpv.create(allocator);

    for (options) |option| {
        try instance.set_option_string(option[0], option[1]);
    }

    return instance;
}

/// Create an `Mpv` instance and initialize it with the given options
pub fn create_and_initialize(allocator: std.mem.Allocator, options: []const struct { []const u8, []const u8 }) !Mpv {
    var instance = try Mpv.create_and_set_options(allocator, options);
    try instance.initialize();
    return instance;
}

/// an alternative helper function to create `MpvRenderContext`
pub fn create_render_context(self: Mpv, params: []MpvRenderParam) !MpvRenderContext {
    return MpvRenderContext.create(self, params);
}

pub const LoadfileFlag = enum {
    Replace,
    Append,
    AppendPlay,
    InsertNext,
    InsertNextPlay,
    InsertAt,
    InsertAtPlay,

    pub fn to_string(self: LoadfileFlag) []const u8 {
        return switch (self) {
            .Replace => "replace",
            .Append => "append",
            .AppendPlay => "append-play",
            .InsertNext => "insert-next",
            .InsertNextPlay => "insert-next-play",
            .InsertAt => "insert-at",
            .InsertAtPlay => "insert-at-play",
        };
    }
};

pub fn loadfile(self: Mpv, filename: []const u8, args: struct {
    flag: LoadfileFlag = .Replace,
    index: usize = 0,
    options: []const u8 = "",
}) !void {
    const flag_str = args.flag.to_string();
    const index_str = try std.fmt.allocPrint(self.allocator, "{}", .{args.index});
    defer self.allocator.free(index_str);

    var cmd_args = std.ArrayList([]const u8).init(self.allocator);
    defer cmd_args.deinit();

    try cmd_args.appendSlice(&[_][]const u8{ "loadfile", filename, flag_str });
    if (args.flag == .InsertAt or args.flag == .InsertAtPlay) {
        try cmd_args.append(index_str);
    }
    try cmd_args.append(args.options);

    try self.command(cmd_args.items);
}

pub fn cycle(self: Mpv, property_name: []const u8, args: struct {
    direction: enum { Up, Down } = .Up,
}) !void {
    const direction_str = if (args.direction == .Up) "up" else "down";
    var cmd_args = [_][]const u8{ "cycle", property_name, direction_str };
    try self.command(&cmd_args);
}
