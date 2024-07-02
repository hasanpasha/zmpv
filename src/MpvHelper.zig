const std = @import("std");
const Mpv = @import("./Mpv.zig");
const GenericError = @import("./generic_error.zig").GenericError;
const MpvRenderContext = @import("./MpvRenderContext.zig");
const MpvRenderParam = MpvRenderContext.MpvRenderParam;
const utils = @import("./utils.zig");
const testing = std.testing;

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

pub fn frame_step(self: Mpv) !void {
    try self.command_string("frame-step");
}

pub fn frame_back_step(self: Mpv) !void {
    try self.command_string("frame-back-step");
}

pub fn property_add(self: Mpv, name: []const u8, args: struct {
    value: []const u8 = "1",
}) !void {
    var cmd_args = [_][]const u8{"add", name, args.value};
    try self.command(&cmd_args);
}

pub fn property_multiply(self: Mpv, name: []const u8, factor: []const u8) !void {
    var cmd_args = [_][]const u8{"multiply", name, factor};
    try self.command(&cmd_args);
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

pub const CycleDirection = enum {
    Up,
    Down,

    pub fn to_string(self: CycleDirection) []const u8 {
        return switch (self) {
            .Up => "up",
            .Down => "down",
        };
    }
};

pub fn cycle(self: Mpv, property_name: []const u8, args: struct {
    direction: CycleDirection = .Up,
}) !void {
    var cmd_args = [_][]const u8{ "cycle", property_name, args.direction.to_string() };
    try self.command(&cmd_args);
}

pub const ScreenshotInclude = enum {
    Subtitles,
    Video,
    Window,

    pub fn to_string(self: ScreenshotInclude) []const u8{
        return switch (self) {
            .Subtitles => "subtitles",
            .Video => "video",
            .Window => "window",
        };
    }
};

pub fn screenshot(self: Mpv, args: struct {
    include: ScreenshotInclude = .Subtitles,
    each_frame: bool = false,
}) !u64 {
    var cmd_args = std.ArrayList([]const u8).init(self.allocator);
    defer cmd_args.deinit();
    var flag_str: []const u8 = undefined;

    try cmd_args.append("screenshot");
    if (args.each_frame) {
        flag_str = try std.fmt.allocPrint(self.allocator, "{s}+each-frame", .{args.include.to_string()});
    } else {
        flag_str = args.include.to_string();
    }
    try cmd_args.append(flag_str);

    defer {
        if (args.each_frame) {
            self.allocator.free(flag_str);
        }
    }
    // TODO: return "screenshot" hash value
    const command_reply_code = 969696;
    try self.command_async(command_reply_code, cmd_args.items);
    return command_reply_code;
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

// tests
const SLEEP_AMOUNT: u64 = 1*1e7;

test "MpvHelper seek" {
    const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.command_string("loadfile sample.mp4");
    try mpv.observe_property(6969, "time-pos", .INT64);
    var seeked = false;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format == .INT64 and !seeked) {
                try mpv.seek("1", .{});
                std.log.debug("seeked", .{});
                seeked = true;
                std.time.sleep(SLEEP_AMOUNT);
            }
            if (seeked) {
                try mpv.command_string("quit");
            }
        }
    }
    try testing.expect(seeked);
}

test "MpvHelper revert_seek" {
    const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.command_string("loadfile sample.mp4");
    try mpv.observe_property(6969, "time-pos", .INT64);
    var seeked = false;
    var reverted = false;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format == .INT64 and !seeked) {
                try mpv.seek("1", .{});
                seeked = true;
                std.time.sleep(SLEEP_AMOUNT);
            }
            if (seeked and !reverted) {
                try mpv.revert_seek(.{});
                reverted = true;
                std.time.sleep(SLEEP_AMOUNT);
            }
            if (seeked and reverted) {
                try mpv.command_string("quit");
            }
        }
    }
    try testing.expect(seeked);
    try testing.expect(reverted);
}

test "MpvHelper frame-step" {
    const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.command_string("loadfile sample.mp4");
    try mpv.observe_property(6969, "time-pos", .INT64);
    var stepped = false;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format == .INT64 and !stepped) {
                try mpv.frame_step();
                stepped = true;
                std.time.sleep(SLEEP_AMOUNT*5);
            }
        }
        if (stepped) {
            const pause_p = try mpv.get_property_string("pause");
            defer mpv.free(pause_p);
            try testing.expectEqualStrings("yes", pause_p);
            try mpv.command_string("quit");
        }
    }
}

