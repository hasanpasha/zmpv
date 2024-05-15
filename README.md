# zmpv
Work in progress.

## Todo
- [ ] Finish wrapping all exported mpv functions.
    - [ ] `mpv/client.h`
    - [ ] `mpv/render.h`
    - [ ] `mpv/render_gl.h`
    - [ ] `mpv/stream_cb.h`
- [ ] Fix memory leaks.
- [ ] write more tests.
- [ ] Add another structs that contains helper functions.
- [ ] Add Examples.
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

pub fn main() !void {
    const mpv = try zmpv.Mpv.new(std.heap.page_allocator);

    try mpv.initialize();
    defer mpv.terminate_destroy();

    try mpv.loadfile("sample.mp4", .{});

    try mpv.request_log_messages(.V);

    while (true) {
        const event = try mpv.wait_event(10000);
        const event_id = event.event_id;
        switch (event_id) {
            .Shutdown => break,
            .LogMessage => {
                const log = event.data.LogMessage;
                std.log.debug("[{s}] \"{s}\"", .{ log.prefix, log.text });
            },
            else => {},
        }
    }
}
```