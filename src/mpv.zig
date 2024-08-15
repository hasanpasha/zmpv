const std = @import("std");
const Allocator = std.mem.Allocator;
const AllocatorError = Allocator.Error;
const ArenaAllocator = std.heap.ArenaAllocator;
const sliceTo = std.mem.sliceTo;

pub fn client_api_version() c_ulong {
    const cFn = @extern(*const fn () callconv(.C) c_ulong, .{ .name = "mpv_client_api_version" });
    return cFn();
}

pub fn client_api_version_z() struct { major: u16, minor: u16 } {
    const version = client_api_version();
    return .{ .major = @intCast(version >> 16), .minor = @intCast(version & 0xffff) };
}

pub fn error_string(ret_code: c_int) [*c]const u8 {
    const cFn = @extern(*const fn (c_int) callconv(.C) [*c]const u8, .{ .name = "mpv_error_string" });
    return cFn(ret_code);
}

/// `mpv_free`
pub fn free(data: ?*anyopaque) void {
    const cFn = @extern(*const fn (?*anyopaque) callconv(.C) void, .{ .name = "mpv_free" });
    return cFn(data);
}

/// Generic functions to free memory allocated by the library's helper functions
pub fn free_z(allocator: Allocator, data: anytype) void {
    switch (@TypeOf(data)) {
        MpvFormatDataZ => data.free(allocator),
        MpvNodeZ => data.free(allocator),
        else => {},
    }
}

pub fn check_error_z(ret_code: c_int) MpvErrorZ!void {
    if (ret_code < 0) {
        return MpvError.raise_error_z(MpvError.from_ret_code_z(ret_code));
    }
}

