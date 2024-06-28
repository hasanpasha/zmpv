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
    log_handler_unregisterrer.unregister();
    // _ = log_handler_unregisterrer;

    var loadfile_cmd_args = [_][]const u8{ "loadfile", filename };
    try mpv.command_async(0, &loadfile_cmd_args);
    // try mpv.command(&loadfile_cmd_args);
    // try mpv.wait_until_playing();
    // const command_callback_unregisterrer = try mpv.register_command_reply_callback(.{
    //     .command_args = &loadfile_cmd_args,
    //     .callback = struct {
    //         pub fn cb(cmd_error: MpvError, result: MpvNode, user_data: ?*anyopaque) void {
    //             _ = user_data;
    //             if (cmd_error == MpvError.Success) {
    //                 // std.log.debug("command result: {}", .{result});
    //             } else {
    //                 // std.log.debug("error running command: {}", .{cmd_error});
    //             }
    //             // _ = cmd_error;
    //         }
    //     }.cb,
    // });
    // command_callback_unregisterrer.unregister();
    // _ = command_callback_unregisterrer;

    // _ = try mpv.wait_for_event(&.{ .Seek }, struct {
    //     pub fn cb(event: MpvEvent) bool {
    //         return (event.event_error == MpvError.Success);
    //     }
    // }.cb);
    // std.log.debug("seeked", .{});

    _ = mpv.wait_for_property("fullscreen", .{ .cond_cb = struct {
        pub fn cb(data: MpvPropertyData) bool {
            return data.Node.Flag;
        }
    }.cb, .timeout = 5}) catch |err| {
        std.log.err("error waiting for fullscreen=true property: {}", .{err});
    };

    // try skip_silence(mpv);
    // std.log.debug("finished skipping", .{});
    // try skip_silence(mpv);
    // try skip_silence(mpv);
    // _ = mpv.wait_for_playback() catch |err| {
    //     std.log.err("error waiting for playback: {}", .{err});
    //     std.process.exit(1);
    // };
    // std.log.debug("started playing", .{});
    // try mpv.wait_until_pause();
    // std.log.debug("exiting because pause", .{});
    // std.log.debug("done playing", .{});
    const shutdown_evt = mpv.wait_for_shutdown(.{ .timeout = null }) catch |err| {
        std.log.err("error waiting for shutdown: {}", .{err});
        std.process.exit(2);
    };
    std.log.debug("everything has ended: {}", .{shutdown_evt});
}

fn skip_silence(mpv: *Mpv) !void {
    try mpv.request_log_messages(.Debug);
    try mpv.set_property_string("af", "lavfi=[silencedetect=n=-20dB:d=1]");
    try mpv.set_property("speed", .INT64, .{ .INT64 = 100 });
    const result = try mpv.wait_for_event(&.{ .LogMessage }, struct {
        pub fn cb(event: MpvEvent) bool {
            const log = event.data.LogMessage;
            const text = log.text[0..(log.text.len-1)];
            var iter = std.mem.split(u8, text, " ");
            while (iter.next()) |tok| {
                if (std.mem.eql(u8, tok, "silence_end:")) {
                    std.log.debug("found silence end: {s}", .{iter.peek().?});
                    return true;
                }
            }
            return false;
        }
    }.cb);
    std.log.debug("got seek result", .{});
    var iter = std.mem.split(u8, result.data.LogMessage.text, " ");
    while (iter.next()) |tok| {
        if (std.mem.eql(u8, tok, "silence_end:")) {
            const pos = iter.peek().?;
            const pos_dup = try mpv.allocator.dupe(u8, pos);
            defer mpv.allocator.free(pos_dup);
            // std.log.debug("seek to: {s}", .{pos});
            try mpv.set_property_string("time-pos", "105.766");
            // try mpv.set_property_string("time-pos", pos);
        }
    }
    try mpv.request_log_messages(.None);
    try mpv.set_property("speed", .INT64, .{ .INT64 = 1 });
    try mpv.set_property_string("af", "");
    std.log.debug("returning", .{});
}