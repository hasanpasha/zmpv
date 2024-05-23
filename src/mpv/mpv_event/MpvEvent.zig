const mpv_error = @import("../errors/mpv_error.zig");
const MpvError = mpv_error.MpvError;
const MpvEventEndFile = @import("./MpvEventEndFile.zig");
const MpvEventStartFile = @import("./MpvEventStartFile.zig");
const MpvEventProperty = @import("./MpvEventProperty.zig");
const MpvEventLogMessage = @import("./MpvEventLogMessage.zig");
const MpvEventClientMessage = @import("./MpvEventClientMessage.zig");
const MpvEventCommand = @import("./MpvEventCommand.zig");
const MpvEventHook = @import("./MpvEventHook.zig");
const MpvEventId = @import("./mpv_event_id.zig").MpvEventId;
const c = @import("../c.zig");
const std = @import("std");
const testing = std.testing;

const Self = @This();

event_id: MpvEventId,
event_error: MpvError,
data: MpvEventData,
reply_userdata: u64,
allocator: std.mem.Allocator,

pub fn from(c_event: [*c]c.struct_mpv_event, allocator: std.mem.Allocator) !Self {
    const event: *c.mpv_event = @ptrCast(c_event);

    const event_id: MpvEventId = @enumFromInt(event.event_id);

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
                .PropertyChange = try MpvEventProperty.from(event.data.?, allocator),
            },
            .LogMessage => MpvEventData{
                .LogMessage = MpvEventLogMessage.from(event.data.?),
            },
            .ClientMessage => MpvEventData{
                .ClientMessage = try MpvEventClientMessage.from(event.data.?, allocator),
            },
            .CommandReply => MpvEventData{
                .CommandReply = try MpvEventCommand.from(event.data.?, allocator),
            },
            .Hook => MpvEventData{
                .Hook = MpvEventHook.from(event.data.?),
            },
            else => MpvEventData{ .None = {} },
        },
        .reply_userdata = event.reply_userdata,
        .allocator = allocator,
    };
}

pub fn free(self: Self) void {
    self.data.free();
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

    pub fn free(self: MpvEventData) void {
        switch (self) {
            .GetPropertyReply, .PropertyChange => |property| {
                property.free();
            },
            .CommandReply => |reply| {
                reply.free();
            },
            .ClientMessage => |message| {
                message.free();
            },
            else => {},
        }
    }
};

test "MpvEvent from" {
    const allocator = testing.allocator;
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
    const z_log = try Self.from(&log_event, allocator);
    const z_data = z_log.data.LogMessage;
    defer Self.free(z_log);

    try testing.expect(z_log.event_id == .LogMessage);
    try testing.expect(z_log.event_error == MpvError.Success);
    try testing.expect(z_log.reply_userdata == 0);
    try testing.expect(z_data.log_level == .V);
    try testing.expect(std.mem.eql(u8, z_data.level, "v"));
    try testing.expect(std.mem.eql(u8, z_data.prefix, "simple"));
    try testing.expect(std.mem.eql(u8, z_data.text, "this is a test log"));
}
