# zmpv
Work in progress.

## Todo
- [ ] Finish wrapping all exported mpv functions.
    - [x] `mpv/client.h`
    - [ ] `mpv/render.h`
    - [x] `mpv/render_gl.h`
    - [ ] `mpv/stream_cb.h`
- [x] Fix memory leaks.
- [ ] write more tests.
- [ ] Add another structs that contains helper functions.
- [x] Add Examples.
- [x] Export as a library.
- [x] Add usage guide.

## Usage
- first fetch the package into your project:
  ```bash
  zig fetch --save https://github.com/hasanpasha/zmpv/archive/${DESIRED_COMMOT_HASH}.tar.gz 
  ```
- import the package in your `build.zig` file:
  ```zig
  const zmpv_dep = b.dependency("zmpv", .{ .target = target, .optimize = optimize });
  exe.root_module.addImport("zmpv", zmpv_dep.module("zmpv"));
  exe.linkLibrary(zmpv_dep.artifact("zmpv_lib"));
  ```

## Example
```zig
const std = @import("std");
const zmpv = @import("zmpv");
const Mpv = zmpv.Mpv;

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);

    if (args.len < 2) {
        std.debug.print("usage: {s} [filename]\n", .{args[0]});
        return;
    }

    const filename = args[1];

    const mpv = try Mpv.new(std.heap.page_allocator);

    try mpv.set_option("osc", .Flag, .{ .Flag = true });
    try mpv.set_option("input-default-bindings", .Flag, .{ .Flag = true });
    try mpv.set_option("input-vo-keyboard", .Flag, .{ .Flag = true });

    try mpv.initialize();
    defer mpv.terminate_destroy();

    try mpv.loadfile(filename, .{});

    try mpv.request_log_messages(.Error);

    try mpv.observe_property(1, "fullscreen", .Flag);
    try mpv.observe_property(2, "time-pos", .INT64);

    while (true) {
        const event = try mpv.wait_event(10000);
        const event_id = event.event_id;
        switch (event_id) {
            .Shutdown => break,
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