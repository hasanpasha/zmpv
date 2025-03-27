const std = @import("std");
const Allocator = std.mem.Allocator;
const AllocatorError = Allocator.Error;
const ArenaAllocator = std.heap.ArenaAllocator;
const sliceTo = std.mem.sliceTo;

extern fn mpv_client_api_version() c_ulong;
pub const client_api_version = mpv_client_api_version;

pub fn client_api_version_z() struct { major: u16, minor: u16 } {
    const version = client_api_version();
    return .{ .major = @truncate(version >> 16), .minor = @truncate(version & 0xffff) };
}

extern fn mpv_free(data: ?*anyopaque) void;
pub const free = mpv_free;

pub const MpvHandle = opaque {
    extern fn mpv_client_name(self: *MpvHandle) [*c]const u8;
    pub const client_name = mpv_client_name;

    extern fn mpv_client_id(self: *MpvHandle) i64;
    pub const client_id = mpv_client_id;

    extern fn mpv_create() ?*MpvHandle;
    pub const create = mpv_create;

    extern fn mpv_initialize(self: *MpvHandle) MpvError;
    pub const initialize = mpv_initialize;

    extern fn mpv_destroy(self: *MpvHandle) void;
    pub const destroy = mpv_destroy;

    extern fn mpv_terminate_destroy(self: *MpvHandle) void;
    pub const terminate_destroy = mpv_terminate_destroy;

    extern fn mpv_create_client(self: *MpvHandle, name: [*c]const u8) *MpvHandle;
    pub const create_client = mpv_create_client;

    extern fn mpv_create_weak_client(self: *MpvHandle, name: [*c]const u8) *MpvHandle;
    pub const create_weak_client = mpv_create_weak_client;

    extern fn mpv_load_config_file(self: *MpvHandle, filename: [*c]const u8) MpvError;
    pub const load_config_file = mpv_load_config_file;

    extern fn mpv_get_time_ns(self: *MpvHandle) i64;
    pub const get_time_ns = mpv_get_time_ns;

    extern fn mpv_get_time_us(self: *MpvHandle) i64;
    pub const get_time_us = mpv_get_time_us;

    extern fn mpv_set_option(self: *MpvHandle, name: [*c]const u8, format: MpvFormat, data: ?*anyopaque) MpvError;
    pub const set_option = mpv_set_option;

    extern fn mpv_set_option_string(self: *MpvHandle, name: [*c]const u8, data: [*c]const u8) MpvError;
    pub const set_option_string = mpv_set_option_string;

    extern fn mpv_command(self: *MpvHandle, args: [*c][*c]const u8) MpvError;
    pub const command = mpv_command;

    extern fn mpv_command_node(self: *MpvHandle, args: [*c]MpvNode, result: [*c]MpvNode) MpvError;
    pub const command_node = mpv_command_node;

    extern fn mpv_command_ret(self: *MpvHandle, args: [*c][*c]const u8, result: [*c]MpvNode) MpvError;
    pub const command_ret = mpv_command_ret;

    extern fn mpv_command_string(self: *MpvHandle, args: [*c]const u8) MpvError;
    pub const command_string = mpv_command_string;

    extern fn mpv_command_async(self: *MpvHandle, reply_userdata: u64, args: [*c][*c]const u8) MpvError;
    pub const command_async = mpv_command_async;

    extern fn mpv_command_node_async(self: *MpvHandle, reply_userdata: u64, args: [*c]MpvNode) MpvError;
    pub const command_node_async = mpv_command_node_async;

    extern fn mpv_abort_async_command(self: *MpvHandle, reply_userdata: u64) MpvError;
    pub const abort_async_command = mpv_abort_async_command;

    extern fn mpv_set_property(self: *MpvHandle, name: [*c]const u8, format: MpvFormat, data: ?*anyopaque) MpvError;
    pub const set_property = mpv_set_property;

    extern fn mpv_set_property_string(self: *MpvHandle, name: [*c]const u8, data: [*c]const u8) MpvError;
    pub const set_property_string = mpv_set_property_string;

    extern fn mpv_del_property(self: *MpvHandle, name: [*c]const u8) MpvError;
    pub const del_property = mpv_del_property;

    extern fn mpv_set_property_async(self: *MpvHandle, reply_userdata: u64, name: [*c]const u8, format: MpvFormat, data: ?*anyopaque) MpvError;
    pub const set_property_async = mpv_set_property_async;

    extern fn mpv_get_property(self: *MpvHandle, name: [*c]const u8, format: MpvFormat, data: ?*anyopaque) MpvError;
    pub const get_property = mpv_get_property;

    extern fn mpv_get_property_string(self: *MpvHandle, name: [*c]const u8) [*c]const u8;
    pub const get_property_string = mpv_get_property_string;

    extern fn mpv_get_property_osd_string(self: *MpvHandle, name: [*c]const u8) [*c]const u8;
    pub const get_property_osd_string = mpv_get_property_osd_string;

    extern fn mpv_get_property_async(self: *MpvHandle, reply_userdata: u64, name: [*c]const u8, format: MpvFormat) MpvError;
    pub const get_property_async = mpv_get_property_async;

    extern fn mpv_observe_property(self: *MpvHandle, reply_userdata: u64, name: [*c]const u8, format: MpvFormat) MpvError;
    pub const observe_property = mpv_observe_property;

    extern fn mpv_request_event(self: *MpvHandle, event: MpvEventId, enable: c_int) MpvError;
    pub const request_event = mpv_request_event;

    extern fn mpv_wait_event(self: *MpvHandle, timeout: f64) *MpvEvent;
    pub const wait_event = mpv_wait_event;

    extern fn mpv_request_log_messages(self: *MpvHandle, min_level: [*c]const u8) MpvError;
    pub const request_log_messages = mpv_request_log_messages;

    extern fn mpv_wakeup(self: *MpvHandle) void;
    pub const wakeup = mpv_wakeup;

    extern fn mpv_set_wakeup_callback(self: *MpvHandle, cb: ?*const fn (?*anyopaque) void) void;
    pub const set_wakeup_callback = mpv_set_wakeup_callback;

    extern fn mpv_wait_async_requests(self: *MpvHandle) void;
    pub const wait_async_requests = mpv_wait_async_requests;

    extern fn mpv_hook_add(self: *MpvHandle, reply_userdata: u64, name: [*c]const u8, priority: c_int) MpvError;
    pub const hook_add = mpv_hook_add;

    extern fn mpv_hook_continue(self: *MpvHandle, id: u64) MpvError;
    pub const hook_continue = mpv_hook_continue;

    extern fn mpv_get_wakeup_pipe(self: *MpvHandle) c_int;
    pub const get_wakeup_pipe = mpv_get_wakeup_pipe;

    // TODO implement mpv custom stream binding
    extern fn mpv_stream_cb_add_ro(ctx: *MpvHandle, protocol: [*c]const u8, user_data: ?*anyopaque, open_fn: ?*const fn (?*anyopaque, [*c]const u8) callconv(.C) c_int) MpvError;
    pub const stream_cb_add_ro = mpv_stream_cb_add_ro;

    pub fn client_name_z(self: *MpvHandle) []const u8 {
        return sliceTo(self.client_name(), 0);
    }

    pub fn init_z(alloc: Allocator, options: anytype) anyerror!*MpvHandle {
        var instance = try MpvHandle.create_z();
        const opts_type = @TypeOf(options);
        const opts_type_info = @typeInfo(opts_type);
        if (opts_type_info != .@"struct") {
            @compileError("expected struct argument, found " ++ @typeName(opts_type));
        }

        const fields_info = opts_type_info.@"struct".fields;

        inline for (fields_info) |field| {
            const field_value = @field(options, field.name);
            const field_type = field.type;
            const field_type_info = @typeInfo(field_type);

            if (field_type_info == .comptime_int or (field_type_info == .int and field_type_info.int.bits <= 64)) {
                try instance.set_option_z(alloc, field.name, .{ .int64 = field_value });
            } else if (field_type_info == .comptime_float or (field_type_info == .float and field_type_info.float.bits <= 64)) {
                try instance.set_option_z(alloc, field.name, .{ .double = field_value });
            } else if (field_type_info == .bool) {
                try instance.set_option_z(alloc, field.name, .{ .flag = field_value });
            } else if (field_type == MpvFormatDataZ) {
                try instance.set_option_z(alloc, field.name, field_value);
            } else if (field_type_info == .enum_literal) {
                try instance.set_option_string_z(field.name, @tagName(field_value));
            } else {
                // FIXME check if it's string
                // if (is_zig_string(field_type)) {
                try instance.set_option_string_z(field.name, field_value);
            }
            // else {
            //     @compileError("not supported option type " ++ @typeName(field_type));
            // }
        }

        try instance.initialize_z();
        return instance;
    }

    pub fn create_z() error{null_value}!*MpvHandle {
        return MpvHandle.create() orelse error.null_value;
    }

    pub fn initialize_z(self: *MpvHandle) MpvErrorZ!void {
        try self.initialize().check_error_z();
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

        try self.set_option(name.ptr, data.get_format(), try data.to_c_data(arena.allocator())).check_error_z();
    }

    pub fn set_option_string_z(self: *MpvHandle, name: []const u8, data: []const u8) MpvErrorZ!void {
        try self.set_option_string(name.ptr, data.ptr).check_error_z();
    }

    pub fn command_z(self: *MpvHandle, allocator: Allocator, args: []const []const u8) (MpvErrorZ || AllocatorError)!void {
        const cmd_args = try create_cstring_array(args, allocator);
        defer free_cstring_array(cmd_args, allocator);

        try self.command(cmd_args.ptr).check_error_z();
    }

    pub fn command_node_z(self: *MpvHandle, allocator: Allocator, args: MpvNodeZ) !MpvNodeZ {
        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();

        var output: MpvNode = undefined;
        try self.command_node(try args.to_c_data(arena.allocator()), &output).check_error_z();

        return MpvNodeZ.from_c_data(allocator, &output);
    }

    pub fn command_async_z(
        self: *MpvHandle,
        allocator: Allocator,
        reply_userdata: u64,
        args: []const []const u8,
    ) (MpvErrorZ || AllocatorError)!void {
        const cmd_args = try create_cstring_array(args, allocator);
        defer free_cstring_array(cmd_args, allocator);

        try self.command_async(reply_userdata, cmd_args.ptr).check_error_z();
    }

    pub fn set_property_z(
        self: *MpvHandle,
        allocator: Allocator,
        name: []const u8,
        data: MpvFormatDataZ,
    ) (MpvErrorZ || AllocatorError)!void {
        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();

        try self.set_property(name.ptr, data.get_format(), try data.to_c_data(arena.allocator())).check_error_z();
    }

    pub fn get_property_z(
        self: *MpvHandle,
        allocator: Allocator,
        name: []const u8,
        format: MpvFormat,
    ) !MpvFormatDataZ {
        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();

        const output_ptr = try MpvFormatDataZ.alloc_c_data(format, arena.allocator());
        defer switch (format) {
            .string, .osd_string => free(cast_anyopaque_ptr([*c]u8, output_ptr).*),
            .node => MpvNode.free_node_contents(cast_anyopaque_ptr(MpvNode, output_ptr)),
            else => {},
        };

        try self.get_property(name.ptr, format, output_ptr).check_error_z();

        return try MpvFormatDataZ.from_c_data(allocator, format, output_ptr);
    }

    pub fn wait_event_z(self: *MpvHandle, wait_flag: EventWaitFlag) *MpvEvent {
        return self.wait_event(wait_flag.get_wait());
    }
};

