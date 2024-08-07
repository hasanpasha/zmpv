const std = @import("std");
const Mpv = @import("Mpv.zig");
const GenericError = @import("generic_error.zig").GenericError;
const MpvNode = @import("mpv_node.zig").MpvNode;
const types = @import("types.zig");
const MpvNodeList = types.MpvNodeList;
const MpvNodeMap = types.MpvNodeMap;
const MpvRenderContext = @import("MpvRenderContext.zig");
const MpvRenderParam = MpvRenderContext.MpvRenderParam;
const utils = @import("utils.zig");
const testing = std.testing;

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
        args.precision.to_string(),
    });
    defer self.allocator.free(flag_str);

    var cmd_args = [_][]const u8{ "seek", target, flag_str };
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
    var cmd_args = [_][]const u8{ "add", name, args.value };
    try self.command(&cmd_args);
}

pub fn property_multiply(self: Mpv, name: []const u8, factor: []const u8) !void {
    var cmd_args = [_][]const u8{ "multiply", name, factor };
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

    pub fn to_string(self: ScreenshotInclude) []const u8 {
        return switch (self) {
            .Subtitles => "subtitles",
            .Video => "video",
            .Window => "window",
        };
    }
};

/// The returned node must be freed with `self.free(node)`
pub fn screenshot(self: Mpv, args: struct {
    include: ScreenshotInclude = .Subtitles,
    each_frame: bool = false,
}) !MpvNode {
    var flag_str: []const u8 = undefined;
    if (args.each_frame) {
        flag_str = try std.fmt.allocPrint(self.allocator, "{s}+each-frame", .{args.include.to_string()});
    } else {
        flag_str = args.include.to_string();
    }

    defer {
        if (args.each_frame) {
            self.allocator.free(flag_str);
        }
    }
    return try self.command_ret(&.{ "screenshot", flag_str });
}

// TODO: wrap `screenshot-raw` command

pub fn screenshot_to_file(self: Mpv, filename: []const u8, args: struct {
    include: ScreenshotInclude = .Subtitles,
}) !void {
    try self.command(&.{ "screenshot-to-file", filename, args.include.to_string() });
}

pub fn playlist_next(self: Mpv, args: struct {
    force: bool = false,
}) !void {
    try self.command(&.{ "playlist-next", if (args.force) "force" else "weak" });
}

pub fn playlist_prev(self: Mpv, args: struct {
    force: bool = false,
}) !void {
    try self.command(&.{ "playlist-prev", if (args.force) "force" else "weak" });
}

pub const LoadlistFlag = enum {
    Replace,
    Append,
    AppendPlay,

    pub fn to_string(self: LoadlistFlag) []const u8 {
        return switch (self) {
            .Replace => "replace",
            .Append => "append",
            .AppendPlay => "append-play",
        };
    }
};

pub fn loadlist(self: Mpv, url: []const u8, args: struct {
    flag: LoadfileFlag = .Append,
}) !void {
    try self.command(&.{ "loadlist", url, args.flag.to_string() });
}

pub fn playlist_clear(self: Mpv) !void {
    try self.command_string("playlist-clear");
}

pub fn run(self: Mpv, command: []const u8, command_args: []const []const u8) !void {
    var cmd_args = std.ArrayList([]const u8).init(self.allocator);
    defer cmd_args.deinit();
    try cmd_args.appendSlice(&.{ "run", command });
    try cmd_args.appendSlice(command_args);
    try self.command(cmd_args.items);
}

pub const SubprocessCommandResult = struct {
    status: i64,
    stdout: []u8,
    stderr: []u8,
    killed_by_us: bool,
    allocator: std.mem.Allocator,

    pub fn from_node_map(node_map: MpvNodeMap, allocator: std.mem.Allocator) !SubprocessCommandResult {
        var hash_map = try node_map.to_hashmap(allocator);
        defer hash_map.deinit();

        return .{
            .status = hash_map.get("status").?.INT64,
            .stdout = try allocator.dupe(u8, hash_map.get("stdout").?.ByteArray),
            .stderr = try allocator.dupe(u8, hash_map.get("stderr").?.ByteArray),
            .killed_by_us = hash_map.get("killed_by_us").?.Flag,
            .allocator = allocator,
        };
    }

    pub fn free(self: @This()) void {
        self.allocator.free(self.stdout);
        self.allocator.free(self.stderr);
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return writer.print("SubprocessCommandResult{{ status = {}, stdout = \"{s}\", stderr = \"{s}\", killed_by_us: {} }}", .{
            self.status,
            self.stdout,
            self.stderr,
            self.killed_by_us,
        });
    }
};