pub const MpvHandle = opaque {
    pub fn client_name(self: *MpvHandle) [*c]const u8 {
        const cFn = @extern(*const fn (?*MpvHandle) callconv(.C) [*c]const u8, .{ .name = "mpv_client_name" });
        return cFn(self);
    }

    pub fn client_id(self: *MpvHandle) i64 {
        const cFn = @extern(*const fn (?*MpvHandle) callconv(.C) i64, .{ .name = "mpv_client_id" });
        return cFn(self);
    }

    pub fn create() ?*MpvHandle {
        const cFn = @extern(*const fn () callconv(.C) ?*MpvHandle, .{ .name = "mpv_create" });
        return cFn();
    }

    pub fn initialize(self: *MpvHandle) c_int {
        const cFn = @extern(*const fn (?*MpvHandle) callconv(.C) c_int, .{ .name = "mpv_initialize" });
        return cFn(self);
    }

    pub fn destroy(self: *MpvHandle) void {
        const cFn = @extern(*const fn (?*MpvHandle) callconv(.C) void, .{ .name = "mpv_destroy" });
        return cFn(self);
    }

    pub fn terminate_destroy(self: *MpvHandle) void {
        const cFn = @extern(*const fn (?*MpvHandle) callconv(.C) void, .{ .name = "mpv_terminate_destroy" });
        return cFn(self);
    }

    pub fn create_client(self: *MpvHandle, name: [*c]const u8) ?*MpvHandle {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]const u8) callconv(.C) ?*MpvHandle, .{ .name = "mpv_create_client" });
        return cFn(self, name);
    }

    pub fn create_weak_client(self: *MpvHandle, name: [*c]const u8) ?*MpvHandle {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]const u8) callconv(.C) ?*MpvHandle, .{ .name = "mpv_create_weak_client" });
        return cFn(self, name);
    }

    pub fn load_config_file(self: *MpvHandle, filename: [*c]const u8) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]const u8) callconv(.C) c_int, .{ .name = "mpv_load_config_file" });
        return cFn(self, filename);
    }

    pub fn get_time_ns(self: *MpvHandle) i64 {
        const cFn = @extern(*const fn (?*MpvHandle) callconv(.C) i64, .{ .name = "mpv_get_time_ns" });
        return cFn(self);
    }

    pub fn get_time_us(self: *MpvHandle) i64 {
        const cFn = @extern(*const fn (?*MpvHandle) callconv(.C) i64, .{ .name = "mpv_get_time_us" });
        return cFn(self);
    }

    pub fn set_option(self: *MpvHandle, name: [*c]const u8, format: MpvFormat, data: ?*anyopaque) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]const u8, MpvFormat, ?*anyopaque) callconv(.C) c_int, .{ .name = "mpv_set_option" });
        return cFn(self, name, format, data);
    }

    pub fn set_option_string(self: *MpvHandle, name: [*c]const u8, data: [*c]const u8) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]const u8, [*c]const u8) callconv(.C) c_int, .{ .name = "mpv_set_option_string" });
        return cFn(self, name, data);
    }

    pub fn command(self: *MpvHandle, args: [*c][*c]const u8) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, [*c][*c]const u8) callconv(.C) c_int, .{ .name = "mpv_command" });
        return cFn(self, args);
    }

    pub fn command_node(self: *MpvHandle, args: [*c]MpvNode, result: [*c]MpvNode) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]MpvNode, [*c]MpvNode) callconv(.C) c_int, .{ .name = "mpv_command_node" });
        return cFn(self, args, result);
    }

    pub fn command_ret(self: *MpvHandle, args: [*c][*c]const u8, result: [*c]MpvNode) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, [*c][*c]const u8, [*c]MpvNode) callconv(.C) c_int, .{ .name = "mpv_command_ret" });
        return cFn(self, args, result);
    }

    pub fn command_string(self: *MpvHandle, args: [*c]const u8) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]const u8) callconv(.C) c_int, .{ .name = "mpv_command_string" });
        return cFn(self, args);
    }

    pub fn command_async(self: *MpvHandle, reply_userdata: u64, args: [*c][*c]const u8) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, u64, [*c][*c]const u8) callconv(.C) c_int, .{ .name = "mpv_command_async" });
        return cFn(self, reply_userdata, args);
    }

    pub fn command_node_async(self: *MpvHandle, reply_userdata: u64, args: [*c]MpvNode) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, u64, [*c]MpvNode) callconv(.C) c_int, .{ .name = "mpv_command_node_async" });
        return cFn(self, reply_userdata, args);
    }
    // TODO mpv_command_node_async(ctx: ?*mpv_handle, reply_userdata: u64, args: [*c]mpv_node) c_int;

    pub fn abort_async_command(self: *MpvHandle, reply_userdata: u64) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, u64) callconv(.C) c_int, .{ .name = "mpv_abort_async_command" });
        return cFn(self, reply_userdata);
    }
    // TODO mpv_abort_async_command(ctx: ?*mpv_handle, reply_userdata: u64) void;

    pub fn set_property(self: *MpvHandle, name: [*c]const u8, format: MpvFormat, data: ?*anyopaque) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]const u8, MpvFormat, ?*anyopaque) callconv(.C) c_int, .{ .name = "mpv_set_property" });
        return cFn(self, name, format, data);
    }

    pub fn set_property_string(self: *MpvHandle, name: [*c]const u8, data: [*c]const u8) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]const u8, [*c]const u8) callconv(.C) c_int, .{ .name = "mpv_set_property_string" });
        return cFn(self, name, data);
    }

    pub fn del_property(self: *MpvHandle, name: [*c]const u8) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]const u8) callconv(.C) c_int, .{ .name = "mpv_del_property" });
        return cFn(self, name);
    }
    // TODO mpv_del_property(ctx: ?*mpv_handle, name: [*c]const u8) c_int;

    pub fn set_property_async(self: *MpvHandle, reply_userdata: u64, name: [*c]const u8, format: MpvFormat, data: ?*anyopaque) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, u64, [*c]const u8, MpvFormat, ?*anyopaque) callconv(.C) c_int, .{ .name = "mpv_set_property_async" });
        return cFn(self, reply_userdata, name, format, data);
    }
    // TODO mpv_set_property_async(ctx: ?*mpv_handle, reply_userdata: u64, name: [*c]const u8, format: mpv_format, data: ?*anyopaque) c_int;

    pub fn get_property(self: *MpvHandle, name: [*c]const u8, format: MpvFormat, data: ?*anyopaque) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]const u8, MpvFormat, ?*anyopaque) callconv(.C) c_int, .{ .name = "mpv_get_property" });
        return cFn(self, name, format, data);
    }

    pub fn get_property_string(self: *MpvHandle, name: [*c]const u8) [*c]const u8 {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]const u8) callconv(.C) [*c]const u8, .{ .name = "mpv_get_property_string" });
        return cFn(self, name);
    }

    pub fn get_property_osdString(self: *MpvHandle, name: [*c]const u8) [*c]const u8 {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]const u8) callconv(.C) [*c]const u8, .{ .name = "mpv_get_property_osd_string" });
        return cFn(self, name);
    }

    pub fn get_property_async(self: *MpvHandle, reply_userdata: u64, name: [*c]const u8, format: MpvFormat) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, u64, [*c]const u8, MpvFormat) callconv(.C) c_int, .{ .name = "mpv_get_property_async" });
        return cFn(self, reply_userdata, name, format);
    }
    // TODO mpv_get_property_async(ctx: ?*mpv_handle, reply_userdata: u64, name: [*c]const u8, format: mpv_format) c_int;

    pub fn observe_property(self: *MpvHandle, reply_userdata: u64, name: [*c]const u8, format: MpvFormat) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, u64, [*c]const u8, MpvFormat) callconv(.C) c_int, .{ .name = "mpv_observe_property" });
        return cFn(self, reply_userdata, name, format);
    }

    pub fn request_event(self: *MpvHandle, event: MpvEventId, enable: c_int) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, MpvEventId, c_int) callconv(.C) c_int, .{ .name = "mpv_request_event" });
        return cFn(self, event, enable);
    }
    // TODO mpv_request_event(ctx: ?*mpv_handle, event: mpv_event_id, enable: c_int) c_int;

    pub fn wait_event(self: *MpvHandle, timeout: f64) *MpvEvent {
        const cFn = @extern(*const fn (?*MpvHandle, f64) callconv(.C) [*c]MpvEvent, .{ .name = "mpv_wait_event" });
        return cFn(self, timeout);
    }

    pub fn request_log_messages(self: *MpvHandle, min_level: [*c]const u8) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, [*c]const u8) callconv(.C) c_int, .{ .name = "mpv_request_log_messages" });
        return cFn(self, min_level);
    }

    pub fn wakeup(self: *MpvHandle) c_int {
        const cFn = @extern(*const fn (?*MpvHandle) callconv(.C) void, .{ .name = "mpv_wakeup" });
        return cFn(self);
    }
    // TODO mpv_wakeup(ctx: ?*mpv_handle) void;

    pub fn set_wakeup_callback(self: *MpvHandle, cb: ?*const fn (?*anyopaque) callconv(.C) void) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, ?*const fn (?*anyopaque) callconv(.C) void) callconv(.C) void, .{
            .name = "mpv_set_wakeup_callback",
        });
        return cFn(self, cb);
    }
    // TODO mpv_set_wakeup_callback(ctx: ?*mpv_handle, cb: ?*const fn (?*anyopaque) callconv(.C) void, d: ?*anyopaque) void;

    pub fn wait_async_requests(self: *MpvHandle) void {
        const cFn = @extern(*const fn (?*MpvHandle) callconv(.C) void, .{ .name = "mpv_wait_async_requests" });
        return cFn(self);
    }
    // TODO mpv_wait_async_requests(ctx: ?*mpv_handle) void;

    pub fn hook_add(self: *MpvHandle, reply_userdata: u64, name: [*c]const u8, priority: c_int) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, u64, [*c]const u8, c_int) callconv(.C) c_int, .{ .name = "mpv_hook_add" });
        return cFn(self, reply_userdata, name, priority);
    }

    pub fn hook_continue(self: *MpvHandle, id: u64) c_int {
        const cFn = @extern(*const fn (?*MpvHandle, u64) callconv(.C) c_int, .{ .name = "mpv_hook_continue" });
        return cFn(self, id);
    }

    pub fn get_wakeup_pipe(self: *MpvHandle) c_int {
        const cFn = @extern(*const fn (?*MpvHandle) callconv(.C) c_int, .{ .name = "mpv_get_wakeup_pipe" });
        return cFn(self);
    }
    // TODO mpv_get_wakeup_pipe(ctx: ?*mpv_handle) c_int;

    pub fn client_name_z(self: *MpvHandle) []const u8 {
        return sliceTo(self.client_name(), 0);
    }

    pub fn create_z() error{null_value}!*MpvHandle {
        return MpvHandle.create() orelse error.null_value;
    }

    pub fn initialize_z(self: *MpvHandle) MpvErrorZ!void {
        try check_error_z(self.initialize());
    }

    pub fn create_client_z(self: *MpvHandle, args: struct {
        name: ?[]const u8 = null,
    }) error{null_value}!*MpvHandle {
        return self.create_client(if (args.name) |n| n.ptr else null) orelse error.null_value;
    }

    pub fn create_weak_client_z(self: *MpvHandle, args: struct {
        name: ?[]const u8 = null,
    }) error{null_value}!*MpvHandle {
        return self.create_weak_client(if (args.name) |n| n.ptr else null) orelse error.null_value;
    }

    pub fn set_option_z(self: *MpvHandle, allocator: Allocator, name: []const u8, data: MpvFormatDataZ) (MpvErrorZ || AllocatorError)!void {
        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();

        try check_error_z(self.set_option(name.ptr, data.get_format(), try data.to_c_data(arena.allocator())));
    }

    pub fn set_option_string_z(self: *MpvHandle, name: []const u8, data: []const u8) MpvErrorZ!void {
        try check_error_z(self.set_option_string(name.ptr, data.ptr));
    }

    pub fn command_z(self: *MpvHandle, allocator: Allocator, args: []const []const u8) (MpvErrorZ || AllocatorError)!void {
        const cmd_args = try create_cstring_array(args, allocator);
        defer free_cstring_array(cmd_args, allocator);

        try check_error_z(self.command(cmd_args.ptr));
    }

    pub fn command_node_z(self: *MpvHandle, allocator: Allocator, args: MpvNodeZ) !MpvNodeZ {
        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();

        var output: MpvNode = undefined;
        try check_error_z(self.command_node(try args.to_c_data(arena.allocator()), &output));

        return MpvNodeZ.from_c_data(allocator, &output);
    }

    pub fn command_async_z(self: *MpvHandle, allocator: Allocator, reply_userdata: u64, args: []const []const u8) (MpvErrorZ || AllocatorError)!void {
        const cmd_args = try create_cstring_array(args, allocator);
        defer free_cstring_array(cmd_args, allocator);

        try check_error_z(self.command_async(reply_userdata, cmd_args.ptr));
    }

    pub fn set_property_z(self: *MpvHandle, allocator: Allocator, name: []const u8, data: MpvFormatDataZ) (MpvErrorZ || AllocatorError)!void {
        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();

        try check_error_z(self.set_property(name.ptr, data.get_format(), try data.to_c_data(arena.allocator())));
    }

    pub fn get_property_z(self: *MpvHandle, allocator: Allocator, name: []const u8, format: MpvFormat) !MpvFormatDataZ {
        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();

        const output_ptr = try MpvFormatDataZ.alloc_c_data(format, arena.allocator());
        defer switch (format) {
            .string, .osd_string => free(cast_anyopaque_ptr([*c]u8, output_ptr).*),
            .node => MpvNode.free_node_contents(cast_anyopaque_ptr(MpvNode, output_ptr)),
            else => {},
        };

        try check_error_z(self.get_property(name.ptr, format, output_ptr));

        return try MpvFormatDataZ.from_c_data(allocator, format, output_ptr);
    }

    pub fn wait_event_z(self: *MpvHandle, wait_flag: EventWaitFlag) *MpvEvent {
        return self.wait_event(wait_flag.get_wait());
    }
};

