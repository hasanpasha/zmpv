const std = @import("std");
const c = @import("./mpv/c.zig");
const Mpv = @import("./mpv/Mpv.zig");

fn seek_cb(cookie: ?*anyopaque, offset: i64) callconv(.C) i64 {
    if (cookie) |fdp| {
        const fd: *std.fs.File = @ptrCast(@alignCast(fdp));
        fd.seekBy(offset) catch {
            return c.MPV_ERROR_UNSUPPORTED;
        };
        const pos = fd.getPos() catch {
            return c.MPV_ERROR_UNSUPPORTED;
        };
        return @intCast(pos);
    } else {
        return c.MPV_ERROR_UNSUPPORTED;
    }
}

fn read_cb(cookie: ?*anyopaque, buf: [*c]u8, size: u64) callconv(.C) i64 {
    _ = size;

    const fd = std.fs.cwd().openFile("sample.mp4", .{}) catch {
        return -2;
    };

    if (cookie) |fdp| {
        // const fd: *std.fs.File = @ptrCast(@alignCast(fdp));
        _ = fdp;
        const read_size = fd.read(std.mem.sliceTo(buf, 0)) catch {
            return -1;
        };
        std.log.debug("read_size = {}", .{read_size});
        return @intCast(read_size);
    } else {
        return -1;
    }
}

fn close_cb(cookie: ?*anyopaque) callconv(.C) void {
    // const fdp: *std.fs.File = @ptrCast(@alignCast(cookie.?));
    // fdp.*.close();
    _ = cookie;
}

fn open_cb(user_data: ?*anyopaque, uri: [*c]u8, info: [*c]c.mpv_stream_cb_info) callconv(.C) c_int {
    _ = user_data;

    const filename = std.mem.sliceTo(uri[6..], 0);
    std.log.debug("opening {s}", .{filename});

    var fd = std.fs.cwd().openFile(filename, .{}) catch {
        return c.MPV_ERROR_LOADING_FAILED;
    };

    info.*.cookie = @ptrCast(&fd);
    info.*.read_fn = &read_cb;
    info.*.seek_fn = &seek_cb;
    info.*.close_fn = &close_cb;

    return 0;
}

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);

    if (args.len < 2) {
        std.debug.print("usage: {s} [filename]\n", .{args[0]});
        return;
    }

    const filename = args[1];
    _ = filename;

    const mpv = try Mpv.create(std.heap.page_allocator);

    try mpv.set_option("osc", .Flag, .{ .Flag = true });
    try mpv.set_option("input-default-bindings", .Flag, .{ .Flag = true });
    try mpv.set_option("input-vo-keyboard", .Flag, .{ .Flag = true });

    try mpv.initialize();
    defer mpv.terminate_destroy();

    _ = c.mpv_stream_cb_add_ro(mpv.handle, "foo", null, &open_cb);

    var cmd_args = [_][]const u8{ "loadfile", "foo://sample.mp4" };
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
