const std = @import("std");
const zmpv = @import("zmpv");
const Mpv = zmpv.Mpv;
const MpvError = zmpv.MpvError;
const MpvLogLevel = zmpv.MpvEventLogMessage.MpvLogLevel;
const MpvNode = zmpv.MpvNode;
const MpvEvent = zmpv.MpvEvent;
const MpvEventProperty = zmpv.MpvEventProperty;
const MpvEventId = zmpv.MpvEventId;
const MpvEventLoop = zmpv.MpvEventLoop;
const MpvEventCallback = zmpv.MpvEventCallback;
const MpvPropertyCallback = zmpv.MpvPropertyCallback;
const MpvPropertyData = zmpv.MpvPropertyData;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) @panic("detected leakage");
    }
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("usage: {s} [filename]\n", .{args[0]});
        return;
    }

    const filename = args[1];

    var mpv = try Mpv.new(allocator, .{
        .options = &.{
            .{ "osc", "yes" },
            .{ "input-default-bindings", "yes" },
            .{ "input-vo-keyboard", "yes" },
        },
    });
    defer mpv.terminate_destroy();

    // var event_loop = try mpv.create_and_run_event_loop_forever(.{});
    var event_loop = try MpvEventLoop.new(mpv);
    defer event_loop.free();

    _ = try event_loop.register_event_callback(MpvEventCallback{
        .event_ids = &.{
            .EndFile,
        },
        .callback = struct {
            pub fn cb(event: MpvEvent, user_data: ?*anyopaque) void {
                _ = user_data;
                std.log.debug("endfile: {}", .{event.data.EndFile});
            }
        }.cb,
        .user_data = null,
    });

    const startfile_callback_unregisterrer = try event_loop.register_event_callback(MpvEventCallback{
        .event_ids = &.{.StartFile},
        .callback = struct {
            pub fn cb(event: MpvEvent, user_data: ?*anyopaque) void {
                _ = user_data;
                std.log.debug("startfile: {}", .{event});
            }
        }.cb,
        .user_data = null,
    });
    // _ = startfile_callback_unregisterrer;
    startfile_callback_unregisterrer.unregister();

    const fullscreen_unregisterrer = try event_loop.register_property_callback(MpvPropertyCallback{
        .property_name = "fullscreen",
        .callback = struct {
            pub fn cb(event: MpvEventProperty, user_data: ?*anyopaque) void {
                _ = user_data;
                std.log.debug("fullscreen changed: {}", .{event.data.Node.Flag});
            }
        }.cb,
    });
    // fullscreen_unregisterrer.unregister();
    _ = fullscreen_unregisterrer;

    const pause_unregisterrer = try event_loop.register_property_callback(MpvPropertyCallback{
        .property_name = "pause",
        .callback = struct {
            pub fn cb(event: MpvEventProperty, user_data: ?*anyopaque) void {
                _ = user_data;
                std.log.debug("pause state: {}", .{event.data.Node.Flag});
            }
        }.cb,
    });
    // pause_unregisterrer.unregister();
    _ = pause_unregisterrer;

    const time_pos_callback_unregisterrer = try event_loop.register_property_callback(MpvPropertyCallback{
        .property_name = "time-pos",
        .format = .INT64,
        .callback = struct {
            pub fn cb(event: MpvEventProperty, user_data: ?*anyopaque) void {
                _ = user_data;
                switch (event.data) {
                    .INT64 => |value| {
                        std.log.debug("time-pos: {}", .{value});
                    },
                    else => {},
                }
            }
        }.cb,
    });
    time_pos_callback_unregisterrer.unregister();
    // _ = time_pos_callback_unregisterrer;

    const log_handler_unregisterrer = try event_loop.register_log_message_handler(.{
        .level = .Debug,
        .callback = struct {
            pub fn cb(level: MpvLogLevel, prefix: []const u8, text: []const u8, user_data: ?*anyopaque) void {
                _ = user_data;
                _ = level;
                std.log.debug("[{s}] \"{s}\"", .{ prefix, text[0..(text.len - 1)] });
            }
        }.cb,
    });
    log_handler_unregisterrer.unregister();
    // _ = log_handler_unregisterrer;

    try event_loop.register_hook_callback(.{
        .hook = .Load,
        .callback = struct {
            pub fn cb(_: ?*anyopaque) void {
                std.log.debug("Hook load", .{});
            }
        }.cb,
    });

    var loadfile_cmd_args = [_][]const u8{ "loadfile", filename };
    try mpv.command(&loadfile_cmd_args);

    try event_loop.start(.{ .start_new_thread = true, .iter_wait_flag= .{ .IndefiniteWait= {} }, });

    _ = try event_loop.wait_until_playing(.{});
    _ = try event_loop.wait_until_paused(.{});

    const shutdown_evt = event_loop.wait_for_shutdown(.{ .timeout = null }) catch |err| {
        std.log.err("error waiting for shutdown: {}", .{err});
        std.process.exit(2);
    };
    std.log.debug("everything has ended: {}", .{shutdown_evt});
}

