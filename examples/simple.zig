const std = @import("std");
// const zmpv = @import("zmpv");
const zmpv = @import("zmpv");
const MpvHandle = zmpv.MpvHandle;
const config = @import("config");

pub fn main() !void {
    const filepath = config.filepath;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) @panic("memory leak");
    }
    const allocator = gpa.allocator();

    const mpv = try MpvHandle.create_z();
    try mpv.initialize_z();
    try mpv.set_option_z(allocator, "osc", .{ .flag = true });
    try mpv.set_option_z(allocator, "input-default-bindings", .{ .flag = true });
    try mpv.set_option_z(allocator, "input-vo-keyboard", .{ .flag = true });
    defer mpv.terminate_destroy();

    const version = zmpv.client_api_version_z();
    std.debug.print("version={any}\n", .{version});

    try mpv.command_async_z(allocator, 0, &.{ "loadfile", filepath });

    try zmpv.check_error_z(mpv.request_log_messages("error"));

    try zmpv.check_error_z(mpv.observe_property(1, "fullscreen", .flag));
    try zmpv.check_error_z(mpv.observe_property(2, "time-pos", .int64));

    // try mpv.cycle("fullscreen", .{ .direction = .Down });
    const fullscreen_status = try mpv.get_property_z(allocator, "fullscreen", .string);
    defer fullscreen_status.free(allocator);
    // defer zmpv.free_z(allocator, fullscreen_status);
    std.log.debug("fullscreen={s}", .{fullscreen_status.string});

    while (true) {
        const event = mpv.wait_event_z(.{ .indefinite = {} });
        if (event.id == .shutdown or event.id == .end_file) break;
        switch (event.get_data_z()) {
            .log_message => |log| {
                std.log.debug("[{s}] \"{s}\"", .{ log.prefix, log.text });
            },
            .property_change => |_| {
                // std.log.debug("property: {}", .{property});

                // if (std.mem.eql(u8, property.name, "fullscreen")) {
                //     std.log.debug("[fullscreen] {}", .{property.data.Flag});
                // } else if (std.mem.eql(u8, property.name, "time-pos")) {
                //     if (property.format() == .INT64) {
                //         std.log.debug("[time-pos] {}", .{property.data.INT64});
                //     }
                // }
            },
            else => {},
        }
    }
}
