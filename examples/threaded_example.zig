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
    // const allocator = gpa.allocator();
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);

    if (args.len < 2) {
        std.debug.print("usage: {s} [filename]\n", .{args[0]});
        return;
    }

    const filename = args[1];

    var mpv = try Mpv.new(allocator, .{ .threading = true });
    try mpv.set_option_string("osc", "yes");
    try mpv.set_option_string("input-default-bindings", "yes");
    try mpv.set_option_string("input-vo-keyboard", "yes");
    try mpv.initialize();
    defer mpv.terminate_destroy();

    const version = Mpv.client_api_version();
    std.debug.print("version={any}.{}\n", .{version >> 16, version & 0xffff});

    var cmd_args = [_][]const u8{ "loadfile", filename };
    try mpv.command_async(0, &cmd_args);

    try mpv.request_log_messages(.Info);

    try mpv.observe_property(1, "fullscreen", .Flag);
    try mpv.observe_property(2, "time-pos", .INT64);

    // try mpv.register_event_callback(MpvEventCallback {
    //     .event_ids = &.{ .EndFile, },
    //     .callback = &endfile_event_handler,
    //     .user_data = null,
    // });

    try mpv.register_event_callback(MpvEventCallback{
        .event_ids = &.{ .StartFile },
        .callback = &startfile_event_handler,
        .user_data = null,
        .callback_cond = null,
    });

    // try mpv.register_event_callback(MpvEventCallback{
    //     .event_ids = &.{ .PropertyChange },
    //     .callback = &property_change_handler,
    //     .user_data = null,
    //     .callback_cond = struct {
    //         pub fn cb(event: MpvEvent) bool {
    //             const property = event.data.PropertyChange;
    //             return (std.mem.eql(u8, property.name, "fullscreen"));
    //         }
    //     }.cb,
    // });
    // try mpv.register_property_callback(MpvPropertyCallback{
    //     .property_name = "fullscreen",
    //     .callback = &fullscreen_observer,
    // });

    // try mpv.register_property_callback(MpvPropertyCallback{
    //     .property_name = "pause",
    //     .callback = struct {
    //         pub fn cb(user_data: ?*anyopaque, data: MpvPropertyData) void {
    //             _ = user_data;
    //             std.log.debug("pause state: {}", .{data.Node.Flag});
    //         }
    //     }.cb,
    // });

    // try mpv.register_property_callback(MpvPropertyCallback{
    //     .property_name = "time-pos",
    //     .callback = struct {
    //         pub fn cb(user_data: ?*anyopaque, data: MpvPropertyData) void {
    //             _ = user_data;
    //             switch (data) {
    //                 .Node => |value| {
    //                     std.log.debug("time-pos: {}", .{value.Double});
    //                 }, else => {},
    //             }
    //         }
    //     }.cb,
    // });

    try mpv.register_log_handler(.{
        .level = .Debug,
        .callback = struct {
            pub fn cb(level: MpvLogLevel, prefix: []const u8, text: []const u8, user_data: ?*anyopaque) void {
                _ = user_data;
                _ = level;
                std.log.debug("[{s}] \"{s}\"", .{prefix, text[0..(text.len-1)]});
            }
        }.cb,
    });


    try mpv.wait_until_playing();
    var pause_args = [_][]const u8{"screenshot"};
    try mpv.register_command_reply_callback(.{
        .command_args = &pause_args,
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
    try mpv.wait_for_playback();
    // std.log.debug("started playing", .{});
    // try mpv.wait_until_pause();
    // std.log.debug("exiting because pause", .{});
    // std.log.debug("done playing", .{});
    // try mpv.wait_for_shutdown();
    // std.log.debug("everything has ended", .{});
}

fn startfile_event_handler(user_data: ?*anyopaque, event: MpvEvent) void  {
    _ = user_data;
    std.log.debug("startfile: {}", .{event.data.StartFile});
}

fn endfile_event_handler(user_data: ?*anyopaque, event: MpvEvent) void {
    _ = user_data;
    std.log.debug("endfile: {}", .{event.data.EndFile});
}

fn fullscreen_observer(user_data: ?*anyopaque, data: MpvPropertyData) void {
    _ = user_data;
    std.log.debug("fullscreen changed: {}", .{data.Node.Flag});
}