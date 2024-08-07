const std = @import("std");
const Mpv = @import("zmpv").Mpv;
const MpvError = @import("zmpv").MpvError;
const config = @import("config");

fn seek_cb(cookie: ?*anyopaque, offset: u64) MpvError!u64 {
    if (cookie) |fdp| {
        const fd: *std.fs.File = @ptrCast(@alignCast(fdp));

        const locked = fd.tryLock(.exclusive) catch {
            return MpvError.Unsupported;
        };

        if (!locked) {
            return MpvError.Unsupported;
        }

        fd.seekTo(offset) catch {
            return MpvError.Unsupported;
        };

        const apos = fd.getPos() catch {
            return MpvError.Unsupported;
        };

        fd.unlock();

        return apos;
    } else {
        return MpvError.Unsupported;
    }
}

fn size_cb(cookie: ?*anyopaque) MpvError!u64 {
    if (cookie) |fdp| {
        const fd: *std.fs.File = @ptrCast(@alignCast(fdp));
        const meta = fd.metadata() catch {
            return MpvError.Unsupported;
        };

        const size = meta.size();

        std.log.debug("returning size {}", .{size});

        return size;
    } else {
        return MpvError.Unsupported;
    }
}

fn read_cb(cookie: ?*anyopaque, buf: []u8, size: u64) MpvError!u64 {
    // std.log.debug("reading", .{});
    if (cookie) |fdp| {
        // std.log.debug("file is here", .{});
        const fd: *std.fs.File = @ptrCast(@alignCast(fdp));

        _ = size;

        const locked = fd.tryLock(.exclusive) catch {
            return MpvError.Generic;
        };

        if (!locked) {
            return MpvError.Generic;
        }

        const read_size = fd.read(buf) catch {
            return MpvError.Generic;
        };

        fd.unlock();

        return @intCast(read_size);
    } else {
        return MpvError.Generic;
    }
}

fn close_cb(cookie: ?*anyopaque) void {
    const fdp: *std.fs.File = @ptrCast(@alignCast(cookie));
    fdp.close();
    std.heap.c_allocator.destroy(fdp);
}

fn open_cb(user_data: ?*anyopaque, uri: []u8) MpvError!?*anyopaque {
    _ = user_data;

    const filename = uri[6..];
    std.log.debug("opening {s}", .{filename});

    const fd = std.fs.cwd().openFile(filename, .{}) catch {
        return MpvError.LoadingFailed;
    };

    const file_ptr = std.heap.c_allocator.create(std.fs.File) catch {
        return MpvError.LoadingFailed;
    };
    file_ptr.* = fd;

    return file_ptr;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const state = gpa.deinit();
        if (state == .leak) {
            @panic("leakage detcted");
        }
    }
    const allocator = gpa.allocator();

    const filepath = config.filepath;

    var mpv = try Mpv.init(allocator, &.{
        .{ .name = "osc", .value = .{ .Flag = true } },
        .{ .name = "input-default-bindings", .value = .{ .Flag = true } },
        .{ .name = "input-vo-keyboard", .value = .{ .Flag = true } },
    });
    defer mpv.deinit(.{});

    try mpv.stream_cb_add_ro(.{
        .protocol = "zig",
        // .userdata = null,
        .open_fn = &open_cb,
        .read_fn = &read_cb,
        .close_fn = &close_cb,
        // .cancel_fn = null,
        .seek_fn = &seek_cb,
        .size_fn = &size_cb,
    });

    const uri = try std.fmt.allocPrint(allocator, "zig://{s}", .{filepath});
    defer allocator.free(uri);

    try mpv.command_async(0, &.{ "loadfile", uri });

    try mpv.request_log_messages(.Error);

    const fullscreen = try mpv.get_property("title", .OSDString);
    defer mpv.free(fullscreen);
    std.log.info("fullscreen = {s}", .{fullscreen.OSDString});

    try mpv.observe_property(1, "fullscreen", .String);
    try mpv.observe_property(2, "time-pos", .INT64);

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
                    std.log.debug("[fullscreen] {s}", .{property.data.String});
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