pub const MpvRenderContext = opaque {
    pub fn create(res: *?*MpvRenderContext, mpv: *MpvHandle, params: [*c]MpvRenderParam) c_int {
        const cFn = @extern(*const fn ([*c]?*MpvRenderContext, ?*MpvHandle, [*c]MpvRenderParam) callconv(.C) c_int, .{
            .name = "mpv_render_context_create",
        });
        return cFn(res, mpv, params);
    }
    // TODO mpv_render_context_create(res: [*c]?*mpv_render_context, mpv: ?*mpv_handle, params: [*c]mpv_render_param) c_int;
    // TODO mpv_render_context_set_parameter(ctx: ?*mpv_render_context, param: mpv_render_param) c_int;
    // TODO mpv_render_context_get_info(ctx: ?*mpv_render_context, param: mpv_render_param) c_int;
    // TODO mpv_render_context_set_update_callback(ctx: ?*mpv_render_context, callback: mpv_render_update_fn, callback_ctx: ?*anyopaque) void;
    // TODO mpv_render_context_update(ctx: ?*mpv_render_context) u64;
    // TODO mpv_render_context_render(ctx: ?*mpv_render_context, params: [*c]mpv_render_param) c_int;
    // TODO mpv_render_context_report_swap(ctx: ?*mpv_render_context) void;
    // TODO mpv_render_context_free(ctx: ?*mpv_render_context) void;
    // TODO mpv_stream_cb_add_ro(ctx: ?*mpv_handle, protocol: [*c]const u8, user_data: ?*anyopaque, open_fn: mpv_stream_cb_open_ro_fn) c_int;

};