test "MpvHelper frame-back-step" {
    const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.command_string("loadfile sample.mp4");
    try mpv.observe_property(6969, "time-pos", .INT64);
    var stepped = false;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format == .INT64 and !stepped) {
                try mpv.frame_back_step();
                stepped = true;
                std.time.sleep(SLEEP_AMOUNT*3);
            }
        }
        if (stepped) {
            const pause_p = try mpv.get_property_string("pause");
            defer mpv.free(pause_p);
            try testing.expectEqualStrings("yes", pause_p);
            try mpv.command_string("quit");
        }
    }
}

test "MpvHelper add" {
    const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.command_string("loadfile sample.mp4");
    try mpv.observe_property(6969, "time-pos", .INT64);
    var added = false;
    var checked_add = false;
    var time_pos: i64 = 0;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format == .INT64 and !added) {
                time_pos = event.data.PropertyChange.data.INT64;
                try mpv.property_add("time-pos", .{ .value = "50" });
                added = true;
                std.time.sleep(SLEEP_AMOUNT*3);
            }
            if (added and !checked_add) {
                const current_time_pos = try mpv.get_property("time-pos", .INT64);
                defer mpv.free(current_time_pos);
                try testing.expect((time_pos+50) == current_time_pos.INT64);
                checked_add = true;
            }
        }
        if (added and checked_add) {
            try mpv.command_string("quit");
        }
    }
}

test "MpvHelper multiply" {
    // return error.SkipZigTest;
    const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.command_string("loadfile sample.mp4");
    try mpv.observe_property(6969, "time-pos", .INT64);
    var multiplied = false;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format == .INT64 and !multiplied) {
                const current_speed = try mpv.get_property("speed", .INT64);
                defer mpv.free(current_speed);
                try mpv.property_multiply("speed", "3");
                std.time.sleep(SLEEP_AMOUNT*3);
                const after_current_speed = try mpv.get_property("speed", .INT64);
                defer mpv.free(current_speed);
                try testing.expect((current_speed.INT64*3) == after_current_speed.INT64);
                multiplied = true;
            }
        }
        if (multiplied) {
            try mpv.command_string("quit");
        }
    }
}

test "MpvHelper cycle" {
    const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.command_string("loadfile sample.mp4");
    try mpv.observe_property(6969, "time-pos", .INT64);
    var paused = false;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format == .INT64 and !paused) {
                try mpv.cycle("pause", .{});
                paused = true;
                std.time.sleep(SLEEP_AMOUNT);
            }
            if (paused) {
                const pause_p = try mpv.get_property_string("pause");
                defer mpv.free(pause_p);
                try testing.expectEqualStrings("yes", pause_p);
                try mpv.command_string("quit");
            }
        }
    }
    try testing.expect(paused);
}

test "MpvHelper loadfile" {
    const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.loadfile("sample.mp4", .{});
    try mpv.observe_property(6969, "time-pos", .INT64);
    var quited = false;
    while (true) {
        const event = mpv.wait_event(0);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969 and !quited) {
            try mpv.command_string("quit");
            quited = true;
        }
    }
}

test "MpvHelper screenshot" {
    const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.command_string("loadfile sample.mp4");
    try mpv.observe_property(6969, "time-pos", .INT64);
    var screenshoted = false;
    var screenshot_reply: u64 = 0;
    var done = false;
    while (true) {
        const event = mpv.wait_event(0);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969 and !screenshoted) {
            if (event.data.PropertyChange.format == .INT64) {
                screenshot_reply = try mpv.screenshot(.{});
                screenshoted = true;
            }
        }
        if (event.reply_userdata == screenshot_reply and screenshoted and !done) {
            const path_node = event.data.CommandReply.result;
            switch (path_node) {
                .String => done = true,
                else => {}
            }
        }
        if (done) {
            try mpv.quit(.{});
        }
    }
}

test "MpvHelper quit" {
    const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.command_string("loadfile sample.mp4");
    try mpv.observe_property(6969, "time-pos", .INT64);
    var quited = false;
    while (true) {
        const event = mpv.wait_event(0);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969 and !quited) {
            try mpv.quit(.{});
            quited = true;
        }
    }
}