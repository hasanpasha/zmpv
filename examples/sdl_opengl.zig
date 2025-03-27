const std = @import("std");
const zmpv = @import("zmpv");
const MpvRenderParam = zmpv.MpvRenderParam;
const MpvRenderApiType = zmpv.MpvRenderApiType;
const MpvRenderParamData = zmpv.MpvRenderParamData;
const MpvOpenGLInitParams = zmpv.MpvOpenGLInitParams;
const MpvRenderContext = zmpv.MpvRenderContext;
const MpvOpenGLFBO = zmpv.MpvOpenGLFBO;
const MpvRenderUpdateFlag = zmpv.MpvRenderUpdateFlag;
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});
const config = @import("config");

var wakeup_on_mpv_render_update: sdl.Uint32 = undefined;
var wakeup_on_mpv_events: sdl.Uint32 = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) @panic("leak");
    }
    const alloc = gpa.allocator();

    var mpv = try zmpv.MpvHandle.init_z(alloc, .{
        .vo = "libmpv",
        .hwdec = "auto",
    });

    _ = sdl.SDL_SetHint(sdl.SDL_HINT_NO_SIGNAL_HANDLERS, "no");
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) < 0) {
        return error.SDLInitFailure;
    }

    const window = sdl.SDL_CreateWindow(
        "sdl - mpv rendering",
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        1080,
        720,
        sdl.SDL_WINDOW_OPENGL | sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE,
    ) orelse {
        return error.null_value;
    };

    _ = sdl.SDL_GL_CreateContext(window) orelse {
        return error.null_value;
    };

    var init_params = MpvOpenGLInitParams{
        .get_proc_address = &get_process_address,
        .get_proc_address_ctx = mpv,
    };

    var params = [_]MpvRenderParam{
        .new_z(.{ .api_type = MpvRenderApiType.opengl }),
        .new_z(.{ .opengl_init_params = &init_params }),
        .invalid,
    };

    var mpv_render_ctx_ptr: ?*MpvRenderContext = undefined;
    try MpvRenderContext.create(&mpv_render_ctx_ptr, mpv, &params).check_error_z();

    var mpv_render_ctx = mpv_render_ctx_ptr orelse return error.null_value;
    defer mpv_render_ctx.free();

    var ambient_light: c_int = -1000;
    try mpv_render_ctx.set_parameter(.new_z(.{ .ambient_light = &ambient_light })).check_error_z();

    wakeup_on_mpv_render_update = sdl.SDL_RegisterEvents(1);
    wakeup_on_mpv_events = sdl.SDL_RegisterEvents(1);

    mpv.set_wakeup_callback(wakeup_callback);
    mpv_render_ctx.set_update_callback(&on_mpv_render_update, null);

    try mpv.request_log_messages("trace").check_error_z();

    const filepath = config.filepath;
    try mpv.command_async_z(alloc, 0, &.{ "loadfile", filepath });

    var fullscreen_status: bool = undefined;
    try mpv.get_property("fullscreen", .flag, &fullscreen_status).check_error_z();
    std.debug.print("is_fullscreen={}\n", .{fullscreen_status});
    // mpv.free(fullscreen_status);

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
                } else if (event.key.keysym.sym == sdl.SDLK_RIGHT) {
                    try mpv.command_async_z(alloc, 0, &.{ "seek", "30" });
                }
            },
            else => {
                if (event.type == wakeup_on_mpv_render_update) {
                    // redraw = mpv_render_ctx.update();
                    const flags = mpv_render_ctx.update();
                    redraw = MpvRenderUpdateFlag.frame.in_flags(flags);
                } else if (event.type == wakeup_on_mpv_events) {
                    while (true) {
                        const mpv_event = mpv.wait_event_z(.none);

                        if (mpv_event.id == .none) {
                            break;
                        } else if (mpv_event.id == .shutdown or mpv_event.id == .end_file) {
                            break :done;
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

            var fbo = MpvOpenGLFBO{
                .fbo = 0,
                .w = w,
                .h = h,
                .internal_format = 0,
            };
            var flip: c_int = 1;
            var zig_render_params = [_]MpvRenderParam{
                .new_z(.{ .opengl_fbo = &fbo }),
                .new_z(.{ .flip_y = &flip }),
                .invalid,
            };
            try mpv_render_ctx.render(&zig_render_params).check_error_z();
        }
        sdl.SDL_GL_SwapWindow(window);
        mpv_render_ctx.report_swap();
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

fn get_process_address(ctx: ?*anyopaque, name: [*c]const u8) callconv(.C) ?*anyopaque {
    var mpv: *zmpv.MpvHandle = @ptrCast(@alignCast(ctx));
    std.log.debug("mpv ID: {}, name: {s}", .{ mpv.client_id(), name });
    return sdl.SDL_GL_GetProcAddress(name);
}
