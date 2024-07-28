const std = @import("std");
const c = @import("c.zig");
const Mpv = @import("Mpv.zig");
const mpv_error = @import("mpv_error.zig");
const MpvError = mpv_error.MpvError;
const GenericError = @import("generic_error.zig").GenericError;
const catch_mpv_error = @import("utils.zig").catch_mpv_error;

const Self = @This();

context: *c.mpv_render_context,
allocator: std.mem.Allocator,

fn params_list_to_c(params: []MpvRenderParam, allocator: std.mem.Allocator) ![*c]c.mpv_render_param {
    var c_params = try allocator.alloc(c.mpv_render_param, params.len);
    for (0..params.len) |index| {
        c_params[index] = try params[index].to_c(allocator);
    }
    return c_params.ptr;
}

pub fn create(mpv: *Mpv, params: []MpvRenderParam) !Self {
    var context: ?*c.mpv_render_context = undefined;

    const allocator = mpv.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const c_params = try Self.params_list_to_c(params, arena.allocator());
    try catch_mpv_error(c.mpv_render_context_create(&context, mpv.handle, c_params));

    if (context) |ctx| {
        return Self{
            .context = ctx,
            .allocator = allocator,
        };
    } else {
        return GenericError.NullValue;
    }

}

pub fn free(self: Self) void {
    c.mpv_render_context_free(self.context);
}

pub fn set_parameter(self: Self, param: MpvRenderParam) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    const c_param = try param.to_c(arena.allocator());
    try catch_mpv_error(c.mpv_render_context_set_parameter(self.context, c_param));
}

pub fn get_info(self: Self, comptime param_type: MpvRenderParamType) !MpvRenderParam {
    const param_data_type = param_type.CDataType();
    var data: param_data_type = undefined;
    const param = c.mpv_render_param{
        .type = param_type.to_c(),
        .data = &data,
    };
    try catch_mpv_error(c.mpv_render_context_get_info(self.context, param));

    return MpvRenderParam.from(param_type, data);
}

pub fn render(self: Self, params: []MpvRenderParam) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    const c_params = try Self.params_list_to_c(params, arena.allocator());
    try catch_mpv_error(c.mpv_render_context_render(self.context, c_params));
}

pub inline fn set_update_callback(self: Self, callback: *const fn (?*anyopaque) void, ctx: ?*anyopaque) void {
    const c_wrapper = struct {
        pub fn cb(cx: ?*anyopaque) callconv(.C) void {
            @call(.always_inline, callback, .{ cx });
        }
    }.cb;

    c.mpv_render_context_set_update_callback(self.context, c_wrapper, ctx);
}

pub fn update(self: Self) bool {
    const flags = c.mpv_render_context_update(self.context);
    return (flags & c.MPV_RENDER_UPDATE_FRAME) == 1;
}

pub fn report_swap(self: Self) void {
    c.mpv_render_context_report_swap(self.context);
}