pub const MpvRenderParam = extern struct {
    type: MpvRenderParamType,
    data: ?*anyopaque,
};

pub const MpvRenderParamType = enum(c_uint) {
    invalid = 0,
    api_type = 1,
    opengl_init_params = 2,
    opengl_fbo = 3,
    flip_y = 4,
    depth = 5,
    icc_profile = 6,
    ambient_light = 7,
    x11_display = 8,
    wl_display = 9,
    advanced_control = 10,
    next_frame_info = 11,
    block_for_target_time = 12,
    skip_rendering = 13,
    drm_display = 14,
    drm_draw_surface_size = 15,
    drm_display_v2 = 16,
    sw_size = 17,
    sw_format = 18,
    sw_stride = 19,
    sw_pointer = 20,
};

pub const MpvRenderParamZ = union(MpvRenderParamType) {
    Invalid: void,
    api_type: MpvRenderApiTypeZ,
    opengl_init_params: MpvOpenGLInitParamsZ,
    opengl_fbo: MpvOpenGLFBO,
    flip_y: bool,
    Depth: i32,
    icc_profile: []u8,
    ambient_light: i32,
    x11_display: ?*anyopaque, // *Display
    wl_display: ?*anyopaque, // *wl_display
    advanced_control: bool,
    next_frame_info: MpvRenderFrameInfo,
    block_for_target_time: bool,
    skip_rendering: bool,
    drm_display: MpvOpenGLDRMParams,
    drm_draw_surface_size: MpvOpenGLDRMDrawSurfaceSize,
    drm_display_v2: MpvOpenGLDRMParams,
    sw_size: MpvSwSize,
    sw_format: []const u8,
    sw_stride: usize,
    sw_pointer: *anyopaque,
};

pub const MpvRenderApiType = struct {
    pub const opengl = "opengl";
    pub const sw = "sw";
};

pub const MpvRenderApiTypeZ = enum {
    opengl,
    sw,
};

pub const MpvOpenGLInitParams = extern struct {
    get_proc_address: ?*const fn (?*anyopaque, [*c]const u8) callconv(.C) ?*anyopaque,
    get_proc_address_ctx: ?*anyopaque,
};

