const std = @import("std");
const zmpv = @import("zmpv");
const Mpv = zmpv.Mpv;
const config = @import("config");

pub fn main() !void {
    const filepath = config.filepath;

    const mpv = try Mpv.create_and_initialize(std.heap.page_allocator, &.{
        .{ "osc", "yes" },
        .{ "input-default-bindings", "yes" },
        .{ "input-vo-keyboard", "yes" },
    });
    defer mpv.terminate_destroy();

    const version = Mpv.client_api_version();
    std.debug.print("version={any}.{}\n", .{ version >> 16, version & 0xffff });

    try mpv.command_async(0, &.{"loadfile", filepath});

    try mpv.request_log_messages(.Error);

    try mpv.observe_property(1, "fullscreen", .Flag);
    try mpv.observe_property(2, "time-pos", .INT64);

    try mpv.cycle("fullscreen", .{ .direction = .Down });
    const fullscreen_status = try mpv.get_property("fullscreen", .String);
    std.log.debug("fullscreen={s}", .{fullscreen_status.String});
    defer mpv.free(fullscreen_status);

    var seeked = false;
    while (true) {
        const event = mpv.wait_event(10000);
        const event_id = event.event_id;
        switch (event_id) {
            .Shutdown => break,
            .LogMessage => {
                const log = event.data.LogMessage;
                std.log.debug("[{s}] \"{s}\"", .{ log.prefix, log.text });
            },
            .PropertyChange, .GetPropertyReply => {
                const property = event.data.PropertyChange;

                if (std.mem.eql(u8, property.name, "fullscreen")) {
                    std.log.debug("[fullscreen] {}", .{property.data.Flag});
                } else if (std.mem.eql(u8, property.name, "time-pos")) {
                    switch (property.data) {
                        .INT64 => |time_pos| {
                            std.log.debug("[time-pos] {}", .{time_pos});
                            if (!seeked) {
                                try mpv.run("ls", &.{"-la"});
                                try mpv.seek("50", .{ .reference = .Absolute, .precision = .Percent });
                                std.time.sleep(5 * 1e8);
                                try mpv.revert_seek(.{});
                                seeked = true;
                            }
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }
    }
}