pub const MpvRenderParamType = enum(c.mpv_render_param_type) {
    Invalid = c.MPV_RENDER_PARAM_INVALID,
    ApiType = c.MPV_RENDER_PARAM_API_TYPE,
    OpenglInitParams = c.MPV_RENDER_PARAM_OPENGL_INIT_PARAMS,
    OpenglFbo = c.MPV_RENDER_PARAM_OPENGL_FBO,
    FlipY = c.MPV_RENDER_PARAM_FLIP_Y,
    Depth = c.MPV_RENDER_PARAM_DEPTH,
    IccProfile = c.MPV_RENDER_PARAM_ICC_PROFILE,
    AmbientLight = c.MPV_RENDER_PARAM_AMBIENT_LIGHT,
    X11Display = c.MPV_RENDER_PARAM_X11_DISPLAY,
    WlDisplay = c.MPV_RENDER_PARAM_WL_DISPLAY,
    AdvancedControl = c.MPV_RENDER_PARAM_ADVANCED_CONTROL,
    NextFrameInfo = c.MPV_RENDER_PARAM_NEXT_FRAME_INFO,
    BlockForTargetTime = c.MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME,
    SkipRendering = c.MPV_RENDER_PARAM_SKIP_RENDERING,
    DrmDisplay = c.MPV_RENDER_PARAM_DRM_DISPLAY,
    DrmDrawSurfaceSize = c.MPV_RENDER_PARAM_DRM_DRAW_SURFACE_SIZE,
    DrmDisplayV2 = c.MPV_RENDER_PARAM_DRM_DISPLAY_V2,
    SwSize = c.MPV_RENDER_PARAM_SW_SIZE,
    SwFormat = c.MPV_RENDER_PARAM_SW_FORMAT,
    SwStride = c.MPV_RENDER_PARAM_SW_STRIDE,
    SwPointer = c.MPV_RENDER_PARAM_SW_POINTER,

    pub fn to_c(self: MpvRenderParamType) c.mpv_render_param_type {
        return @intFromEnum(self);
    }

    pub inline fn CDataType(comptime self: MpvRenderParamType) type {
        return switch (self) {
            .NextFrameInfo => c.mpv_render_frame_info,
            else => @panic("Unimplemented"),
        };
    }
};

pub const MpvRenderApiType = enum {
    OpenGL,
    SW,

    pub fn to_c(self: MpvRenderApiType) *anyopaque {
        const text = switch (self) {
            .OpenGL => c.MPV_RENDER_API_TYPE_OPENGL,
            .SW => c.MPV_RENDER_API_TYPE_SW,
        };
        return @ptrCast(@constCast(text));
    }
};

pub const MpvOpenGLInitParams = struct {
    get_process_address: *const fn (?*anyopaque, [*c]const u8) callconv(.C) ?*anyopaque,
    get_process_address_ctx: ?*anyopaque,

    pub fn to_c(self: MpvOpenGLInitParams, allocator: std.mem.Allocator) !*c.mpv_opengl_init_params {
        const value_ptr = try allocator.create(c.mpv_opengl_init_params);
        value_ptr.* = .{
            .get_proc_address = self.get_process_address,
            .get_proc_address_ctx = self.get_process_address_ctx,
        };
        return value_ptr;
    }
};

pub const MpvOpenGLFBO = struct {
    fbo: i32 = 0,
    w: i32,
    h: i32,
    internal_format: i32 = 0,

    pub fn to_c(self: MpvOpenGLFBO, allocator: std.mem.Allocator) !*c.mpv_opengl_fbo {
        const value_ptr = try allocator.create(c.mpv_opengl_fbo);
        value_ptr.* = .{
            .fbo = @intCast(self.fbo),
            .w = @intCast(self.w),
            .h = @intCast(self.h),
            .internal_format = @intCast(self.internal_format),
        };
        return value_ptr;
    }
};

pub const MpvRenderFrameInfoFlag = struct {
    present: bool,
    redraw: bool,
    repeat: bool,
    block_vsync: bool,

    pub fn from(flags: u64) MpvRenderFrameInfoFlag {
        return MpvRenderFrameInfoFlag{
            .present = (flags & c.MPV_RENDER_FRAME_INFO_PRESENT) == 1,
            .redraw = (flags & c.MPV_RENDER_FRAME_INFO_REDRAW) == 1,
            .repeat = (flags & c.MPV_RENDER_FRAME_INFO_REPEAT) == 1,
            .block_vsync = (flags & c.MPV_RENDER_FRAME_INFO_BLOCK_VSYNC) == 1,
        };

    }
};

pub const MpvRenderFrameInfo = struct {
    flags: MpvRenderFrameInfoFlag,
    target_time: i64,

    pub fn from(data: c.mpv_render_frame_info) MpvRenderFrameInfo {
        return MpvRenderFrameInfo{
            .flags = MpvRenderFrameInfoFlag.from(data.flags),
            .target_time = data.target_time,
        };
    }
};

