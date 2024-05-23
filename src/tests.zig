comptime {
    _ = @import("./mpv/Mpv.zig");
    _ = @import("./mpv/mpv_format.zig");
    _ = @import("./mpv/MpvNode.zig");
    _ = @import("./mpv/utils.zig");
    _ = @import("./mpv/mpv_property_data.zig");
    _ = @import("./mpv/mpv_event/mpv_event_id.zig");
    _ = @import("./mpv/mpv_event/MpvEvent.zig");
    _ = @import("./mpv/mpv_event/MpvEventClientMessage.zig");
    _ = @import("./mpv/mpv_event/MpvEventCommand.zig");
    _ = @import("./mpv/mpv_event/MpvEventEndFile.zig");
    _ = @import("./mpv/mpv_event/MpvEventHook.zig");
    _ = @import("./mpv/mpv_event/MpvEventLogMessage.zig");
    _ = @import("./mpv/mpv_event/MpvEventProperty.zig");
    _ = @import("./mpv/mpv_event/MpvEventStartFile.zig");
}
