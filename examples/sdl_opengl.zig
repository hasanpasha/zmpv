const std = @import("std");
const zmpv = @import("zmpv");
const Mpv = zmpv.Mpv;
const MpvRenderContext = zmpv.MpvRenderContext;
const MpvRenderParam = MpvRenderContext.MpvRenderParam;
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

var wakeup_on_mpv_render_update: sdl.Uint32 = undefined;
var wakeup_on_mpv_events: sdl.Uint32 = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) @panic("leak");
    }

    var mpv = try Mpv.create(gpa.allocator());
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
    const mpv_render_ctx = try mpv.create_render_context(&params);
    defer mpv_render_ctx.free();

    try mpv_render_ctx.set_parameter(.{ .AmbientLight = -100000000 });

    wakeup_on_mpv_render_update = sdl.SDL_RegisterEvents(1);
    wakeup_on_mpv_events = sdl.SDL_RegisterEvents(1);

    mpv.set_wakeup_callback(wakeup_callback, null);
    mpv_render_ctx.set_update_callback(&on_mpv_render_update, null);

    try mpv.request_log_messages(.Error);

    const filepath = "resources/sample.mp4";
    try mpv.command_async(0, &.{ "loadfile", filepath });

    const fullscreen_status = try mpv.get_property("fullscreen", .String);
    mpv.free(fullscreen_status);

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
                } else if (event.key.keysym.sym == sdl.SDLK_RIGHT) {
                    var seek_r_args = [_][]const u8{ "seek", "30" };
                    try mpv.command_async(0, &seek_r_args);
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
                        } else if (mpv_event.event_id == .Shutdown or mpv_event.event_id == .EndFile) {
                            break :done;
                        } else if (mpv_event.event_id == .LogMessage) {
                            const log = mpv_event.data.LogMessage;
                            std.log.info("\"{s}\"", .{log.text});
                        }
                    }
                }
            },
        }

        if (redraw) {
            const info = try mpv_render_ctx.get_info(.NextFrameInfo);
            std.log.debug("{}", .{info});

            var w: c_int = undefined;
            var h: c_int = undefined;
            sdl.SDL_GetWindowSize(window, &w, &h);

            var zig_render_params = [_]MpvRenderParam{
                .{ .SkipRendering = false },
                .{ .OpenglFbo = .{
                    .fbo = 0,
                    .w = w,
                    .h = h,
                    .internal_format = 0,
                } },
                .{ .FlipY = true },
                .{ .Depth = 16 },
                .{ .BlockForTargetTime = true },
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