// FIXME: check for string not working for some reason, fix it!
pub fn is_zig_string(comptime T: type) bool {
    return comptime switch (@typeInfo(T)) {
        .pointer => |ptr| ptr_result: {
            if (ptr.is_allowzero or ptr.is_volatile) break :ptr_result false;

            break :ptr_result switch (ptr.size) {
                .one => ptr.child == u8,
                .slice => {
                    const ptr_child_info = @typeInfo(ptr.child);
                    break :ptr_result ptr_child_info == .array and ptr_child_info.array.child == u8;
                },
                else => false,
            };
        },
        .array => |array| array.child == u8,
        else => false,
    };
}

pub const MpvRenderContext = opaque {
    extern fn mpv_render_context_create(res: *?*MpvRenderContext, mpv: *MpvHandle, params: [*c]MpvRenderParam) MpvError;
    pub const create = mpv_render_context_create;

    extern fn mpv_render_context_set_parameter(ctx: *MpvRenderContext, param: MpvRenderParam) MpvError;
    pub const set_parameter = mpv_render_context_set_parameter;

    extern fn mpv_render_context_get_info(ctx: *MpvRenderContext, param: MpvRenderParam) MpvError;
    pub const get_info = mpv_render_context_get_info;

    extern fn mpv_render_context_set_update_callback(ctx: *MpvRenderContext, callback: ?*const fn (?*anyopaque) void, callback_ctx: ?*anyopaque) void;
    pub const set_update_callback = mpv_render_context_set_update_callback;

    extern fn mpv_render_context_update(ctx: *MpvRenderContext) u64;
    pub const update = mpv_render_context_update;

    extern fn mpv_render_context_render(ctx: *MpvRenderContext, params: [*c]MpvRenderParam) MpvError;
    pub const render = mpv_render_context_render;

    extern fn mpv_render_context_report_swap(ctx: *MpvRenderContext) void;
    pub const report_swap = mpv_render_context_report_swap;

    extern fn mpv_render_context_free(ctx: *MpvRenderContext) void;
    pub const free = mpv_render_context_free;

    // TODO pub fn create_z(alloc: Allocator, mpv: *MpvHandle, z_params: []MpvRenderParamZ) anyerror!*MpvRenderContext {}
};

