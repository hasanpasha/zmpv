const c = @cImport({
    @cInclude("mpv/client.h");
});

pub const MpvError = error{
    Success,
    EventQueueFull,
    NoMem,
    Uninitialized,
    InvalidParameter,
    OptionNotFound,
    OptionFormat,
    OptionError,
    PropertyNotFound,
    PropertyFormat,
    PropertyUnavailable,
    PropertyError,
    Command,
    LoadingFailed,
    AoInitFailed,
    VoInitFailed,
    NothingToPlay,
    UnknownFormat,
    Unsupported,
    NotImplemented,
    Generic,
};

pub fn from_mpv_c_error(errorCode: c_int) MpvError {
    return switch (errorCode) {
        c.MPV_ERROR_SUCCESS => MpvError.Success,
        c.MPV_ERROR_EVENT_QUEUE_FULL => MpvError.EventQueueFull,
        c.MPV_ERROR_NOMEM => MpvError.NoMem,
        c.MPV_ERROR_UNINITIALIZED => MpvError.Uninitialized,
        c.MPV_ERROR_INVALID_PARAMETER => MpvError.InvalidParameter,
        c.MPV_ERROR_OPTION_NOT_FOUND => MpvError.OptionNotFound,
        c.MPV_ERROR_OPTION_FORMAT => MpvError.OptionFormat,
        c.MPV_ERROR_OPTION_ERROR => MpvError.OptionError,
        c.MPV_ERROR_PROPERTY_NOT_FOUND => MpvError.PropertyNotFound,
        c.MPV_ERROR_PROPERTY_FORMAT => MpvError.PropertyFormat,
        c.MPV_ERROR_PROPERTY_UNAVAILABLE => MpvError.PropertyUnavailable,
        c.MPV_ERROR_PROPERTY_ERROR => MpvError.PropertyError,
        c.MPV_ERROR_COMMAND => MpvError.Command,
        c.MPV_ERROR_LOADING_FAILED => MpvError.LoadingFailed,
        c.MPV_ERROR_AO_INIT_FAILED => MpvError.AoInitFailed,
        c.MPV_ERROR_VO_INIT_FAILED => MpvError.VoInitFailed,
        c.MPV_ERROR_NOTHING_TO_PLAY => MpvError.NothingToPlay,
        c.MPV_ERROR_UNKNOWN_FORMAT => MpvError.UnknownFormat,
        c.MPV_ERROR_UNSUPPORTED => MpvError.Unsupported,
        c.MPV_ERROR_NOT_IMPLEMENTED => MpvError.NotImplemented,
        c.MPV_ERROR_GENERIC => MpvError.Generic,
        else => @panic("Unknown MPV error code"),
    };
}
