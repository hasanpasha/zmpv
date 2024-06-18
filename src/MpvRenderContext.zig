const c = @import("./c.zig");
const Mpv = @import("./Mpv.zig");
const std = @import("std");
const mpv_error = @import("./mpv_error.zig");
const MpvError = mpv_error.MpvError;
const catch_mpv_error = @import("./utils.zig").catch_mpv_error;

const Self = @This();

context: *c.mpv_render_context,
allocator: std.mem.Allocator,

fn params_list_to_c(params: []MpvRenderParam, allocator: std.mem.Allocator) ![*c]c.mpv_render_param {
    var c_params = try allocator.alloc(c.mpv_render_param, params.len);
    for (0..params.len) |index| {
        c_params[index] = try params[index].to_c(allocator);
    }
    return @ptrCast(c_params);
}

pub fn create(mpv: Mpv, params: []MpvRenderParam) !Self {
    var context: *c.mpv_render_context = undefined;

    const allocator = mpv.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const c_params = try Self.params_list_to_c(params, arena.allocator());
    try catch_mpv_error(c.mpv_render_context_create(@ptrCast(&context), mpv.handle, c_params));

    return Self{
        .context = context,
        .allocator = allocator,
    };
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
    // std.log.debug("get_info {any}", .{data});

    return MpvRenderParam.from(param_type, data);
}

pub fn render(self: Self, params: []MpvRenderParam) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    const c_params = try Self.params_list_to_c(params, arena.allocator());
    try catch_mpv_error(c.mpv_render_context_render(self.context, c_params));
}

pub fn set_update_callback(self: Self, callback: ?*const fn (?*anyopaque) void, ctx: ?*anyopaque) void {
    c.mpv_render_context_set_update_callback(self.context, @ptrCast(callback), ctx);
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
        const param_type: c.mpv_render_param_type = @intCast(@intFromEnum(self));
        return param_type;
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
    get_process_address: ?*const fn (?*anyopaque, [*c]const u8) ?*anyopaque,
    get_process_address_ctx: ?*anyopaque,

    pub fn to_c(self: MpvOpenGLInitParams, allocator: std.mem.Allocator) !*c.mpv_opengl_init_params {
        const value_ptr = try allocator.create(c.mpv_opengl_init_params);
        value_ptr.*.get_proc_address = @ptrCast(self.get_process_address);
        value_ptr.*.get_proc_address_ctx = self.get_process_address_ctx;
        return value_ptr;
    }
};

pub const MpvOpenGLFBO = struct {
    fbo: i64,
    w: i64,
    h: i64,
    internal_format: i64,

    pub fn to_c(self: MpvOpenGLFBO, allocator: std.mem.Allocator) !*c.mpv_opengl_fbo {
        const value_ptr = try allocator.create(c.mpv_opengl_fbo);
        value_ptr.*.fbo = @intCast(self.fbo);
        value_ptr.*.w = @intCast(self.w);
        value_ptr.*.h = @intCast(self.h);
        value_ptr.*.internal_format = @intCast(self.internal_format);
        return value_ptr;
    }
};

pub const MpvRenderFrameInfoFlag = struct {
    present: bool,
    redraw: bool,
    repeat: bool,
    block_vsync: bool,

    pub fn to_c(self: MpvRenderFrameInfoFlag) u64 {
        var flag: u64 = 0;
        flag = if (self.present) flag | c.MPV_RENDER_FRAME_INFO_PRESENT else flag;
        flag = if (self.redraw) flag | c.MPV_RENDER_FRAME_INFO_REDRAW else flag;
        flag = if (self.repeat) flag | c.MPV_RENDER_FRAME_INFO_REPEAT else flag;
        flag = if (self.block_vsync) flag | c.MPV_RENDER_FRAME_INFO_BLOCK_VSYNC else flag;
        return flag;
    }
};

