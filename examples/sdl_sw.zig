const zmpv = @import("zmpv");
const Mpv = zmpv.Mpv;
const MpvRenderContext = zmpv.MpvRenderContext;
const MpvRenderParam = MpvRenderContext.MpvRenderParam;
const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});
const config = @import("config");

var wakeup_on_mpv_render_update: sdl.Uint32 = undefined;
var wakeup_on_mpv_events: sdl.Uint32 = undefined;

pub fn main() !void {
    var mpv = try Mpv.create(std.heap.page_allocator);
    defer mpv.terminate_destroy();

    try mpv.set_option_string("vo", "libmpv");
    try mpv.set_option_string("hwdec", "vaapi");
    try mpv.initialize();

    _ = sdl.SDL_SetHint(sdl.SDL_HINT_NO_SIGNAL_HANDLERS, "no");
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) < 0) {
        return error.SDLInitFailure;
    }

    var window: *sdl.SDL_Window = undefined;
    var renderer: *sdl.SDL_Renderer = undefined;
    // const window = sdl.SDL_CreateWindow(
    //     "sdl - mpv rendering",
    //     sdl.SDL_WINDOWPOS_CENTERED,
    //     sdl.SDL_WINDOWPOS_CENTERED,
    //     1080,
    //     720,
    //     sdl.SDL_WINDOW_OPENGL | sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE,
    // ) orelse {
    //     return error.Nullvalue;
    // };
    if (sdl.SDL_CreateWindowAndRenderer(
        1080,
        720,
        sdl.SDL_WINDOW_OPENGL | sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE,
        @ptrCast(&window),
        @ptrCast(&renderer),
    ) != 0) {
        return error.NullValue;
    }

    var params = [_]MpvRenderParam{
        .{ .ApiType = .SW },
        .{ .AdvancedControl = true },
        .{ .Invalid = {} },
    };

    const mpv_render_ctx = try MpvRenderContext.create(mpv, &params);
    defer mpv_render_ctx.free();

    wakeup_on_mpv_render_update = sdl.SDL_RegisterEvents(1);
    wakeup_on_mpv_events = sdl.SDL_RegisterEvents(1);

    mpv.set_wakeup_callback(wakeup_callback, null);
    mpv_render_ctx.set_update_callback(&on_mpv_render_update, null);

    try mpv.request_log_messages(.Error);

    const filepath = config.filepath;
    try mpv.command_async(0, &.{ "loadfile", filepath });

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
                    var pause_args = [_][]const u8{ "cycle", "pause" };
                    try mpv.command_async(0, &pause_args);
                }
            },
            else => {
                if (event.type == wakeup_on_mpv_render_update) {
                    redraw = mpv_render_ctx.update();
                } else if (event.type == wakeup_on_mpv_events) {
                    while (true) {
                        const mpv_event = mpv.wait_event(0);

                        if (mpv_event.event_id == .None) {
                            break;
                        } else if (mpv_event.event_id == .LogMessage) {
                            const log = mpv_event.data.LogMessage;
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

            var zig_render_params = [_]MpvRenderParam{
                .{ .SwSize = .{ .w = @intCast(w), .h = @intCast(h) } },
                .{ .SwFormat = .@"0bgr" },
                .{ .SwStride = @intCast(pitch) },
                .{ .SwPointer = pixels },
                .{ .SkipRendering = false },
                .{ .FlipY = true },
                .{ .Depth = 16 },
                .{ .BlockForTargetTime = false },
                .{ .Invalid = {} },
            };
            try mpv_render_ctx.render(&zig_render_params);
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

fn get_process_address(ctx: ?*anyopaque, name: [*c]const u8) ?*anyopaque {
    _ = ctx;
    return sdl.SDL_GL_GetProcAddress(name);
}
