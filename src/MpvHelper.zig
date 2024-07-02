const std = @import("std");
const Mpv = @import("./Mpv.zig");
const MpvRenderContext = @import("./MpvRenderContext.zig");
const MpvRenderParam = MpvRenderContext.MpvRenderParam;

/// Create an `Mpv` instance and set options if provided
pub fn create_and_set_options(allocator: std.mem.Allocator, options: []const struct { []const u8, []const u8 }) !*Mpv {
    const instance = try Mpv.create(allocator);

    for (options) |option| {
        try instance.set_option_string(option[0], option[1]);
    }

    return instance;
}

/// Create an `Mpv` instance and initialize it with the given options
pub fn create_and_initialize(allocator: std.mem.Allocator, options: []const struct { []const u8, []const u8 }) !*Mpv {
    var instance = try Mpv.create_and_set_options(allocator, options);
    try instance.initialize();
    return instance;
}

/// an alternative helper function to create `MpvRenderContext`
pub fn create_render_context(self: *Mpv, params: []MpvRenderParam) !MpvRenderContext {
    return MpvRenderContext.create(self, params);
}

// Mpv commands

pub const SeekReference = enum {
    Relative,
    Absolute,

    pub fn to_string(self: SeekReference) []const u8 {
        return switch (self) {
            .Relative => "relative",
            .Absolute => "absolute",
        };
    }
};

pub const SeekPrecision = enum {
    Keyframes,
    Percent,
    Exact,

    pub fn to_string(self: SeekPrecision) []const u8 {
        return switch (self) {
            .Keyframes => "keyframes",
            .Percent => "percent",
            .Exact => "exact",
        };
    }
};

pub fn seek(self: Mpv, target: []const u8, args: struct {
    reference: SeekReference = .Relative,
    precision: SeekPrecision = .Keyframes,
}) !void {
    const flag_str = try std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{
        args.reference.to_string(),
        if (args.precision == .Percent) "-" else "+",
        args.precision.to_string()
    });
    defer self.allocator.free(flag_str);

    var cmd_args = [_][]const u8{"seek", target, flag_str};
    try self.command(&cmd_args);
}

pub const RevertSeekFlag = enum {
    Mark,
    MarkPermanent,

    pub fn to_string(self: RevertSeekFlag) []const u8 {
        return switch (self) {
            .Mark => "mark",
            .MarkPermanent => "mark-permanent",
        };
    }
};

pub fn revert_seek(self: Mpv, args: struct {
    flag: ?RevertSeekFlag = null,
}) !void {
    var cmd_args = std.ArrayList([]const u8).init(self.allocator);
    defer cmd_args.deinit();

    try cmd_args.append("revert_seek");

    if (args.flag) |flag| {
        try cmd_args.append(flag.to_string());
    }

    try self.command(cmd_args.items);
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

pub fn quit(self: Mpv, args: struct {
    code: ?u8 = null,
}) !void {
    var cmd_args = std.ArrayList([]const u8).init(self.allocator);
    defer cmd_args.deinit();
    var code_str: []u8 = undefined;

    try cmd_args.append("quit");
    if (args.code) |code| {
        code_str = try std.fmt.allocPrint(self.allocator, "{}", .{code});
        try cmd_args.append(code_str);
    }
    defer {
        if (args.code != null) {
            self.allocator.free(code_str);
        }
    }

    try self.command(cmd_args.items);
}