const MpvOpenGLDRMDrawSurfaceSize = struct {
    width: i32,
    height: i32,

    pub fn to_c(self: MpvOpenGLDRMDrawSurfaceSize, allocator: std.mem.Allocator) !*c.mpv_opengl_drm_draw_surface_size {
        const value_ptr = try allocator.create(c.mpv_opengl_drm_draw_surface_size);
        value_ptr.* = .{
            .width = @intCast(self.width),
            .height = @intCast(self.height),
        };
        return value_ptr;
    }
};

const MpvOpenGLDRMParams = struct {
    fd: i32,
    crtc_id: i32,
    connector_id: i32,
    atomic_request_ptr: [*c]?*anyopaque, // not tested
    render_fd: i32,

    pub fn to_c(self: MpvOpenGLDRMParams, allocator: std.mem.Allocator) !*c.mpv_opengl_drm_params {
        const value_ptr = try allocator.create(c.mpv_opengl_drm_params);
        value_ptr.* = .{
            .fd = @intCast(self.fd),
            .crtc_id = @intCast(self.crtc_id),
            .connector_id = @intCast(self.connector_id),
            .atomic_request_ptr = @ptrCast(self.atomic_request_ptr),
            .render_fd = @intCast(self.render_fd),
        };
        return value_ptr;
    }

    pub fn to_c_v2(self: MpvOpenGLDRMParams, allocator: std.mem.Allocator) !*c.mpv_opengl_drm_params_v2 {
        const value_ptr = try allocator.create(c.mpv_opengl_drm_params_v2);
        value_ptr.* = .{
            .fd = @intCast(self.fd),
            .crtc_id = @intCast(self.crtc_id),
            .connector_id = @intCast(self.connector_id),
            .atomic_request_ptr = @ptrCast(self.atomic_request_ptr),
            .render_fd = @intCast(self.render_fd),
        };
        return value_ptr;
    }
};

const MpvSwSize = struct {
    w: i32,
    h: i32,

    pub fn to_c(self: MpvSwSize, allocator: std.mem.Allocator) !*[2]c_int {
        const value_ptr = try allocator.create([2]c_int);
        value_ptr.* = .{ @intCast(self.w), @intCast(self.h) };
        return value_ptr;
    }
};

