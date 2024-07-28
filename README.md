# zmpv

`libmpv` bindings in zig.

## Todo

- [X] Finish wrapping all exported `libmpv` functions.
  - [X] `mpv/client.h`
  - [X] `mpv/render.h`
  - [X] `mpv/render_gl.h`
  - [X] `mpv/stream_cb.h`
- [X] ~~Fix memory leak~~
  - [X] ~~Free memory that is allocated by libmpv.~~ (mostly, please open an issue if you come across unallocated memory)
- [ ] write more tests.
- [ ] Add another struct that contains helper functions.
  - [ ] try implementing [python-mpv](https://github.com/jaseg/python-mpv) functionality.
- [X] Add Examples.
  - [ ] wayland rendering
  - [ ] x11 rendering
  - [ ] drm rendering
  - [X] simple usage
  - [X] opengl rendering
  - [X] software rendering
- [X] ~~Export as a library Make the library~~
  - [X] ~~cross-platform compatible~~ (the module user should link to `libmpv`)
- [X] Add usage guide.

## Usage

- first fetch the package into your project:

  ```bash
  zig fetch --save https://github.com/hasanpasha/zmpv/archive/${DESIRED_COMMOT_HASH}.tar.gz 
  ```
- import the package in your `build.zig` file:

  ```zig
  const zmpv_dep = b.dependency("zmpv", .{ .target = target, .optimize = optimize });
  exe.root_module.addImport("zmpv", zmpv_dep.module("zmpv"));
  exe.linkSystemLibrary("mpv"); # in linux
  exe.linkLibC();
  ```

## Example

```zig
const std = @import("std");
const zmpv = @import("zmpv");
const Mpv = zmpv.Mpv;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){};
    defer {
        if (gpa.deinit() == .leak) @panic("detected memory leak");
    }
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 2) {
        std.debug.print("usage: {s} [filename]\n", .{args[0]});
        return;
    }

    const filename = args[1];

    const mpv = try Mpv.create(allocator);

    try mpv.set_option("osc",.{ .Flag = true });
    try mpv.set_option("input-default-bindings",.{ .Flag = true });
    try mpv.set_option("input-vo-keyboard",.{ .Flag = true });

    try mpv.initialize();
    defer mpv.terminate_destroy();

    try mpv.command_async(0, &.{ "loadfile", filename });

    try mpv.request_log_messages(.Error);

    try mpv.observe_property(1, "fullscreen", .Flag);
    try mpv.observe_property(2, "time-pos", .INT64);

    try mpv.set_property("fullscreen", .{ .Flag = true });

    while (true) {
        const event = mpv.wait_event(-1);
        const event_id = event.event_id;
        switch (event_id) {
            .Shutdown, .EndFile => break,
            .LogMessage => {
                const log = event.data.LogMessage;
                std.log.debug("[{s}] \"{s}\"", .{ log.prefix, log.text });
            },
            .PropertyChange, .GetPropertyReply => {
                const property = event.data.PropertyChange;

                if (std.mem.eql(u8, property.name, "fullscreen")) {
                    std.log.debug("[fullscreen] {}", .{property.data.Flag});
                } else if (std.mem.eql(u8, property.name, "time-pos")) {
                    switch (property.data) {
                        .INT64 => |time_pos| {
                            std.log.debug("[time-pos] {}", .{time_pos});
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }
    }
}
```
