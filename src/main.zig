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

    try mpv.hook_add(0, "on_load", 0);

    try mpv.loadfile("sample.mp4", .{});

    // var args = [_][]const u8{"screenshot-raw"};
    // const result = try mpv.command_ret(&args);
    // std.log.debug("[screenshot-raw result] {}", .{result});

    // var args = [_][]const u8{ "cycle", "pause" };
    // var load_args = [_][]const u8{ "loadfile", "sample.mp4" };
    // try mpv.command_async(6969, &load_args);
    // mpv.abort_async_command(6969);

    try mpv.request_log_messages(.None);

    try mpv.observe_property(11, "fullscreen", .Flag);
    try mpv.unobserve_property(11);
    try mpv.observe_property(0, "time-pos", .Double);
    // try mpv.observe_property(0, "screenshot-raw", .ByteArray);
    // try mpv.observe_property(0, "playlist", .Node);

    // try mpv.set_property_string("fullscreen", "yes");

    try mpv.set_property("fullscreen", .Node, .{ .Node = .{ .Flag = true } });

    // const fullscreen_status = try mpv.get_property_string("fullscreen");
    // std.debug.print("\n[fullscreen]: {s}\n", .{fullscreen_status});
    // const fullscreen_status = try mpv.get_property("fullscreen", .String);
    // std.log.debug("[fullscreen]: {s}", .{fullscreen_status.String});

    var time_pos_not_changed = true;
    while (true) {
        const event = try mpv.wait_event(10000);
        switch (event.event_id) {
            .Shutdown => break,
            .CommandReply => {
                std.log.debug("[event] {}", .{event.data.CommandReply.result});
            },
            // .FileLoaded => {
            //     var args = [_][]const u8{"screenshot-raw"};
            //     try mpv.command(&args);
            // },
            .Hook => {
                std.log.debug("[event] hook {}", .{event.data});

                std.log.debug("HANDLING {s} hook", .{event.data.Hook.name});

                // for (0..100) |i| {
                //     std.log.debug("DOING WORK {}", .{i});
                // }

                std.log.debug("CONTINUING", .{});
                try mpv.hook_continue(event.data.Hook.id);
            },
            // .PlaybackRestart => {
            //     // const filename = try mpv.get_property("filename", .Node);
            //     // std.log.debug("[filename]: {s}", .{filename.Node.String});
            // },
            .PropertyChange => {
                const property_change = event.data.PropertyChange;
                //     std.log.debug("[property_change] name={s} value={any}", .{ property_change.name, property_change.data });
                //     std.debug.print("[propertyChange] name={s}, {?}\n", .{ property_change.name, property_change.data });
                //     //     const playlist = try mpv.get_property("playlist", .Node);
                //     //     std.log.debug("[playlist]: {any}", .{playlist.Node});
                //     //     // const title_osd = try mpv.get_property("title", .String);
                //     //     // std.log.debug("[title_osd] {}\n", .{title_osd});

                if (std.mem.eql(u8, property_change.name, "time-pos")) {
                    switch (property_change.data) {
                        .Double => |num| {
                            // std.log.debug("TIME-POS {}", .{num});
                            if (num >= 3.14 and time_pos_not_changed) {
                                time_pos_not_changed = false;
                                // try mpv.set_property("time-pos", .Double, .{ .Double = num * 2 });
                                var args = [_][]const u8{"screenshot-raw"};
                                const data = try mpv.command_ret(&args);
                                // std.log.debug("[screenshot] {?}", .{data.NodeMap.get("data")});
                                std.log.debug("[screenshot] format={s}", .{data.NodeMap.get("format").?.String});
                                std.log.debug("[screenshot] w={}", .{data.NodeMap.get("w").?.INT64});
                                std.log.debug("[screenshot] h={}", .{data.NodeMap.get("h").?.INT64});
                                std.log.debug("[screenshot] stride={}", .{data.NodeMap.get("stride").?.INT64});
                                // var stop_cmd = [_][]const u8{"quit"};
                                // try mpv.command(&stop_cmd);
                            }
                        },
                        else => {},
                    }
                }
            },
            .LogMessage => {
                const log = event.data.LogMessage;
                std.log.debug("[log] {s} \"{s}\"", .{ log.level, log.text });
            },
            .EndFile => {
                const endfile = event.data.EndFile;
                std.debug.print("[endfile] {any}\n", .{endfile});
            },
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