pub const MpvRenderParam = union(MpvRenderParamType) {
    Invalid: void,
    ApiType: MpvRenderApiType,
    OpenglInitParams: MpvOpenGLInitParams,
    OpenglFbo: MpvOpenGLFBO,
    FlipY: bool,
    Depth: i32,
    IccProfile: []u8,
    AmbientLight: i32,
    X11Display: *anyopaque, // *Display
    WlDisplay: *anyopaque, // *wl_display
    AdvancedControl: bool,
    NextFrameInfo: MpvRenderFrameInfo,
    BlockForTargetTime: bool,
    SkipRendering: bool,
    DrmDisplay: MpvOpenGLDRMParams,
    DrmDrawSurfaceSize: MpvOpenGLDRMDrawSurfaceSize,
    DrmDisplayV2: MpvOpenGLDRMParams,
    SwSize: MpvSwSize,
    SwFormat: []const u8,
    SwStride: usize,
    SwPointer: *anyopaque,

    pub fn from(param_type: MpvRenderParamType, data: anytype) MpvRenderParam {
        switch (param_type) {
            .NextFrameInfo => {
                return .{ .NextFrameInfo = MpvRenderFrameInfo.from(data) };
            },
            else => @panic("Unimplemented"),
        }
    }

    pub fn to_c(self: MpvRenderParam, allocator: std.mem.Allocator) !c.mpv_render_param {
        var param: c.mpv_render_param = undefined;
        switch (self) {
            .Invalid => {
                param.type = MpvRenderParamType.Invalid.to_c();
                param.data = null;
            },
            .ApiType => |api_type| {
                param.type = MpvRenderParamType.ApiType.to_c();
                param.data = api_type.to_c();
            },
            .OpenglInitParams => |opengl_init_params| {
                param.type = MpvRenderParamType.OpenglInitParams.to_c();
                param.data = try opengl_init_params.to_c(allocator);
            },
            .OpenglFbo => |opengl_fbo| {
                param.type = MpvRenderParamType.OpenglFbo.to_c();
                param.data = try opengl_fbo.to_c(allocator);
            },
            .Depth => |depth| {
                param.type = MpvRenderParamType.Depth.to_c();
                const value_ptr = try allocator.create(c_int);
                value_ptr.* = @intCast(depth);
                param.data = value_ptr;
            },
            .FlipY => |flip| {
                param.type = MpvRenderParamType.FlipY.to_c();
                const value_ptr = try allocator.create(c_int);
                value_ptr.* = if (flip) 1 else 0;
                param.data = value_ptr;
            },
            .IccProfile => |icc_profile| {
                param.type = MpvRenderParamType.IccProfile.to_c();
                const value_ptr = try allocator.create(c.mpv_byte_array);
                value_ptr.data = icc_profile.ptr;
                value_ptr.size = icc_profile.len;
                param.data = value_ptr;
            },
            .AmbientLight => |light| {
                param.type = MpvRenderParamType.AmbientLight.to_c();
                const value_ptr = try allocator.create(c_int);
                value_ptr.* = @intCast(light);
                param.data = value_ptr;
            },
            .X11Display => |x11_display| {
                param.type = MpvRenderParamType.X11Display.to_c();
                param.data = x11_display;
            },
            .WlDisplay => |wl_display| {
                param.type = MpvRenderParamType.WlDisplay.to_c();
                param.data = wl_display;
            },
            .AdvancedControl => |advanced| {
                param.type = MpvRenderParamType.AdvancedControl.to_c();
                const value_ptr = try allocator.create(c_int);
                value_ptr.* = if (advanced) 1 else 0;
                param.data = value_ptr;
            },
            .BlockForTargetTime => |block| {
                param.type = MpvRenderParamType.BlockForTargetTime.to_c();
                const value_ptr = try allocator.create(c_int);
                value_ptr.* = if (block) 1 else 0;
                param.data = value_ptr;
            },
            .SkipRendering => |skip| {
                param.type = MpvRenderParamType.SkipRendering.to_c();
                const value_ptr = try allocator.create(c_int);
                value_ptr.* = if (skip) 1 else 0;
                param.data = value_ptr;
            },
            .DrmDisplay => |params| {
                param.type = MpvRenderParamType.DrmDisplay.to_c();
                param.data = try params.to_c(allocator);
            },
            .DrmDrawSurfaceSize => |size| {
                param.type = MpvRenderParamType.DrmDrawSurfaceSize.to_c();
                param.data = try size.to_c(allocator);
            },
            .DrmDisplayV2 => |params| {
                param.type = MpvRenderParamType.DrmDisplayV2.to_c();
                param.data = try params.to_c_v2(allocator);
            },
            .SwSize => |size| {
                param.type = MpvRenderParamType.SwSize.to_c();
                const data = try size.to_c(allocator);
                param.data = data;
            },
            .SwFormat => |format| {
                param.type = MpvRenderParamType.SwFormat.to_c();
                param.data = @ptrCast(@constCast(format.ptr));
            },
            .SwStride => |stride| {
                param.type = MpvRenderParamType.SwStride.to_c();
                const value_ptr = try allocator.create(usize);
                value_ptr.* = stride;
                param.data = value_ptr;
            },
            .SwPointer => |pointer| {
                param.type = MpvRenderParamType.SwPointer.to_c();
                param.data = pointer;
            },
            else => @panic("Unimplement"),
        }
        return param;
    }
};
