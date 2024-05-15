const std = @import("std");
const MpvNode = @import("./mpv_node.zig").MpvNode;

pub const MpvNodehashMap = std.StringHashMap(MpvNode);
