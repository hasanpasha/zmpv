const std = @import("std");
const zmpv = @import("zmpv");
const Mpv = zmpv.Mpv;
const MpvEventCallback = zmpv.MpvEventCallback;

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);

    if (args.len < 2) {
        std.debug.print("usage: {s} [filename]\n", .{args[0]});
        return;
    }

    const filename = args[1];

    var mpv = try Mpv.new(std.heap.page_allocator, .{ .threading = true });
    // &.{
    //     .{ "osc", "yes" },
    //     .{ "input-default-bindings", "yes" },
    //     .{ "input-vo-keyboard", "yes" },
    // });
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

    try mpv.register_event_callback(MpvEventCallback {
        .registered_event_ids = &.{ .EndFile, },
        .callback = &endfile_event_handler,
        .user_data = null,
    });

    while (true) {
        std.time.sleep(10000);
        // const event = try mpv.wait_event(0);
        // switch (event.event_id) {
        //     .EndFile => break,
        //     else => {},
        // }
    }

    // mpv.event_thread.?.join();

    // while (true) {
    //     const event = try mpv.wait_event(10000);
    //     const event_id = event.event_id;
    //     switch (event_id) {
    //         .Shutdown => break,
    //         .LogMessage => {
    //             const log = event.data.LogMessage;
    //             std.log.debug("[{s}] \"{s}\"", .{ log.prefix, log.text });
    //         },
    //         .PropertyChange, .GetPropertyReply => {
    //             const property = event.data.PropertyChange;

    //             if (std.mem.eql(u8, property.name, "fullscreen")) {
    //                 std.log.debug("[fullscreen] {}", .{property.data.Flag});
    //             } else if (std.mem.eql(u8, property.name, "time-pos")) {
    //                 switch (property.data) {
    //                     .INT64 => |time_pos| {
    //                         std.log.debug("[time-pos] {}", .{time_pos});
    //                     },
    //                     else => {},
    //                 }
    //             }
    //         },
    //         else => {},
    //     }
    // }
}

fn endfile_event_handler(user_data: ?*anyopaque) void {
    std.log.debug("endfile handler: {any}", .{user_data});
}