const std = @import("std");
//const glfw = @import("mach-glfw");
const Mpv = @import("./mpv/Mpv.zig");
const MpvFormat = @import("./mpv/mpv_format.zig").MpvFormat;

const c = @cImport({
    @cInclude("mpv/client.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("detected leakage");
    }

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const mpv = try Mpv.new(allocator);

    try mpv.set_option("osc", .Flag, .{ .Flag = true });
    try mpv.set_option("title", .String, .{ .String = "zmpv" });
    try mpv.set_option("input-default-bindings", .Flag, .{ .Flag = true });
    try mpv.set_option("input-vo-keyboard", .Flag, .{ .Flag = true });

    // try mpv.set_option_string("input-default-bindings", "yes");
    // try mpv.set_option_string("input-vo-keyboard", "yes");
    try mpv.initialize();
    defer mpv.terminate_destroy();

    // try mpv.loadfile("sample.mp4", .{});

    var args = [_][]const u8{ "loadfile", "sample.mp4" };
    try mpv.command_async(0, &args);

    try mpv.request_log_messages(.None);

    try mpv.observe_property(0, "fullscreen", .Flag);
    // try mpv.observe_property(0, "time-pos", .Node);
    // try mpv.observe_property(0, "screenshot-raw", .ByteArray);
    try mpv.observe_property(0, "playlist", .Node);

    try mpv.set_property_string("fullscreen", "yes");

    // const fullscreen_status = try mpv.get_property_string("fullscreen");
    // std.debug.print("\n[fullscreen]: {s}\n", .{fullscreen_status});
    // const fullscreen_status = try mpv.get_property("fullscreen", .String);
    // std.log.debug("[fullscreen]: {s}", .{fullscreen_status.String});

    while (true) {
        const event = try mpv.wait_event(10000);
        switch (event.event_id) {
            .Shutdown => break,
            // .CommandReply => {
            //     std.log.debug("[event] {}", .{event});
            // },
            // .PlaybackRestart => {
            //     const filename = try mpv.get_property("filename", .Node);
            //     std.log.debug("[filename]: {s}", .{filename.Node.String});
            // },
            // .PropertyChange => {
            // const property_change = event.data.?.PropertyChange;
            // std.debug.print("[propertyChange] name={s}, {?}\n", .{ property_change.name, property_change.data });
            //     const playlist = try mpv.get_property("playlist", .Node);
            //     std.log.debug("[playlist]: {any}", .{playlist.Node});
            //     // const title_osd = try mpv.get_property("title", .String);
            //     // std.log.debug("[title_osd] {}\n", .{title_osd});
            // },
            // .LogMessage => {
            //     const log = event.data.?.LogMessage;
            //     std.debug.print("[log] {s} \"{s}\"\n", .{ log.level, log.text });
            // },
            // .EndFile => {
            //     const endfile = event.data.?.EndFile;
            //     std.debug.print("[endfile] {any}\n", .{endfile});
            // },
            else => {},
        }
    }
}

test "simple test" {
    const mpv = try Mpv.new(std.testing.allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();
}

test "memory leak" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const mpv = try Mpv.new(allocator);
    try mpv.initialize();

    try mpv.loadfile("sample.mp4", .{});

    while (true) {
        const event = try mpv.wait_event(10000);
        switch (event.event_id) {
            .Shutdown => break,
            .PlaybackRestart => break,
            else => {},
        }
    }

    mpv.terminate_destroy();

    const status = gpa.deinit();
    try std.testing.expect(status == .ok);
}
