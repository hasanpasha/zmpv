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