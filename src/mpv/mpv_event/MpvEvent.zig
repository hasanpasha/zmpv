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