pub const MpvOpenGLInitParamsZ = struct {
    get_proc_address: ?*const fn (?*anyopaque, [*c]const u8) callconv(.C) ?*anyopaque = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8) callconv(.C) ?*anyopaque),
    get_proc_address_ctx: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
};

const EventWaitFlag = union(enum) {
    none: void,
    indefinite: void,
    timed: f64,

    pub fn get_wait(self: EventWaitFlag) f64 {
        return switch (self) {
            .none => 0,
            .indefinite => -1,
            .timed => |value| value,
        };
    }
};

pub const MpvError = enum(c_int) {
    success = 0,
    event_queue_full = -1,
    nomem = -2,
    uninitialized = -3,
    invalid_parameter = -4,
    option_not_found = -5,
    option_format = -6,
    option_error = -7,
    property_not_found = -8,
    property_format = -9,
    property_unavailable = -10,
    property_error = -11,
    command = -12,
    loading_failed = -13,
    ao_init_failed = -14,
    vo_init_failed = -15,
    nothing_to_play = -16,
    unknown_format = -17,
    unsupported = -18,
    not_implemented = -19,
    generic = -20,

    pub fn from_ret_code_z(ret_code: c_int) MpvError {
        return @enumFromInt(ret_code);
    }

    pub fn to_string_z(self: MpvError) []const u8 {
        return sliceTo(error_string(@intFromEnum(self)), 0);
    }

    pub fn raise_error_z(self: MpvError) MpvErrorZ!void {
        return switch (self) {
            .success => {},
            .event_queue_full => MpvErrorZ.event_queue_full,
            .nomem => MpvErrorZ.nomem,
            .uninitialized => MpvErrorZ.uninitialized,
            .invalid_parameter => MpvErrorZ.invalid_parameter,
            .option_not_found => MpvErrorZ.option_not_found,
            .option_format => MpvErrorZ.option_format,
            .option_error => MpvErrorZ.option_error,
            .property_not_found => MpvErrorZ.property_not_found,
            .property_format => MpvErrorZ.property_format,
            .property_unavailable => MpvErrorZ.property_unavailable,
            .property_error => MpvErrorZ.property_error,
            .command => MpvErrorZ.command,
            .loading_failed => MpvErrorZ.loading_failed,
            .ao_init_failed => MpvErrorZ.ao_init_failed,
            .vo_init_failed => MpvErrorZ.vo_init_failed,
            .nothing_to_play => MpvErrorZ.nothing_to_play,
            .unknown_format => MpvErrorZ.unknown_format,
            .unsupported => MpvErrorZ.unsupported,
            .not_implemented => MpvErrorZ.not_implemented,
            .generic => MpvErrorZ.generic,
        };
    }
};

pub const MpvEventId = enum(c_uint) {
    none = 0,
    shutdown = 1,
    log_message = 2,
    get_property_reply = 3,
    set_property_reply = 4,
    command_reply = 5,
    start_file = 6,
    end_file = 7,
    file_loaded = 8,
    idle = 11,
    tick = 14,
    client_message = 16,
    video_reconfig = 17,
    audio_reconfig = 18,
    seek = 20,
    playback_restart = 21,
    property_change = 22,
    queue_overflow = 24,
    hook = 25,
};

pub const MpvEvent = extern struct {
    id: MpvEventId,
    err: MpvError,
    reply_userdata: u64,
    data: ?*anyopaque,

    pub fn to_node(self: *MpvEvent, dst: *MpvNode) c_int {
        const cFn = @extern(*const fn ([*c]MpvNode, [*c]MpvEvent) callconv(.C) c_int, .{ .name = "mpv_event_to_node" });
        return cFn(dst, self);
    }
    // TODO pub extern fn mpv_event_to_node(dst: [*c]mpv_node, src: [*c]mpv_event) c_int;

    pub fn get_data_z(self: MpvEvent) MpvEventDataZ {
        return MpvEventDataZ.from_c_data(self.data, self.id);
    }

    pub fn check_error_z(self: MpvEvent) MpvErrorZ!void {
        try self.err.raise_error_z();
    }
};

pub const MpvEventDataZ = union(enum) {
    none: void,
    log_message: *MpvEventLogMessage,
    get_property_reply: *MpvEventProperty,
    command_reply: *MpvEventCommand,
    start_file: *MpvEventStartFile,
    end_file: *MpvEventEndFile,
    client_message: *MpvEventClientMessage,
    property_change: *MpvEventProperty,
    hook: *MpvEventHook,

    pub fn from_c_data(data_ptr: ?*anyopaque, format: MpvEventId) MpvEventDataZ {
        if (data_ptr) |ptr| {
            return switch (format) {
                .log_message => .{ .log_message = @ptrCast(@alignCast(ptr)) },
                .get_property_reply => .{ .get_property_reply = @ptrCast(@alignCast(ptr)) },
                .command_reply => .{ .command_reply = @ptrCast(@alignCast(ptr)) },
                .start_file => .{ .start_file = @ptrCast(@alignCast(ptr)) },
                .end_file => .{ .end_file = @ptrCast(@alignCast(ptr)) },
                .client_message => .{ .client_message = @ptrCast(@alignCast(ptr)) },
                .property_change => .{ .property_change = @ptrCast(@alignCast(ptr)) },
                .hook => .{ .hook = @ptrCast(@alignCast(ptr)) },
                else => .{ .none = {} },
            };
        } else {
            return .{ .none = {} }; //
        }
    }
};