pub const MpvRenderParam = extern struct {
    type: MpvRenderParamType,
    data: ?*anyopaque,

    pub fn new_z(data: MpvRenderParamData) MpvRenderParam {
        var param: MpvRenderParam = undefined;
        param.type = std.meta.activeTag(data);

        switch (data) {
            .invalid => param.data = null,
            .api_type => |val| param.data = @constCast(@ptrCast(val)),
            .sw_size => |val| param.data = @constCast(@ptrCast(val)),
            .sw_format => |val| param.data = @constCast(@ptrCast(val)),
            inline else => |val| param.data = @ptrCast(val),
        }

        return param;
    }

    pub const invalid = MpvRenderParam.new_z(.invalid);
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

const X11Display = anyopaque;
const WaylandDisplay = anyopaque;

pub const MpvRenderParamData = union(MpvRenderParamType) {
    invalid: void,
    api_type: [:0]const u8,
    opengl_init_params: *MpvOpenGLInitParams,
    opengl_fbo: *MpvOpenGLFBO,
    flip_y: *c_int,
    depth: *c_int,
    icc_profile: *MpvByteArray,
    ambient_light: *c_int,
    x11_display: *X11Display,
    wl_display: *WaylandDisplay,
    advanced_control: *c_int,
    next_frame_info: *MpvRenderFrameInfo,
    block_for_target_time: *c_int,
    skip_rendering: *c_int,
    drm_display: *anyopaque,
    drm_draw_surface_size: *anyopaque,
    drm_display_v2: *anyopaque,
    sw_size: *[2]c_int,
    sw_format: [:0]const u8,
    sw_stride: *isize,
    sw_pointer: ?*anyopaque,
};

// pub const MpvRenderParamZ = union(MpvRenderParamType) {
//     invalid,
//     api_type: MpvRenderApiTypeZ,
//     opengl_init_params: MpvOpenGLInitParams,
//     opengl_fbo,
//     flip_y: bool,
//     depth: i32,
//     icc_profile: []u8,
//     ambient_light: i32,
//     x11_display: ?*anyopaque, // *Display
//     wl_display: ?*anyopaque, // *wl_display
//     advanced_control: bool,
//     next_frame_info,
//     block_for_target_time: bool,
//     skip_rendering: bool,
//     drm_display,
//     drm_draw_surface_size,
//     drm_display_v2,
//     sw_size,
//     sw_format: []const u8,
//     sw_stride: usize,
//     sw_pointer: ?*anyopaque,

//     pub fn to_c(self: MpvRenderParamZ, alloc: Allocator) !MpvRenderParam {
//         var param: MpvRenderParam = undefined;
//         param.type = std.meta.activeTag(self);
//         switch (self) {
//             .invalid => {
//                 param.data = null;
//             },
//             .api_type => |val| {
//                 param.data = val.to_c();
//             },
//             .opengl_init_params => |val| {
//                 param.data = val;
//             },
//             // .opengl_fbo => |val| {},
//             .flip_y => |val| {
//                 const data = try alloc.create(c_int);
//                 data.* = @intCast(@intFromBool(val));
//                 param.data = data;
//             },
//             // .Depth => |val| {},
//             // .icc_profile => |val| {},
//             // .ambient_light => |val| {},
//             // .x11_display => |val| {},
//             // .wl_display => |val| {},
//             // .advanced_control => |val| {},
//             // .next_frame_info => |val| {},
//             // .block_for_target_time => |val| {},
//             // .skip_rendering => |val| {},
//             // .drm_display => |val| {},
//             // .drm_draw_surface_size => |val| {},
//             // .drm_display_v2 => |val| {},
//             // .sw_size => |val| {},
//             // .sw_format => |val| {},
//             // .sw_stride => |val| {},
//             // .sw_pointer => |val| {},
//             else => @panic("unhandled"),
//         }
//     }
// };

pub const MpvRenderApiType = struct {
    pub const opengl = "opengl";
    pub const sw = "sw";
};

pub const MpvRenderApiTypeZ = enum {
    opengl,
    sw,

    pub fn to_c(self: MpvRenderApiTypeZ) *const [:0]u8 {
        return switch (self) {
            .opengl => MpvRenderApiType.opengl,
            .sw => MpvRenderApiType.sw,
        };
    }
};

pub const MpvOpenGLInitParams = extern struct {
    get_proc_address: ?*const fn (?*anyopaque, [*c]const u8) callconv(.C) ?*anyopaque,
    get_proc_address_ctx: ?*anyopaque,
};

pub const MpvOpenGLFBO = extern struct {
    fbo: c_int,
    w: c_int,
    h: c_int,
    internal_format: c_int,
};

pub const MpvRenderFrameInfoFlags = enum(u64) {
    present = 1 << 0,
    redraw = 1 << 1,
    repeat = 1 << 2,
    block_async = 1 << 3,
};

pub const MpvRenderFrameInfo = extern struct {
    flags: MpvRenderFrameInfoFlags,
    target_time: i64,
};

// mpv_render_update_flag
pub const MpvRenderUpdateFlag = enum(u64) {
    frame = 1 << 0,

    pub fn in_flags(self: MpvRenderUpdateFlag, flags: u64) bool {
        return ((flags & @intFromEnum(self)) != 0);
    }
};

pub fn MpvOpenGLInitParamsZ(user_data: anytype, comptime callback: fn (@TypeOf(user_data), [*c]const u8) ?*anyopaque) MpvOpenGLInitParams {
    return MpvOpenGLInitParams{
        .get_proc_address = struct {
            fn cb(a: ?*anyopaque, b: [*c]const u8) ?*anyopaque {
                return callback(@alignCast(@ptrCast(a)), b);
            }
        }.cb,
        .get_proc_address_ctx = user_data,
    };
}

// pub const MpvOpenGLInitParamsZ = struct {
//     get_proc_address: ?*const fn (?*anyopaque, [*c]const u8) callconv(.C) ?*anyopaque = null,
//     get_proc_address_ctx: ?*anyopaque = null,
// };

const EventWaitFlag = union(enum) {
    none,
    indefinite,
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
    _,

    pub fn from_ret_code_z(ret_code: c_int) MpvError {
        return @enumFromInt(ret_code);
    }

    extern fn mpv_error_string(err: MpvError) [*c]const u8;
    pub const string = mpv_error_string;

    pub fn string_z(self: MpvError) []const u8 {
        return sliceTo(self.string(), 0);
    }

    pub fn check_error_z(self: MpvError) MpvErrorZ!void {
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
            else => @panic("unknown MpvError"),
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

    extern fn mpv_event_to_node(dst: [*c]MpvNode, src: [*c]MpvEvent) MpvError;
    pub const to_node = mpv_event_to_node;

    pub fn get_data_z(self: MpvEvent) MpvEventDataZ {
        return MpvEventDataZ.from_c_data(self.data, self.id);
    }

    pub fn check_error_z(self: MpvEvent) MpvErrorZ!void {
        try self.err.check_error_z();
    }
};

pub const MpvEventDataZ = union(enum) {
    none,
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
                else => .none,
            };
        } else {
            return .none; //
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
    data: MpvNodeData,
    format: MpvFormat,

    extern fn mpv_free_node_contents(node: [*c]MpvNode) void;
    pub const free_node_contents = mpv_free_node_contents;
};

pub const MpvEventCommand = extern struct {
    result: MpvNode,
};

pub const NodeMapEntry = struct { key: []const u8, value: MpvNodeZ };

pub const MpvNodeZ = union(enum) {
    none,
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
            .string => .{ .string = try allocator.dupe(u8, sliceTo(node.data.string, 0)) },
            .flag => .{ .flag = node.data.flag == 1 },
            .int64 => .{ .int64 = node.data.int64 },
            .double => .{ .double = node.data.double },
            .node_array => .{ .node_array = try from_node_array(allocator, node.data.list) },
            .node_map => .{ .node_map = try from_node_map(allocator, node.data.list) },
            .byte_array => .{ .byte_array = try from_byte_array(allocator, node.data.byte_array) },
            else => .none,
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
            .none => node.format = .none,
            .string => |string| {
                node.format = .string;
                node.data.string = try allocator.dupeZ(u8, string);
            },
            .flag => |flag| {
                node.format = .flag;
                node.data.flag = @intFromBool(flag);
            },
            .int64 => |num| {
                node.format = .int64;
                node.data.int64 = num;
            },
            .double => |num| {
                node.format = .double;
                node.data.double = num;
            },
            .node_array => |array| {
                node.format = .node_array;
                node.data.list = try node_array_to_cdata(array, allocator);
            },
            .node_map => |map| {
                node.format = .node_map;
                node.data.list = try node_map_to_cdata(map, allocator);
            },
            .byte_array => |bytes| {
                node.format = .byte_array;
                node.data.byte_array = try byte_array_to_cdata(bytes, allocator);
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
    none,
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
            .none => return .none,
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

pub fn create_cstring_array(z_array: []const []const u8, allocator: Allocator) AllocatorError![:0][*c]const u8 {
    const array = try allocator.allocSentinel([*c]const u8, z_array.len, 0);
    for (0..z_array.len) |index| {
        array[index] = try allocator.dupeZ(u8, z_array[index]);
    }
    return array;
}

pub fn free_cstring_array(c_array: [:0][*c]const u8, allocator: Allocator) void {
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
