const std = @import("std");
const c = @import("c.zig");
const Mpv = @import("Mpv.zig");
const mpv_error = @import("mpv_error.zig");
const MpvError = mpv_error.MpvError;
const utils = @import("utils.zig");

pub const MpvStreamCBInfo = struct {
    protocol: []const u8,
    userdata: ?*anyopaque = null,
    open_fn: *const fn (?*anyopaque, []u8) MpvError!?*anyopaque,
    read_fn: *const fn (?*anyopaque, []u8, u64) MpvError!u64,
    cancel_fn: ?*const fn (?*anyopaque) void = null,
    seek_fn: ?*const fn (?*anyopaque, u64) MpvError!u64 = null,
    size_fn: ?*const fn (?*anyopaque) MpvError!u64 = null,
    close_fn: *const fn (?*anyopaque) void,
};

pub inline fn stream_cb_add_ro(
    self: Mpv,
    cb_info: MpvStreamCBInfo,
) !void {

    const c_open_wrapper = struct {
        pub fn cb(data: ?*anyopaque, uri: [*c]u8, c_info: [*c]c.mpv_stream_cb_info) callconv(.C) c_int  {
            const cookie = @call(.always_inline, cb_info.open_fn, .{ data, std.mem.sliceTo(uri, 0) }) catch |err| {
                return mpv_error.to_mpv_c_error(err);
            };

            c_info.*.cookie = cookie;

            c_info.*.read_fn = struct {
                pub fn cb(cookie_p: ?*anyopaque, buf: [*c]u8, s: u64) callconv(.C) i64 {
                    var bb: []u8 = undefined;
                    bb.ptr = buf;
                    bb.len = @intCast(s);
                    const ss = @call(.always_inline, cb_info.read_fn, .{ cookie_p, bb, s }) catch |err| {
                        return mpv_error.to_mpv_c_error(err);
                    };
                    return @intCast(ss);
                }
            }.cb;

            c_info.*.close_fn = struct {
                pub fn cb(cookie_p: ?*anyopaque) callconv(.C) void {
                    @call(.always_inline, cb_info.close_fn, .{ cookie_p });
                }
            }.cb;

            if (cb_info.cancel_fn) |fun| {
                c_info.*.cancel_fn = struct {
                    pub fn cb(cookie_p: ?*anyopaque) callconv(.C) void {
                        @call(.always_inline, fun, .{ cookie_p });
                    }
                }.cb;
            }

            if (cb_info.seek_fn) |fun| {
                c_info.*.seek_fn = struct {
                    pub fn cb(cookie_p: ?*anyopaque, offset: i64) callconv(.C) i64 {
                        const offset_arg: u64 = @intCast(offset);
                        const result_offset = @call(.always_inline, fun, .{ cookie_p, offset_arg }) catch |err| {
                            return mpv_error.to_mpv_c_error(err);
                        };
                        return @intCast(result_offset);
                    }
                }.cb;
            }

            if (cb_info.size_fn) |fun| {
                c_info.*.size_fn = struct {
                    pub fn cb(cookie_p: ?*anyopaque) callconv(.C) i64 {
                        const size = @call(.always_inline, fun, .{ cookie_p }) catch |err| {
                            return mpv_error.to_mpv_c_error(err);
                        };
                        return @intCast(size);
                    }
                }.cb;
            }

            return mpv_error.to_mpv_c_error(MpvError.Success);
        }
    }.cb;

    try utils.catch_mpv_error(c.mpv_stream_cb_add_ro(self.handle, cb_info.protocol.ptr, cb_info.userdata, c_open_wrapper));
}
