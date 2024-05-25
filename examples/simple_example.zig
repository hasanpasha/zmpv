const std = @import("std");
const zmpv = @import("zmpv");
const Mpv = zmpv.Mpv;

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);

    if (args.len < 2) {
        std.debug.print("usage: {s} [filename]\n", .{args[0]});
        return;
    }

    const filename = args[1];

    const mpv = try Mpv.create(std.heap.page_allocator, &.{
        .{"osc", "yes"},
        .{"input-default-bindings", "yes"},
        .{"input-vo-keyboard", "yes"},
    });

    try mpv.initialize();
    defer mpv.terminate_destroy();

    var cmd_args = [_][]const u8{ "loadfile", filename };
    try mpv.command_async(0, &cmd_args);

    try mpv.request_log_messages(.Error);

    try mpv.observe_property(1, "fullscreen", .Flag);
    try mpv.observe_property(2, "time-pos", .INT64);

    while (true) {
        const event = try mpv.wait_event(10000);
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
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }
    }
}