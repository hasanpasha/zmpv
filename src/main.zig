const std = @import("std");
//const glfw = @import("mach-glfw");
const Mpv = @import("./mpv/Mpv.zig");
const MpvFormat = @import("./mpv/mpv_format.zig").MpvFormat;

const c = @cImport({
    @cInclude("mpv/client.h");
});

pub fn main() !void {
    //_ = c.mpv_set_option(ctx, "osc", c.MPV_FORMAT_FLAG, &val);
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer {
    //     const deinit_status = gpa.deinit();
    //     if (deinit_status == .leak) @panic("detected leakage");
    // }
    // const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const mpv = try Mpv.new(allocator);
    // const mpv = try Mpv.new(std.heap.page_allocator);

    try mpv.set_option_string("input-default-bindings", "yes");
    try mpv.set_option_string("input-vo-keyboard", "yes");
    try mpv.initialize();
    defer mpv.terminate_destroy();

    var args = [_][]const u8{ "loadfile", "sample.mp4" };
    try mpv.command(&args);

    try mpv.request_log_messages(.None);

    try mpv.observe_property(0, "fullscreen", .Flag);
    // try mpv.observe_property(0, "time-pos", .Node);
    // try mpv.observe_property(0, "screenshot-raw", .ByteArray);
    try mpv.observe_property(0, "playlist", .Node);

    try mpv.set_property_string("fullscreen", "yes");

    const fullscreen_status = try mpv.get_property_string("fullscreen");
    std.debug.print("\n[fullscreen]: {s}\n", .{fullscreen_status});

    while (true) {
        const event = try mpv.wait_event(10000);
        switch (event.event_id) {
            .Shutdown => break,
            // .PropertyChange => {
            //     const optional_data = event.data;
            //     if (optional_data) |data| {
            //         switch (data) {
            //             .EndFile => |end_file| {
            //                 std.debug.print("[event] {?}\n", .{end_file});
            //             },
            //             .StartFile => |start_file| {
            //                 // std.debug.print("[event] {?}\n", .{start_file});
            //             },
            //             .PropertyChange => |property_change| {
            //                 // std.debug.print("[event] name={s}, {?}\n", .{ property_change.name, property_change });
            //             },
            //             .LogMessage => |log_message| {
            //                 // std.debug.print("[event] log_level = {s}\n", .{log_message.level});
            //             },
            //             .None => {},
            //         }
            //     }
            // },
            .LogMessage => {
                const log = event.data.?.LogMessage;
                std.debug.print("[log] {s} \"{s}\"\n", .{ log.level, log.text });
            },
            else => {},
        }
    }
}
