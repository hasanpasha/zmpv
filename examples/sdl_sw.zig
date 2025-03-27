const zmpv = @import("zmpv");
const MpvHandle = zmpv.MpvHandle;
const MpvRenderParam = zmpv.MpvRenderParam;
const MpvRenderApiType = zmpv.MpvRenderApiType;
const MpvRenderParamData = zmpv.MpvRenderParamData;
const MpvOpenGLInitParams = zmpv.MpvOpenGLInitParams;
const MpvRenderContext = zmpv.MpvRenderContext;
const MpvOpenGLFBO = zmpv.MpvOpenGLFBO;
const MpvRenderUpdateFlag = zmpv.MpvRenderUpdateFlag;
const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});
const config = @import("config");

var wakeup_on_mpv_render_update: sdl.Uint32 = undefined;
var wakeup_on_mpv_events: sdl.Uint32 = undefined;

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    var mpv = try MpvHandle.create_z();
    try mpv.set_option_string("vo", "libmpv").check_error_z();
    try mpv.set_option_string("hwdec", "vaapi").check_error_z();

    try mpv.initialize_z();

    defer mpv.terminate_destroy();

    _ = sdl.SDL_SetHint(sdl.SDL_HINT_NO_SIGNAL_HANDLERS, "no");
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) < 0) {
        return error.SDLInitFailure;
    }

    var window_op: ?*sdl.SDL_Window = null;
    var renderer_op: ?*sdl.SDL_Renderer = null;
    if (sdl.SDL_CreateWindowAndRenderer(
        1080,
        720,
        sdl.SDL_WINDOW_OPENGL | sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE,
        &window_op,
        &renderer_op,
    ) != 0) {
        return error.null_value;
    }

    const window = window_op orelse return error.null_value;
    const renderer = renderer_op orelse return error.null_value;

    var advanced_control: c_int = 1;
    var params = [_]MpvRenderParam{
        .new_z(.{ .api_type = MpvRenderApiType.sw }),
        .new_z(.{ .advanced_control = &advanced_control }),
        .invalid,
    };

    var mpv_render_ctx_op: ?*MpvRenderContext = null;
    try MpvRenderContext.create(&mpv_render_ctx_op, mpv, &params).check_error_z();

    const mpv_render_ctx = mpv_render_ctx_op orelse return error.null_value;
    defer mpv_render_ctx.free();

    wakeup_on_mpv_render_update = sdl.SDL_RegisterEvents(1);
    wakeup_on_mpv_events = sdl.SDL_RegisterEvents(1);

    mpv.set_wakeup_callback(wakeup_callback);
    mpv_render_ctx.set_update_callback(&on_mpv_render_update, null);

    try mpv.request_log_messages("error").check_error_z();

    const filepath = config.filepath;
    try mpv.command_async_z(alloc, 0, &.{ "loadfile", filepath });

    var tex: ?*sdl.SDL_Texture = null;
    defer sdl.SDL_DestroyTexture(tex);
    var tex_w: c_int = -1;
    var tex_h: c_int = -1;

    var redraw: bool = false;
    done: while (true) {
        redraw = false;
        var event: sdl.SDL_Event = undefined;
        if (sdl.SDL_WaitEvent(&event) != 1) {
            break;
        }

        switch (event.type) {
            sdl.SDL_QUIT => break :done,
            sdl.SDL_WINDOWEVENT => {
                redraw = true;
            },
            sdl.SDL_KEYDOWN => {
                if (event.key.keysym.sym == sdl.SDLK_q) {
                    break;
                } else if (event.key.keysym.sym == sdl.SDLK_SPACE) {
                    try mpv.command_async_z(alloc, 0, &.{ "cycle", "pause" });
                }
            },
            else => {
                if (event.type == wakeup_on_mpv_render_update) {
                    const flags = mpv_render_ctx.update();
                    redraw = MpvRenderUpdateFlag.frame.in_flags(flags);
                } else if (event.type == wakeup_on_mpv_events) {
                    while (true) {
                        const mpv_event = mpv.wait_event(0);

                        if (mpv_event.id == .none) {
                            break;
                        } else if (mpv_event.id == .log_message) {
                            const log = mpv_event.get_data_z().log_message;
                            std.log.info("\"{s}\"", .{log.text});
                        }
                    }
                }
            },
        }

        if (redraw) {
            var w: c_int = undefined;
            var h: c_int = undefined;
            sdl.SDL_GetWindowSize(window, &w, &h);
            if (tex == null or tex_w != w or tex_h != h) {
                sdl.SDL_DestroyTexture(tex);
                tex = sdl.SDL_CreateTexture(renderer, sdl.SDL_PIXELFORMAT_RGBX8888, sdl.SDL_TEXTUREACCESS_STREAMING, w, h);

                if (tex == null) {
                    return error.NullValue;
                }

                tex_w = w;
                tex_h = h;
            }

            var pixels: *anyopaque = undefined;
            var pitch: c_int = undefined;
            if (sdl.SDL_LockTexture(tex, null, @ptrCast(&pixels), &pitch) != 0) {
                return error.SDLError;
            }

            var stride: isize = @intCast(pitch);
            var flip_y: c_int = 1;
            var size: [2]c_int = .{ w, h };
            var zig_render_params = [_]MpvRenderParam{
                .new_z(.{ .sw_size = &size }),
                .new_z(.{ .sw_format = "0bgr" }),
                .new_z(.{ .sw_stride = &stride }),
                .new_z(.{ .sw_pointer = pixels }),
                .new_z(.{ .flip_y = &flip_y }),
                .invalid,
            };
            try mpv_render_ctx.render(&zig_render_params).check_error_z();
            sdl.SDL_UnlockTexture(tex);
            _ = sdl.SDL_RenderCopy(renderer, tex, null, null);
            sdl.SDL_RenderPresent(renderer);
        }
    }
}

fn wakeup_callback(data: ?*anyopaque) void {
    _ = data;
    var event = sdl.SDL_Event{ .type = wakeup_on_mpv_events };
    _ = sdl.SDL_PushEvent(@ptrCast(&event));
}

fn on_mpv_render_update(data: ?*anyopaque) void {
    _ = data;
    var event = sdl.SDL_Event{ .type = wakeup_on_mpv_render_update };
    _ = sdl.SDL_PushEvent(@ptrCast(&event));
}