pub const MpvFormat = enum(c_uint) {
    none = 0,
    string = 1,
    osd_string = 2,
    flag = 3,
    int64 = 4,
    double = 5,
    node = 6,
    node_array = 7,
    node_map = 8,
    byte_array = 9,
};

pub const MpvEventProperty = extern struct {
    name: [*c]const u8,
    format: MpvFormat,
    data: ?*anyopaque,
};

pub const MpvLogLevel = enum(c_uint) {
    none = 0,
    fatal = 10,
    err = 20,
    warn = 30,
    info = 40,
    v = 50,
    debug = 60,
    trace = 70,
};

pub const MpvEventLogMessage = extern struct {
    prefix: [*c]const u8,
    level: [*c]const u8,
    text: [*c]const u8,
    log_level: MpvLogLevel,
};

pub const MpvEventStartFile = extern struct {
    playlist_entry_id: i64,
};

pub const MpvEndFileReason = enum(c_uint) {
    eof = 0,
    stop = 2,
    quit = 3,
    err = 4,
    redirect = 5,
};

pub const MpvEventEndFile = extern struct {
    reason: MpvEndFileReason,
    err: MpvError,
    playlist_entry_id: i64,
    playlist_insert_id: i64,
    playlist_insert_num_entries: c_int,
};

pub const MpvEventClientMessage = extern struct {
    num_args: c_int,
    args: [*c][*c]const u8,

    pub fn get_args_z(self: *MpvEventClientMessage) [][*:0]const u8 {
        return @ptrCast(self.args[0..@intCast(self.num_args)]);
    }
};

pub const MpvEventHook = extern struct {
    name: [*c]const u8,
    id: u64,

    pub fn get_name_z(self: *MpvEventHook) []const u8 {
        return sliceTo(self.name, 0);
    }
};

pub const MpvNodeList = extern struct {
    num: c_int,
    values: [*c]MpvNode,
    keys: [*c][*c]u8,
};

pub const MpvByteArray = extern struct {
    data: ?*anyopaque,
    size: usize,
};

pub const MpvNodeData = extern union {
    string: [*c]u8,
    flag: c_int,
    int64: i64,
    double: f64,
    list: [*c]MpvNodeList,
    byte_array: [*c]MpvByteArray,
};

pub const MpvNode = extern struct {
    u: MpvNodeData,
    format: MpvFormat,

    pub fn free_node_contents(node: [*c]MpvNode) void {
        const cFn = @extern(*const fn ([*c]MpvNode) callconv(.C) void, .{ .name = "mpv_free_node_contents" });
        return cFn(node);
    }
};

pub const MpvEventCommand = extern struct {
    result: MpvNode,
};

pub const NodeMapEntry = struct { key: []const u8, value: MpvNodeZ };

