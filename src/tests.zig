comptime {
    _ = @import("./Mpv.zig");
    _ = @import("./mpv_format.zig");
    _ = @import("./mpv_node.zig");
    _ = @import("./utils.zig");
    _ = @import("./mpv_property_data.zig");
    _ = @import("./mpv_event_id.zig");
    _ = @import("./MpvEvent.zig");
    _ = @import("./mpv_event_data_types/MpvEventClientMessage.zig");
    _ = @import("./mpv_event_data_types/MpvEventCommand.zig");
    _ = @import("./mpv_event_data_types/MpvEventEndFile.zig");
    _ = @import("./mpv_event_data_types/MpvEventHook.zig");
    _ = @import("./mpv_event_data_types/MpvEventLogMessage.zig");
    _ = @import("./mpv_event_data_types/MpvEventProperty.zig");
    _ = @import("./mpv_event_data_types/MpvEventStartFile.zig");
}
