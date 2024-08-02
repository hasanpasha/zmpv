const std = @import("std");
const c = @import("c.zig");
const mpv_error = @import("mpv_error.zig");
const MpvError = mpv_error.MpvError;
const AllocatorError = std.mem.Allocator.Error;
const MpvEventEndFile = @import("mpv_event_data_types//MpvEventEndFile.zig");
const MpvEventStartFile = @import("mpv_event_data_types//MpvEventStartFile.zig");
const MpvEventProperty = @import("mpv_event_data_types//MpvEventProperty.zig");
const MpvEventLogMessage = @import("mpv_event_data_types//MpvEventLogMessage.zig");
const MpvEventClientMessage = @import("mpv_event_data_types//MpvEventClientMessage.zig");
const MpvEventCommand = @import("mpv_event_data_types//MpvEventCommand.zig");
const MpvEventHook = @import("mpv_event_data_types//MpvEventHook.zig");
const MpvEventId = @import("mpv_event_id.zig").MpvEventId;
const testing = std.testing;

const Self = @This();

event_id: MpvEventId,
event_error: MpvError,
data: MpvEventData,
reply_userdata: u64,

pub fn from(event: *c.mpv_event) Self {
    const event_id = MpvEventId.from(event.event_id);

    return Self{
        .event_id = event_id,
        .event_error = mpv_error.from_mpv_c_error(event.@"error"),
        .data = switch (event_id) {
            .EndFile => MpvEventData{
                .EndFile = MpvEventEndFile.from(event.data.?),
            },
            .StartFile => MpvEventData{
                .StartFile = MpvEventStartFile.from(event.data.?),
            },
            .PropertyChange => MpvEventData{
                .PropertyChange = MpvEventProperty.from(event.data.?),
            },
            .LogMessage => MpvEventData{
                .LogMessage = MpvEventLogMessage.from(event.data.?),
            },
            .ClientMessage => MpvEventData{
                .ClientMessage = MpvEventClientMessage.from(event.data.?),
            },
            .CommandReply => MpvEventData{
                .CommandReply = MpvEventCommand.from(event.data.?),
            },
            .Hook => MpvEventData{
                .Hook = MpvEventHook.from(event.data.?),
            },
            else => MpvEventData{ .None = {} },
        },
        .reply_userdata = event.reply_userdata,
    };
}

pub fn copy(self: Self, allocator: std.mem.Allocator) AllocatorError!Self {
    return Self{
        .event_id = self.event_id,
        .event_error = self.event_error,
        .reply_userdata = self.reply_userdata,
        .data = try self.data.copy(allocator),
    };
}

pub fn free(self: Self, allocator: std.mem.Allocator) void {
    self.data.free(allocator);
}

pub const MpvEventData = union(enum) {
    None: void,
    LogMessage: MpvEventLogMessage,
    GetPropertyReply: MpvEventProperty,
    CommandReply: MpvEventCommand,
    StartFile: MpvEventStartFile,
    EndFile: MpvEventEndFile,
    ClientMessage: MpvEventClientMessage,
    PropertyChange: MpvEventProperty,
    Hook: MpvEventHook,

    pub fn copy(self: MpvEventData, allocator: std.mem.Allocator) AllocatorError!MpvEventData {
        return switch (self) {
            .LogMessage => |log| .{ .LogMessage = try log.copy(allocator) },
            .GetPropertyReply => |property| .{ .GetPropertyReply = try property.copy(allocator) },
            .CommandReply => |reply| .{ .CommandReply = try reply.copy(allocator) },
            .ClientMessage => |message| .{ .ClientMessage = try message.copy(allocator) },
            .PropertyChange => |property| .{ .PropertyChange = try property.copy(allocator) },
            .Hook => |hook| .{ .Hook = try hook.copy(allocator) },
            else => self,
        };
    }

    pub fn free(self: MpvEventData, allocator: std.mem.Allocator) void {
        switch (self) {
            .LogMessage => |log| log.free(allocator),
            .GetPropertyReply, .PropertyChange => |property| property.free(allocator),
            .CommandReply => |command_reply| command_reply.free(allocator),
            .ClientMessage => |message| message.free(allocator),
            .Hook => |hook| hook.free(allocator),
            else => {},
        }
    }
};

test "MpvEvent from" {
    var log_event_data = c.mpv_event_log_message{
        .log_level = c.MPV_LOG_LEVEL_V,
        .level = "v",
        .prefix = "simple",
        .text = "this is a test log",
    };
    var log_event = c.mpv_event{
        .@"error" = c.MPV_ERROR_SUCCESS,
        .data = &log_event_data,
        .event_id = c.MPV_EVENT_LOG_MESSAGE,
        .reply_userdata = 0,
    };
    const z_log = Self.from(&log_event);
    const z_data = z_log.data.LogMessage;

    try testing.expect(z_log.event_id == .LogMessage);
    try testing.expect(z_log.event_error == MpvError.Success);
    try testing.expect(z_log.reply_userdata == 0);
    try testing.expect(z_data.log_level == .V);
    try testing.expect(std.mem.eql(u8, z_data.level, "v"));
    try testing.expect(std.mem.eql(u8, z_data.prefix, "simple"));
    try testing.expect(std.mem.eql(u8, z_data.text, "this is a test log"));
}

test "MpvEvent copy" {
    const allocator = testing.allocator;

    const event = Self {
        .event_id = .LogMessage,
        .event_error = MpvError.Success,
        .reply_userdata = 0,
        .data = .{ .LogMessage = .{
            .log_level = .V,
            .level = "v",
            .prefix = "something",
            .text = "log text",
        }},
    };

    const event_copy = try event.copy(allocator);
    defer event_copy.free(allocator);

    const log_copy = event_copy.data.LogMessage;
    try testing.expectEqualStrings("v", log_copy.level);
    try testing.expectEqualStrings("something", log_copy.prefix);
    try testing.expectStringEndsWith("log text", log_copy.text);
}
