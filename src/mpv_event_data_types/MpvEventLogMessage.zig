const c = @import("../c.zig");
const std = @import("std");
const testing = std.testing;
const utils = @import("../utils.zig");

const Self = @This();

prefix: []const u8,
level: []const u8,
text: []const u8,
log_level: MpvLogLevel,

pub fn from(data_ptr: *anyopaque) Self {
    const log = utils.cast_event_data(data_ptr, c.mpv_event_log_message);
    return Self{
        .prefix = std.mem.sliceTo(log.prefix, 0),
        .level = std.mem.sliceTo(log.level, 0),
        .text = std.mem.sliceTo(log.text, 0),
        .log_level = MpvLogLevel.from(log.log_level),
    };
}

pub fn copy(self: Self, allocator: std.mem.Allocator) !Self {
    return .{
        .log_level = self.log_level,
        .level = try allocator.dupe(u8, self.level),
        .prefix = try allocator.dupe(u8, self.prefix),
        .text = try allocator.dupe(u8, self.text),
    };
}

pub fn free(self: Self, allocator: std.mem.Allocator) void {
    allocator.free(self.level);
    allocator.free(self.prefix);
    allocator.free(self.text);
}

pub const MpvLogLevel = enum(c.mpv_log_level) {
    None = c.MPV_LOG_LEVEL_NONE,
    Fatal = c.MPV_LOG_LEVEL_FATAL,
    Error = c.MPV_LOG_LEVEL_ERROR,
    Warn = c.MPV_LOG_LEVEL_WARN,
    Info = c.MPV_LOG_LEVEL_INFO,
    V = c.MPV_LOG_LEVEL_V,
    Debug = c.MPV_LOG_LEVEL_DEBUG,
    Trace = c.MPV_LOG_LEVEL_TRACE,

    pub fn from(level: c.mpv_log_level) MpvLogLevel {
        return @enumFromInt(level);
    }

    pub fn to_string(self: MpvLogLevel) []const u8 {
        return switch (self) {
            .None => "no",
            .Fatal => "fatal",
            .Error => "error",
            .Warn => "warn",
            .Info => "info",
            .V => "v",
            .Debug => "debug",
            .Trace => "trace",
        };
    }
};

test "MpvEventLogMessage from" {
    var log_event_data = c.mpv_event_log_message{
        .log_level = c.MPV_LOG_LEVEL_V,
        .level = "v",
        .prefix = "simple",
        .text = "this is a test log",
    };
    const z_log = Self.from(&log_event_data);

    try testing.expect(z_log.log_level == .V);
    try testing.expect(std.mem.eql(u8, z_log.level, "v"));
    try testing.expect(std.mem.eql(u8, z_log.prefix, "simple"));
    try testing.expect(std.mem.eql(u8, z_log.text, "this is a test log"));
}

test "MpvEventLogMessage copy" {
    const allocator = testing.allocator;

    const log = Self {
        .log_level = .Debug,
        .level = "debug",
        .prefix = "hey",
        .text = "this is the log",
    };
    const log_copy = try log.copy(allocator);
    defer log_copy.free(allocator);

    try testing.expect(log_copy.log_level == .Debug);
    try testing.expectEqualStrings("debug", log_copy.level);
    try testing.expectEqualStrings("hey", log_copy.prefix);
    try testing.expectEqualStrings("this is the log", log_copy.text);
}