pub const MpvRenderFrameInfo = struct {
    flags: MpvRenderFrameInfoFlag,
    target_time: i64,

    pub fn from(data: c.mpv_render_frame_info) MpvRenderFrameInfo {
        const flags = MpvRenderFrameInfoFlag{
            .present = (data.flags & c.MPV_RENDER_FRAME_INFO_PRESENT) == 1,
            .redraw = (data.flags & c.MPV_RENDER_FRAME_INFO_REDRAW) == 1,
            .repeat = (data.flags & c.MPV_RENDER_FRAME_INFO_REPEAT) == 1,
            .block_vsync = (data.flags & c.MPV_RENDER_FRAME_INFO_BLOCK_VSYNC) == 1,
        };

        return MpvRenderFrameInfo{
            .flags = flags,
            .target_time = data.target_time,
        };
    }

    pub fn to_c(self: MpvRenderFrameInfo, allocator: std.mem.Allocator) !*c.mpv_render_frame_info {
        const value_ptr = try allocator.create(c.mpv_render_frame_info);
        value_ptr.*.flags = self.flags.to_c();
        value_ptr.*.target_time = self.target_time;
        return value_ptr;
    }
};

const MpvOpenGLDRMDrawSurfaceSize = struct {
    width: i64,
    height: i64,

    pub fn to_c(self: MpvOpenGLDRMDrawSurfaceSize, allocator: std.mem.Allocator) !*c.mpv_opengl_drm_draw_surface_size {
        const value_ptr = try allocator.create(c.mpv_opengl_drm_draw_surface_size);
        value_ptr.*.width = @intCast(self.width);
        value_ptr.*.height = @intCast(self.height);
        return value_ptr;
    }
};

const MpvOpenGLDRMParams = struct {
    fd: i64,
    crtc_id: i64,
    connector_id: i64,
    atomic_request_ptr: [*c]?*anyopaque, // not tested
    render_fd: i64,

    pub fn to_c(self: MpvOpenGLDRMParams, allocator: std.mem.Allocator) !*c.mpv_opengl_drm_params {
        const value_ptr = try allocator.create(c.mpv_opengl_drm_params);
        value_ptr.*.fd = @intCast(self.fd);
        value_ptr.*.crtc_id = @intCast(self.crtc_id);
        value_ptr.*.connector_id = @intCast(self.connector_id);
        value_ptr.*.atomic_request_ptr = @ptrCast(self.atomic_request_ptr);
        value_ptr.*.render_fd = @intCast(self.render_fd);
        return value_ptr;
    }

    pub fn to_c_v2(self: MpvOpenGLDRMParams, allocator: std.mem.Allocator) !*c.mpv_opengl_drm_params_v2 {
        const value_ptr = try allocator.create(c.mpv_opengl_drm_params_v2);
        value_ptr.*.fd = @intCast(self.fd);
        value_ptr.*.crtc_id = @intCast(self.crtc_id);
        value_ptr.*.connector_id = @intCast(self.connector_id);
        value_ptr.*.atomic_request_ptr = @ptrCast(self.atomic_request_ptr);
        value_ptr.*.render_fd = @intCast(self.render_fd);
        return value_ptr;
    }
};

const MpvSwSize = struct {
    w: i64,
    h: i64,

    pub fn to_c(self: MpvSwSize, allocator: std.mem.Allocator) !*[2]c_int {
        const value_ptr = try allocator.create([2]c_int);
        value_ptr.*[0] = @intCast(self.w);
        value_ptr.*[1] = @intCast(self.h);
        return value_ptr;
    }
};

const MpvSwFormat = enum {
    Rgb0,
    Bgr0,
    @"0bgr",
    @"0rgb",

    pub fn to_c(self: MpvSwFormat) *[4:0]u8 {
        const value = switch (self) {
            .Rgb0 => "rgb0",
            .Bgr0 => "bgr0",
            .@"0bgr" => "0bgr",
            .@"0rgb" => "0rgb",
        };
        return @constCast(value);
    }
};

pub const MpvRenderParam = union(MpvRenderParamType) {
    Invalid: void,
    ApiType: MpvRenderApiType,
    OpenglInitParams: MpvOpenGLInitParams,
    OpenglFbo: MpvOpenGLFBO,
    FlipY: bool,
    Depth: i64,
    IccProfile: []u8,
    AmbientLight: i64,
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
    SwFormat: MpvSwFormat,
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
            .NextFrameInfo => |next_frame_info| {
                param.type = MpvRenderParamType.NextFrameInfo.to_c();
                param.data = try next_frame_info.to_c(allocator);
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
                param.data = @ptrCast(data);
            },
            .SwFormat => |format| {
                param.type = MpvRenderParamType.SwFormat.to_c();
                param.data = @ptrCast(format.to_c());
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
        }
        return param;
    }
};