pub const MpvNodeZ = union(enum) {
    none: void,
    string: []const u8,
    flag: bool,
    int64: i64,
    double: f64,
    node_array: []const MpvNodeZ,
    node_map: []const NodeMapEntry,
    byte_array: []u8,

    pub fn from_c_data(allocator: Allocator, node: *MpvNode) AllocatorError!MpvNodeZ {
        const format = node.format;
        return switch (format) {
            .string => .{ .string = try allocator.dupe(u8, sliceTo(node.u.string, 0)) },
            .flag => .{ .flag = node.u.flag == 1 },
            .int64 => .{ .int64 = node.u.int64 },
            .double => .{ .double = node.u.double },
            .node_array => .{ .node_array = try from_node_array(allocator, node.u.list) },
            .node_map => .{ .node_map = try from_node_map(allocator, node.u.list) },
            .byte_array => .{ .byte_array = try from_byte_array(allocator, node.u.byte_array) },
            else => .{ .none = {} },
        };
    }

    pub fn from_node_array(allocator: Allocator, array: *MpvNodeList) AllocatorError![]const MpvNodeZ {
        const len: usize = @intCast(array.num);
        const values = array.values;

        const node_list = try allocator.alloc(MpvNodeZ, len);
        for (0.., values[0..len]) |idx, *value| {
            node_list[idx] = try MpvNodeZ.from_c_data(allocator, value);
        }

        return node_list;
    }

    pub fn from_node_map(allocator: Allocator, map: *MpvNodeList) AllocatorError![]const NodeMapEntry {
        const len: usize = @intCast(map.num);
        const values = map.values;
        const keys = map.keys;

        const node_list = try allocator.alloc(NodeMapEntry, len);
        for (0.., values[0..len], keys[0..len]) |idx, *value, key| {
            node_list[idx].key = try allocator.dupe(u8, sliceTo(key, 0));
            node_list[idx].value = try MpvNodeZ.from_c_data(allocator, value);
        }

        return node_list;
    }

    pub fn from_byte_array(allocator: Allocator, array: *MpvByteArray) AllocatorError![]u8 {
        if (array.size == 0) return &.{};
        const bytes: [*c]u8 = @ptrCast(@alignCast(array.data));
        return try allocator.dupe(u8, sliceTo(bytes, 0));
    }

    pub fn free(self: MpvNodeZ, allocator: Allocator) void {
        switch (self) {
            .string => |string| allocator.free(string),
            .node_array => |array| free_node_array(array, allocator),
            .node_map => |map| free_node_map(map, allocator),
            .byte_array => |bytes| free_byte_array(bytes, allocator),
            else => {},
        }
    }

    pub fn free_node_array(array: []const MpvNodeZ, allocator: Allocator) void {
        for (array) |node| {
            node.free(allocator);
        }
        allocator.free(array);
    }

    pub fn free_node_map(map: []const NodeMapEntry, allocator: Allocator) void {
        for (map) |entry| {
            allocator.free(entry.key);
            entry.value.free(allocator);
        }
        allocator.free(map);
    }

    pub fn free_byte_array(bytes: []u8, allocator: Allocator) void {
        allocator.free(bytes);
    }

    pub fn to_c_data(self: MpvNodeZ, allocator: Allocator) AllocatorError!*MpvNode {
        var node = try allocator.create(MpvNode);

        switch (self) {
            .none => {
                node.format = .none;
            },
            .string => |string| {
                node.format = .string;
                node.u.string = try allocator.dupeZ(u8, string);
            },
            .flag => |flag| {
                node.format = .flag;
                node.u.flag = @intFromBool(flag);
            },
            .int64 => |num| {
                node.format = .int64;
                node.u.int64 = num;
            },
            .double => |num| {
                node.format = .double;
                node.u.double = num;
            },
            .node_array => |array| {
                node.format = .node_array;
                node.u.list = try node_array_to_cdata(array, allocator);
            },
            .node_map => |map| {
                node.format = .node_map;
                node.u.list = try node_map_to_cdata(map, allocator);
            },
            .byte_array => |bytes| {
                node.format = .byte_array;
                node.u.byte_array = try byte_array_to_cdata(bytes, allocator);
            },
        }
        return node;
    }

    pub fn node_array_to_cdata(array: []const MpvNodeZ, allocator: Allocator) AllocatorError!*MpvNodeList {
        var list = try allocator.create(MpvNodeList);

        const len = array.len;
        var values_list = try allocator.alloc(MpvNode, len);
        for (0.., array) |idx, value| {
            values_list[idx] = (try value.to_c_data(allocator)).*;
        }
        list.num = @intCast(len);
        list.values = values_list.ptr;

        return list;
    }

    pub fn node_map_to_cdata(map: []const NodeMapEntry, allocator: Allocator) AllocatorError!*MpvNodeList {
        var list = try allocator.create(MpvNodeList);

        const len = map.len;
        var keys_list = try allocator.alloc([*c]u8, len);
        var values_list = try allocator.alloc(MpvNode, len);
        for (0.., map) |idx, entry| {
            keys_list[idx] = try allocator.dupeZ(u8, entry.key);
            values_list[idx] = (try entry.value.to_c_data(allocator)).*;
        }
        list.num = @intCast(len);
        list.keys = keys_list.ptr;
        list.values = values_list.ptr;

        return list;
    }

    pub fn byte_array_to_cdata(bytes: []u8, allocator: Allocator) AllocatorError!*MpvByteArray {
        var byte_array = try allocator.create(MpvByteArray);
        byte_array.size = bytes.len;
        byte_array.data = bytes.ptr;

        return byte_array;
    }
};