/// The result should be free by calling `.free()` on it.
pub fn subprocess(self: Mpv, command: []const []const u8, args: struct {
    playback_only: bool = true,
    capture_size: i64 = 64 * 1e6,
    capture_stdout: bool = false,
    capture_stderr: bool = false,
    detach: bool = false,
    env: []const []const u8 = &.{},
    stdin_data: []const u8 = "",
    passthrough_stdin: bool = false,
    /// This is not part of the mpv command arguments but is used by this function
    /// itself to determine whether to run the command asynchronously or not.
    sync: bool = true,
}) !union {
    value: SubprocessCommandResult,
    reply_code: u64,
} {
    var cmd_args = std.ArrayList(MpvNodeMap.Element).init(self.allocator);
    defer cmd_args.deinit();

    var command_args = std.ArrayList(MpvNodeList.Element).init(self.allocator);
    defer command_args.deinit();
    for (command) |arg| {
        try command_args.append(.{ .String = arg });
    }
    try cmd_args.append(.{ "name", MpvNode{ .String = "subprocess" } });
    try cmd_args.append(.{ "args", MpvNode{ .NodeArray = MpvNodeList.new(command_args.items) } });
    try cmd_args.append(.{ "playback_only", MpvNode{ .Flag = args.playback_only } });
    try cmd_args.append(.{ "capture_size", MpvNode{ .INT64 = args.capture_size } });
    try cmd_args.append(.{ "capture_stdout", MpvNode{ .Flag = args.capture_stdout } });
    try cmd_args.append(.{ "capture_stderr", MpvNode{ .Flag = args.capture_stderr } });
    try cmd_args.append(.{ "detach", MpvNode{ .Flag = args.detach } });
    var envs = std.ArrayList(MpvNodeList.Element).init(self.allocator);
    defer envs.deinit();
    for (args.env) |env| {
        try envs.append(.{ .String = env });
    }
    try cmd_args.append(.{ "env", MpvNode{ .NodeArray = MpvNodeList.new(envs.items) } });
    try cmd_args.append(.{ "stdin_data", MpvNode{ .String = args.stdin_data } });
    try cmd_args.append(.{ "passthrough_stdin", MpvNode{ .Flag = args.passthrough_stdin } });

    const cmd_args_node = MpvNode{ .NodeMap = MpvNodeMap.new(cmd_args.items) };
    if (args.sync) {
        const node = try self.command_node(cmd_args_node);
        defer self.free(node);
        return .{ .value = try SubprocessCommandResult.from_node_map(node.NodeMap, self.allocator) };
    } else {
        const str = try std.mem.concat(self.allocator, u8, command);
        defer self.allocator.free(str);
        const reply_code = std.hash.Fnv1a_64.hash(str);
        try self.command_node_async(reply_code, cmd_args_node);
        return .{ .reply_code = reply_code };
    }
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
const SLEEP_AMOUNT: u64 = 1 * 1e7;
const test_filepath = "resources/sample.mp4";

test "MpvHelper seek" {
    const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.command(&.{ "loadfile", test_filepath });
    try mpv.observe_property(6969, "time-pos", .INT64);
    var seeked = false;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format() == .INT64 and !seeked) {
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

    try mpv.command(&.{ "loadfile", test_filepath });
    try mpv.observe_property(6969, "time-pos", .INT64);
    var seeked = false;
    var reverted = false;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format() == .INT64 and !seeked) {
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

    try mpv.command(&.{ "loadfile", test_filepath });
    try mpv.observe_property(6969, "time-pos", .INT64);
    var stepped = false;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format() == .INT64 and !stepped) {
                try mpv.frame_step();
                stepped = true;
                std.time.sleep(SLEEP_AMOUNT * 5);
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

    try mpv.command(&.{ "loadfile", test_filepath });
    try mpv.observe_property(6969, "time-pos", .INT64);
    var stepped = false;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format() == .INT64 and !stepped) {
                try mpv.frame_back_step();
                stepped = true;
                std.time.sleep(SLEEP_AMOUNT * 3);
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

    try mpv.command(&.{ "loadfile", test_filepath });
    try mpv.observe_property(6969, "time-pos", .INT64);
    var added = false;
    var checked_add = false;
    var time_pos: i64 = 0;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format() == .INT64 and !added) {
                time_pos = event.data.PropertyChange.data.INT64;
                try mpv.property_add("time-pos", .{ .value = "50" });
                added = true;
                std.time.sleep(SLEEP_AMOUNT * 3);
            }
            if (added and !checked_add) {
                const current_time_pos = try mpv.get_property("time-pos", .INT64);
                defer mpv.free(current_time_pos);
                try testing.expect((time_pos + 50) == current_time_pos.INT64);
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

    try mpv.command(&.{ "loadfile", test_filepath });
    try mpv.observe_property(6969, "time-pos", .INT64);
    var multiplied = false;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format() == .INT64 and !multiplied) {
                const current_speed = try mpv.get_property("speed", .INT64);
                defer mpv.free(current_speed);
                try mpv.property_multiply("speed", "3");
                std.time.sleep(SLEEP_AMOUNT * 3);
                const after_current_speed = try mpv.get_property("speed", .INT64);
                defer mpv.free(current_speed);
                try testing.expect((current_speed.INT64 * 3) == after_current_speed.INT64);
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

    try mpv.command(&.{ "loadfile", test_filepath });
    try mpv.observe_property(6969, "time-pos", .INT64);
    var paused = false;
    while (true) {
        const event = mpv.wait_event(-1);
        if (event.event_id == .EndFile) break;
        if (event.reply_userdata == 6969) {
            if (event.data.PropertyChange.format() == .INT64 and !paused) {
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

// FIXME `loadfile` randomly returns error for unknow reasons
test "MpvHelper loadfile" {
    const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.loadfile(test_filepath, .{});
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

fn remove_file_with_extension(extension: []const u8, allocator: std.mem.Allocator, args: struct {
    path: []const u8 = ".",
}) !void {
    var dir = try std.fs.cwd().openDir(args.path, .{ .iterate = true });
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        const ext = std.fs.path.extension(entry.basename);
        if (std.mem.eql(u8, ext, extension)) {
            try dir.deleteFile(entry.path);
        }
    }
}

fn clean_saved_screen_shots(path: []const u8, allocator: std.mem.Allocator) !void {
    try remove_file_with_extension(".jpg", allocator, .{ .path = path });
}

test "MpvHelper screenshot" {
    const allocator = testing.allocator;
    const mpv = try Mpv.create_and_initialize(allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.command(&.{ "loadfile", test_filepath });
    try mpv.observe_property(6969, "time-pos", .Double);
    var screenshoted = false;
    var stopped = false;
    while (true) {
        const event = mpv.wait_event(0);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969 and !screenshoted) {
            if (event.data.PropertyChange.format() == .Double) {
                const time_pos = event.data.PropertyChange.data.Double;
                if (!screenshoted and time_pos > 0.3) {
                    const screenshot_ret = try mpv.screenshot(.{ .each_frame = true });
                    defer mpv.free(screenshot_ret);
                    var screenshot_info = screenshot_ret.NodeMap;
                    var iter = screenshot_info.iterator();
                    const filename_pair = iter.next().?;
                    try testing.expectEqualStrings("filename", filename_pair[0]);
                    try testing.expectStringStartsWith(filename_pair[1].String, "mpv");
                    try testing.expectStringEndsWith(filename_pair[1].String, ".jpg");
                    try testing.expect(!screenshoted);
                    try testing.expect(!stopped);
                    screenshoted = true;
                }

                if (screenshoted and !stopped) {
                    const screenshot_ret = try mpv.screenshot(.{});
                    defer mpv.free(screenshot_ret);
                    try testing.expect(time_pos > 0.3);
                    try testing.expect(screenshoted);
                    stopped = true;
                }

                if (time_pos > 1.2) {
                    try testing.expect(screenshoted);
                    try testing.expect(stopped);
                }
            }
        }
        if (screenshoted and stopped) {
            try mpv.quit(.{});
        }
    }
    // clean up saved files
    try clean_saved_screen_shots(".", allocator);
}

test "MpvHelper screenshot-to-file" {
    const allocator = testing.allocator;
    const mpv = try Mpv.create_and_initialize(allocator, &.{});
    defer mpv.terminate_destroy();

    const custom_screenshot_filename = "hender.jpg";
    try mpv.command(&.{ "loadfile", test_filepath });
    try mpv.observe_property(6969, "time-pos", .Double);
    var screenshoted = false;
    while (true) {
        const event = mpv.wait_event(0);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969 and !screenshoted) {
            if (event.data.PropertyChange.format() == .Double) {
                const time_pos = event.data.PropertyChange.data.Double;
                if (!screenshoted and time_pos > 0.3) {
                    try mpv.screenshot_to_file(custom_screenshot_filename, .{});
                    screenshoted = true;
                }

                if (time_pos > 1.0) {
                    try testing.expect(screenshoted);
                }
            }
        }
        if (screenshoted) {
            try mpv.quit(.{});
        }
    }
    // clean up saved files
    try std.fs.cwd().deleteFile(custom_screenshot_filename);
}

fn create_playlist(base_file_path: []const u8, allocator: std.mem.Allocator, args: struct {
    size: usize = 1,
    playlist_filename: []const u8 = "playlist.txt",
}) ![]const u8 {
    const file = try std.fs.cwd().createFile(
        args.playlist_filename,
        .{ .read = true },
    );
    defer file.close();

    for (0..args.size) |idx| {
        const symlink = try std.fmt.allocPrint(allocator, "{s}-{}.bak", .{ base_file_path, idx });
        defer allocator.free(symlink);
        try std.fs.cwd().symLink(base_file_path, symlink, .{});
        _ = try file.writer().print("{s}\n", .{symlink});
    }

    return args.playlist_filename;
}

test "MpvHelper playlist-next" {
    const allocator = testing.allocator;
    const mpv = try Mpv.create_and_initialize(allocator, &.{});
    defer mpv.terminate_destroy();

    const base_filename = test_filepath;
    const playlist_path = try create_playlist(base_filename, allocator, .{ .size = 2 });
    defer {
        std.fs.cwd().deleteFile(playlist_path) catch {};
        remove_file_with_extension(".bak", allocator, .{ .path = "resources" }) catch {};
    }
    try mpv.command(&.{ "loadlist", playlist_path });
    try mpv.observe_property(6969, "playlist-current-pos", .INT64);
    var nums_play_next: u8 = 0;
    var finished = false;
    while (true) {
        const event = mpv.wait_event(0);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969) {
            const playlist_pos = event.data.PropertyChange.data.INT64;
            if (nums_play_next == 0) {
                try testing.expect(playlist_pos == 0);
                nums_play_next += 1;
                try mpv.playlist_next(.{ .force = true });
            } else if (nums_play_next == 1) {
                try testing.expect(playlist_pos == 1);
                finished = true;
            }
        }
        if (finished) {
            try mpv.quit(.{});
        }
    }
}

test "MpvHelper playlist-prev" {
    const allocator = testing.allocator;
    const mpv = try Mpv.create_and_initialize(allocator, &.{});
    defer mpv.terminate_destroy();

    const base_filename = test_filepath;
    const playlist_path = try create_playlist(base_filename, allocator, .{ .size = 2 });
    defer {
        std.fs.cwd().deleteFile(playlist_path) catch {};
        remove_file_with_extension(".bak", allocator, .{ .path = "resources" }) catch {};
    }
    try mpv.command(&.{ "loadlist", playlist_path });
    try mpv.observe_property(6969, "playlist-current-pos", .INT64);
    var nums_play_next: u8 = 0;
    var finished = false;
    while (true) {
        const event = mpv.wait_event(0);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (event.reply_userdata == 6969) {
            const playlist_pos = event.data.PropertyChange.data.INT64;
            if (nums_play_next == 0) {
                try testing.expect(playlist_pos == 0);
                nums_play_next += 1;
                try mpv.command_string("playlist-next");
            } else if (nums_play_next == 1) {
                try testing.expect(playlist_pos == 1);
                nums_play_next += 1;
                try mpv.playlist_prev(.{});
            } else if (nums_play_next == 2) {
                try testing.expect(playlist_pos == 0);
                finished = true;
            }
        }
        if (finished) {
            try mpv.quit(.{});
        }
    }
}

test "MpvHelper loadlist" {
    const allocator = testing.allocator;
    const mpv = try Mpv.create_and_initialize(allocator, &.{});
    defer mpv.terminate_destroy();

    const base_filename = test_filepath;
    const playlist_path = try create_playlist(base_filename, allocator, .{ .size = 3 });
    defer {
        std.fs.cwd().deleteFile(playlist_path) catch {};
        remove_file_with_extension(".bak", allocator, .{ .path = "resources" }) catch {};
    }

    try mpv.loadlist(playlist_path, .{});
    const pc = try mpv.get_property("playlist-count", .INT64);
    try testing.expect(pc.INT64 == 3);
    try mpv.command_string("playlist-play-index 0");

    while (true) {
        const event = mpv.wait_event(0);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
    }
}

test "MpvHelper playlist-clear" {
    const allocator = testing.allocator;
    const mpv = try Mpv.create_and_initialize(allocator, &.{});
    defer mpv.terminate_destroy();

    const base_filename = test_filepath;
    const playlist_path = try create_playlist(base_filename, allocator, .{ .size = 2 });
    defer {
        std.fs.cwd().deleteFile(playlist_path) catch {};
        remove_file_with_extension(".bak", allocator, .{ .path = "resources" }) catch {};
    }

    try mpv.command(&.{ "loadlist", playlist_path });
    const pc1 = try mpv.get_property("playlist-count", .INT64);
    try testing.expect(pc1.INT64 == 2);

    try mpv.playlist_clear();

    const pc2 = try mpv.get_property("playlist-count", .INT64);
    try testing.expect(pc2.INT64 == 1);
}

test "MpvHelper run" {
    // FIXME: find a way to test mpv.run without blocking the test unit.
    return error.SkipZigTest;
    // const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    // defer mpv.terminate_destroy();

    // try mpv.run("/bin/sh", &.{ "-c", "echo ${title}" });
    // try mpv.command(&.{ "loadfile", test_filepath });
    // try mpv.observe_property(6969, "time-pos", .INT64);
    // var ran = false;
    // while (true) {
    //     const event = mpv.wait_event(0);
    //     if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
    //     if (event.reply_userdata == 6969 and !ran) {
    //         ran = true;
    //     } else if (ran) {
    //         try mpv.command_string("quit");
    //     }
    // }
}

// FIXME sync process gets unexpected stdout text
test "MpvHelper subprocess" {
    const allocator = testing.allocator;
    const mpv = try Mpv.create_and_initialize(allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.command(&.{ "loadfile", test_filepath });
    try mpv.observe_property(6969, "time-pos", .INT64);
    var should_quit = false;
    var result_code: ?u64 = null;
    var done_sync = false;
    while (true) {
        const event = mpv.wait_event(0);
        if (event.event_id == .EndFile or event.event_id == .Shutdown) break;
        if (result_code) |code| {
            if (code == event.reply_userdata) {
                const data = event.data.CommandReply.result.NodeMap;
                const result = try SubprocessCommandResult.from_node_map(data, allocator);
                defer result.free();
                try testing.expectEqualStrings("hello", result.stdout);
                try testing.expectEqualStrings("", result.stderr);
                try testing.expect(result.killed_by_us == false);
                try testing.expect(result.status == 0);
                should_quit = true;
            }
        }
        if (event.reply_userdata == 6969) {
            if (!done_sync) {
                const result = (try mpv.subprocess(&.{ "/bin/sh", "-c", "sleep 1 && printf hello" }, .{
                    .capture_stdout = true,
                    .capture_stderr = true,
                    .detach = true,
                    .sync = true,
                })).value;
                defer result.free();
                try testing.expectEqualStrings("hello", result.stdout);
                try testing.expectEqualStrings("", result.stderr);
                try testing.expect(result.killed_by_us == false);
                try testing.expect(result.status == 0);
                done_sync = true;
            }
            result_code = (try mpv.subprocess(&.{ "/bin/sh", "-c", "sleep 1 && printf hello" }, .{
                .capture_stdout = true,
                .capture_stderr = true,
                .capture_size = 1e9,
                .detach = true,
                .sync = false,
            })).reply_code;
        }
        if (should_quit) {
            try mpv.command_string("quit");
        }
    }
}

test "MpvHelper quit" {
    const mpv = try Mpv.create_and_initialize(testing.allocator, &.{});
    defer mpv.terminate_destroy();

    try mpv.command(&.{ "loadfile", test_filepath });
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
