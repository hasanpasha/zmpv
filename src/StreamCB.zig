const std = @import("std");
const c = @import("./c.zig");
const Mpv = @import("./Mpv.zig");
const mpv_error = @import("./mpv_error.zig");
const MpvError = mpv_error.MpvError;
const catch_mpv_error = @import("./utils.zig").catch_mpv_error;

pub const MpvStreamCBInfo = struct {
    cookie: ?*anyopaque,
    read_fn: *const fn (?*anyopaque, []u8, u64) MpvError!u64,
    seek_fn: ?*const fn (?*anyopaque, u64) MpvError!u64,
    size_fn: ?*const fn (?*anyopaque) MpvError!u64,
    close_fn: ?*const fn (?*anyopaque) void,
    cancel_fn: ?*const fn (?*anyopaque) void,
};

const MpvStreamOpenState = struct {
    cb: *const fn (?*anyopaque, []u8, std.mem.Allocator) MpvError!MpvStreamCBInfo,
    user_data: ?*anyopaque,
    arena: std.heap.ArenaAllocator,
};

const MpvStreamState = struct {
    cbs: MpvStreamCBInfo,
    arena: std.heap.ArenaAllocator,
};

const s_cbs = struct {
    pub fn read_cb(inner_state_op: ?*anyopaque, buf: [*c]u8, size: u64) callconv(.C) i64 {
        const inner_state_ptr: *MpvStreamState = @ptrCast(@alignCast(inner_state_op));

        var read_buf: []u8 = undefined;
        read_buf.ptr = buf;
        read_buf.len = size;

        const read_size = inner_state_ptr.cbs.read_fn(inner_state_ptr.cbs.cookie, read_buf, size) catch |err| {
            return mpv_error.to_mpv_c_error(err);
        };

        return @intCast(read_size);
    }

    pub fn close_cb(inner_state_op: ?*anyopaque) callconv(.C) void {
        const inner_state_ptr: *MpvStreamState = @ptrCast(@alignCast(inner_state_op));
        var inner_arena = inner_state_ptr.*.arena;
        defer inner_arena.deinit();
        defer inner_arena.allocator().destroy(inner_state_ptr);

        if (inner_state_ptr.cbs.close_fn) |close_fn| {
            close_fn(inner_state_ptr.cbs.cookie);
        }
    }

    pub fn seek_cb(inner_state_op: ?*anyopaque, offset: i64) callconv(.C) i64 {
        const inner_state_ptr: *MpvStreamState = @ptrCast(@alignCast(inner_state_op));

        if (inner_state_ptr.cbs.seek_fn) |seek_fn| {
            const npos = seek_fn(inner_state_ptr.cbs.cookie, @intCast(offset)) catch |err| {
                return mpv_error.to_mpv_c_error(err);
            };
            return @intCast(npos);
        } else {
            return mpv_error.to_mpv_c_error(MpvError.Unsupported);
        }
    }

    pub fn size_cb(inner_state_op: ?*anyopaque) callconv(.C) i64 {
        const inner_state_ptr: *MpvStreamState = @ptrCast(@alignCast(inner_state_op));

        if (inner_state_ptr.cbs.size_fn) |size_fn| {
            const npos = size_fn(inner_state_ptr.cbs.cookie) catch |err| {
                return mpv_error.to_mpv_c_error(err);
            };
            return @intCast(npos);
        } else {
            return mpv_error.to_mpv_c_error(MpvError.Unsupported);
        }
    }

    pub fn cancel_cb(inner_state_op: ?*anyopaque) callconv(.C) void {
        const inner_state_ptr: *MpvStreamState = @ptrCast(@alignCast(inner_state_op));

        if (inner_state_ptr.cbs.close_fn) |cancel_fn| {
            cancel_fn(inner_state_ptr.cbs.cookie);
        }
    }
};

const s_open_cb = struct {
    pub fn cb(state_op: ?*anyopaque, c_protocol: [*c]u8, info: [*c]c.mpv_stream_cb_info) callconv(.C) c_int {
        const state_ptr: *MpvStreamOpenState = @ptrCast(@alignCast(state_op));

        var arena = state_ptr.arena;
        const allocator = arena.allocator();
        defer allocator.destroy(state_ptr);

        const z_info = state_ptr.cb(
            state_ptr.user_data,
            std.mem.sliceTo(c_protocol, 0),
            allocator,
        ) catch |err| {
            return mpv_error.to_mpv_c_error(err);
        };

        const info_state_ptr = allocator.create(MpvStreamState) catch {
            return mpv_error.to_mpv_c_error(MpvError.LoadingFailed);
        };

        info_state_ptr.*.cbs = z_info;
        info_state_ptr.*.arena = arena;

        info.*.cookie = @ptrCast(@alignCast(info_state_ptr));
        info.*.read_fn = s_cbs.read_cb;
        info.*.close_fn = s_cbs.close_cb;
        info.*.seek_fn = s_cbs.seek_cb;
        info.*.size_fn = s_cbs.size_cb;
        info.*.cancel_fn = s_cbs.cancel_cb;

        return mpv_error.to_mpv_c_error(MpvError.Success);
    }
}.cb;

pub fn stream_cb_add_ro(
    self: Mpv,
    protocol: []const u8,
    user_data: ?*anyopaque,
    open_fn: *const fn (?*anyopaque, []u8, std.mem.Allocator) MpvError!MpvStreamCBInfo,
) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    const state_ptr = try arena.allocator().create(MpvStreamOpenState);
    state_ptr.*.cb = open_fn;
    state_ptr.*.user_data = user_data;
    state_ptr.*.arena = arena;

    try catch_mpv_error(c.mpv_stream_cb_add_ro(self.handle, protocol.ptr, state_ptr, s_open_cb));
}