pub const MpvFormatDataZ = union(MpvFormat) {
    none: void,
    string: []const u8,
    osd_string: []const u8,
    flag: bool,
    int64: i64,
    double: f64,
    node: MpvNodeZ,
    node_array: []const MpvNodeZ,
    node_map: []const NodeMapEntry,
    byte_array: []u8,

    pub fn alloc_c_data(self: MpvFormat, allocator: Allocator) AllocatorError!?*anyopaque {
        return switch (self) {
            .none => return null,
            .string, .osd_string => @ptrCast(try allocator.create([*c]u8)),
            .flag => @ptrCast(try allocator.create(c_int)),
            .int64 => @ptrCast(try allocator.create(i64)),
            .double => @ptrCast(try allocator.create(f64)),
            .node => @ptrCast(try allocator.create(MpvNode)),
            .node_array, .node_map => @ptrCast(try allocator.create(MpvNodeList)),
            .byte_array => @ptrCast(try allocator.create(MpvByteArray)),
        };
    }

    pub fn from_c_data(allocator: Allocator, format: MpvFormat, data_ptr: ?*anyopaque) !MpvFormatDataZ {
        switch (format) {
            .none => return .{ .none = {} },
            .string => {
                const data = cast_anyopaque_ptr([*c]u8, data_ptr);
                return .{ .string = try allocator.dupe(u8, sliceTo(data.*, 0)) };
            },
            .osd_string => {
                const data = cast_anyopaque_ptr([*c]u8, data_ptr);
                return .{ .osd_string = try allocator.dupe(u8, sliceTo(data.*, 0)) };
            },
            .flag => {
                const data = cast_anyopaque_ptr(c_int, data_ptr);
                return .{ .flag = data.* == 1 };
            },
            .int64 => {
                const data = cast_anyopaque_ptr(i64, data_ptr);
                return .{ .int64 = data.* };
            },
            .double => {
                const data = cast_anyopaque_ptr(f64, data_ptr);
                return .{ .double = data.* };
            },
            .node => {
                const data = cast_anyopaque_ptr(MpvNode, data_ptr);
                return .{ .node = try MpvNodeZ.from_c_data(allocator, data) };
            },
            .node_array => {
                const data = cast_anyopaque_ptr(MpvNodeList, data_ptr);
                return .{ .node_array = try MpvNodeZ.from_node_array(allocator, data) };
            },
            .node_map => {
                const data = cast_anyopaque_ptr(MpvNodeList, data_ptr);
                return .{ .node_map = try MpvNodeZ.from_node_map(allocator, data) };
            },
            .byte_array => {
                const data = cast_anyopaque_ptr(MpvByteArray, data_ptr);
                return .{ .byte_array = try MpvNodeZ.from_byte_array(allocator, data) };
            },
        }
    }

    pub fn free(self: MpvFormatDataZ, allocator: Allocator) void {
        switch (self) {
            .string, .osd_string => |string| allocator.free(string),
            .node => |node| node.free(allocator),
            .node_array => |array| MpvNodeZ.free_node_array(array, allocator),
            .node_map => |map| MpvNodeZ.free_node_map(map, allocator),
            .byte_array => |bytes| MpvNodeZ.free_byte_array(bytes, allocator),
            else => {},
        }
    }

    pub fn to_c_data(self: MpvFormatDataZ, allocator: Allocator) !?*anyopaque {
        switch (self) {
            .none => return null,
            .string, .osd_string => |string| {
                const mem = try allocator.create([*c]u8);
                mem.* = try allocator.dupeZ(u8, string);
                return @ptrCast(mem);
            },
            .flag => |flag| {
                const mem = try allocator.create(c_int);
                mem.* = if (flag) 1 else 0;
                return @ptrCast(mem);
            },
            .int64 => |num| {
                const mem = try allocator.create(i64);
                mem.* = num;
                return @ptrCast(mem);
            },
            .double => |num| {
                const mem = try allocator.create(f64);
                mem.* = num;
                return @ptrCast(mem);
            },
            .node => |node| {
                return @ptrCast(try node.to_c_data(allocator));
            },
            .node_array => |array| {
                return @ptrCast(try MpvNodeZ.node_array_to_cdata(array, allocator));
            },
            .node_map => |map| {
                return @ptrCast(try MpvNodeZ.node_map_to_cdata(map, allocator));
            },
            .byte_array => |bytes| {
                return @ptrCast(try MpvNodeZ.byte_array_to_cdata(bytes, allocator));
            },
        }
    }

    pub fn get_format(self: MpvFormatDataZ) MpvFormat {
        return std.meta.activeTag(self);
    }
};

pub fn cast_anyopaque_ptr(T: type, ptr: ?*anyopaque) *T {
    return @ptrCast(@alignCast(ptr));
}

pub fn create_cstring_array(z_array: []const []const u8, allocator: std.mem.Allocator) AllocatorError![:0][*c]const u8 {
    const array = try allocator.allocSentinel([*c]const u8, z_array.len, 0);
    for (0..z_array.len) |index| {
        array[index] = try allocator.dupeZ(u8, z_array[index]);
    }
    return array;
}

pub fn free_cstring_array(c_array: [:0][*c]const u8, allocator: std.mem.Allocator) void {
    for (0..c_array.len) |index| {
        const slice: [:0]const u8 = std.mem.sliceTo(c_array[index], 0);
        allocator.free(slice);
    }
    allocator.free(c_array);
}

pub const MpvErrorZ = error{
    event_queue_full,
    nomem,
    uninitialized,
    invalid_parameter,
    option_not_found,
    option_format,
    option_error,
    property_not_found,
    property_format,
    property_unavailable,
    property_error,
    command,
    loading_failed,
    ao_init_failed,
    vo_init_failed,
    nothing_to_play,
    unknown_format,
    unsupported,
    not_implemented,
    generic,
};
