pub fn cast_event_data(data_ptr: ?*anyopaque, return_data: type) return_data {
    const casted_data: *return_data = @ptrCast(@alignCast(data_ptr));
    return casted_data.*;
}
