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

    // var loadcmd = [_][*:0]const u8{ "loadfile", "sample.mp4" };
    // try mpv.command(&loadcmd);

    // try mpv.command_string("loadfile sample.mp4");
    // try mpv.command_string("cycle pause");
    // try mpv.command_string("cycle mute");

    try mpv.observe_property(0, "fullscreen", .Flag);

    try mpv.set_property_string("fullscreen", "yes");

    const fullscreen_status = try mpv.get_property_string("fullscreen");
    std.debug.print("\n[fullscreen]: {s}\n", .{fullscreen_status});

    while (true) {
        const event = mpv.wait_event(10000);
        switch (event.event_id) {
            .Shutdown => break,
            .PropertyChange => std.debug.print("[event] {?}\n", .{event.data}),
            else => {},
        }
    }
}
