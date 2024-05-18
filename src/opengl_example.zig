const Mpv = @import("./mpv/Mpv.zig");
const MpvRenderContext = Mpv.MpvRenderContext;
const MpvRenderParam = Mpv.MpvRenderParam;
const std = @import("std");
const c = @import("./mpv/c.zig");
const sdl = @import("./sdl2.zig");

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

    const window = sdl.SDL_CreateWindow(
        "sdl - mpv rendering",
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        1080,
        720,
        sdl.SDL_WINDOW_OPENGL | sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE,
    ) orelse {
        return error.Nullvalue;
    };

    _ = sdl.SDL_GL_CreateContext(window) orelse {
        return error.NullValue;
    };

    var params = [_]MpvRenderParam{
        .{ .ApiType = .OpenGL },
        .{ .OpenglInitParams = .{ 
            .get_process_address = &get_process_address,
            .get_process_address_ctx = null, 
        } },
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

    var args = [_][]const u8{"loadfile", "sample.mp4"};
    try mpv.command_async(0, &args);

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
                    var pause_args = [_][]const u8{"cycle", "pause"};
                    try mpv.command_async(0, &pause_args);
                }
            },
            else => {
                if (event.type == wakeup_on_mpv_render_update) {
                    // const flags = c.mpv_render_context_update(mpv_context);
                    // if ((flags & c.MPV_RENDER_UPDATE_FRAME) == 1) {
                    //     redraw = true;
                    // }
                    redraw = mpv_render_ctx.update();
                } else if (event.type == wakeup_on_mpv_events) {
                    while (true) {
                        const mpv_event = try mpv.wait_event(0);
                        defer mpv_event.free();
                        
                        if (mpv_event.event_id == .None) {
                            break;
                        }
                        else if (mpv_event.event_id == .LogMessage) {
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

            var arena = std.heap.ArenaAllocator.init(mpv.allocator);
            defer arena.deinit();
            var zig_render_params = [_]MpvRenderParam{
                .{ .OpenglFbo = .{ .fbo = 0, .w = w, .h = h, .internal_format = 0, } },
                .{ .FlipY = true },
                .{ .Invalid = {} },
            };
            try mpv_render_ctx.render(&zig_render_params);
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

fn get_process_address(ctx: ?*anyopaque, name: [*c]const u8) ?*anyopaque {
    _ = ctx;
    return sdl.SDL_GL_GetProcAddress(name);
}
