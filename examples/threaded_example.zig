const std = @import("std");
const zmpv = @import("zmpv");
const Mpv = zmpv.Mpv;
const MpvError = zmpv.MpvError;
const MpvLogLevel = zmpv.MpvEventLogMessage.MpvLogLevel;
const MpvNode = zmpv.MpvNode;
const MpvEvent = zmpv.MpvEvent;
const MpvEventId = zmpv.MpvEventId;
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
        .start_event_thread = true,
        .options = &.{
            .{"osc", "yes"},
            .{"input-default-bindings", "yes"},
            .{"input-vo-keyboard", "yes"},
        },
    });
    defer mpv.terminate_destroy();

    
    _ = try mpv.register_event_callback(MpvEventCallback {
        .event_ids = &.{ .EndFile, },
        .callback = struct {
            pub fn cb(user_data: ?*anyopaque, event: MpvEvent) void {
                _ = user_data;
                std.log.debug("endfile: {}", .{event.data.EndFile});
            }
        }.cb,
        .user_data = null,
    });

    const startfile_callback_unregisterrer = try mpv.register_event_callback(MpvEventCallback{
        .event_ids = &.{ .StartFile },
        .callback = struct {
            pub fn cb(user_data: ?*anyopaque, event: MpvEvent) void {
                _ = user_data;
                std.log.debug("startfile: {}", .{event});
            }
        }.cb,
        .user_data = null,
        .callback_cond = null,
    });
    // _ = startfile_callback_unregisterrer;
    startfile_callback_unregisterrer.unregister();

    _ = try mpv.register_property_callback(MpvPropertyCallback{
        .property_name = "fullscreen",
        .callback = struct {
            pub fn cb(user_data: ?*anyopaque, data: MpvPropertyData) void {
                _ = user_data;
                std.log.debug("fullscreen changed: {}", .{data.Node.Flag});
            }
        }.cb,
    });

    _ = try mpv.register_property_callback(MpvPropertyCallback{
        .property_name = "pause",
        .callback = struct {
            pub fn cb(user_data: ?*anyopaque, data: MpvPropertyData) void {
                _ = user_data;
                std.log.debug("pause state: {}", .{data.Node.Flag});
            }
        }.cb,
    });

    const time_pos_callback_unregisterrer = try mpv.register_property_callback(MpvPropertyCallback{
        .property_name = "time-pos",
        .callback = struct {
            pub fn cb(user_data: ?*anyopaque, data: MpvPropertyData) void {
                _ = user_data;
                switch (data) {
                    .Node => |value| {
                        std.log.debug("time-pos: {}", .{value.Double});
                    }, else => {},
                }
            }
        }.cb,
    });
    time_pos_callback_unregisterrer.unregister();
    // _ = time_pos_callback_unregisterrer;

    const log_handler_unregisterrer = try mpv.register_log_message_handler(.{
        .level = .V,
        .callback = struct {
            pub fn cb(level: MpvLogLevel, prefix: []const u8, text: []const u8, user_data: ?*anyopaque) void {
                _ = user_data;
                _ = level;
                std.log.debug("[{s}] \"{s}\"", .{prefix, text[0..(text.len-1)]});
            }
        }.cb,
    });
    // log_handler_unregisterrer.unregister();
    _ = log_handler_unregisterrer;

    var loadfile_cmd_args = [_][]const u8{ "loadfile", filename };
    // try mpv.wait_until_playing();
    const command_callback_unregisterrer = try mpv.register_command_reply_callback(.{
        .command_args = &loadfile_cmd_args,
        .callback = struct {
            pub fn cb(cmd_error: MpvError, result: MpvNode, user_data: ?*anyopaque) void {
                _ = user_data;
                if (cmd_error == MpvError.Success) {
                    std.log.debug("command result: {}", .{result});
                } else {
                    std.log.debug("error running command: {}", .{cmd_error});
                }
                // _ = cmd_error;
            }
        }.cb,
    });
    // command_callback_unregisterrer.unregister();
    _ = command_callback_unregisterrer;
    try mpv.wait_for_playback();
    // std.log.debug("started playing", .{});
    // try mpv.wait_until_pause();
    // std.log.debug("exiting because pause", .{});
    // std.log.debug("done playing", .{});
    // try mpv.wait_for_shutdown();
    // std.log.debug("everything has ended", .{});
}