const std = @import("std");
const Mpv = @import("zmpv").Mpv;
const MpvError = @import("zmpv").MpvError;

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
}

fn open_cb(user_data: ?*anyopaque, uri: []u8, allocator: std.mem.Allocator) MpvError!Mpv.MpvStreamCBInfo {
    _ = user_data;

    const filename = std.mem.sliceTo(uri[6..], 0);
    std.log.debug("opening {s}", .{filename});

    const fd = std.fs.cwd().openFile(filename, .{}) catch {
        return MpvError.LoadingFailed;
    };

    const file_ptr = allocator.create(std.fs.File) catch {
        return MpvError.LoadingFailed;
    };
    file_ptr.* = fd;

    return Mpv.MpvStreamCBInfo{
        .cookie = @ptrCast(file_ptr),
        .read_fn = &read_cb,
        .close_fn = &close_cb,
        .seek_fn = &seek_cb,
        .size_fn = &size_cb,
        .cancel_fn = null,
    };
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

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("usage: {s} [filename]\n", .{args[0]});
        return;
    }

    const filename = args[1];

    const mpv = try Mpv.create(allocator, null);

    try mpv.set_option("osc", .Flag, .{ .Flag = true });
    try mpv.set_option("input-default-bindings", .Flag, .{ .Flag = true });
    try mpv.set_option("input-vo-keyboard", .Flag, .{ .Flag = true });

    try mpv.initialize();
    defer mpv.terminate_destroy();

    try mpv.stream_cb_add_ro("zig", null, &open_cb);

    const uri = try std.fmt.allocPrint(allocator, "zig://{s}", .{filename});
    defer allocator.free(uri);

    var cmd_args = [_][]const u8{ "loadfile", uri };
    try mpv.command_async(0, &cmd_args);

    try mpv.request_log_messages(.Error);

    const fullscreen = try mpv.get_property("title", .OSDString);
    defer mpv.free(fullscreen);
    std.log.info("fullscreen = {s}", .{fullscreen.OSDString});

    try mpv.observe_property(1, "fullscreen", .String);
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
