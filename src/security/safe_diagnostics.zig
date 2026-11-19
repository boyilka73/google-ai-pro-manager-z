/// Closed vocabulary for diagnostics. Never pass provider response bodies,
/// URLs with query strings, credentials, user input, or payment data to logs.
pub const ErrorCode = enum {
    configuration_invalid,
    database_unavailable,
    database_query_failed,
    provider_state_unverified,
    operation_conflict,
    operation_uncertain,
    user_action_required,
    internal_error,
};
pub const Severity = enum { info, warning, err };
pub const Event = struct { code: ErrorCode, severity: Severity };

/// Stable, non-sensitive label suitable for logs and support bundles.
pub fn label(code: ErrorCode) []const u8 {
    return switch (code) {
        .configuration_invalid => "configuration_invalid",
        .database_unavailable => "database_unavailable",
        .database_query_failed => "database_query_failed",
        .provider_state_unverified => "provider_state_unverified",
        .operation_conflict => "operation_conflict",
        .operation_uncertain => "operation_uncertain",
        .user_action_required => "user_action_required",
        .internal_error => "internal_error",
    };
}

test "diagnostic vocabulary is closed and stable" {
    const testing = @import("std").testing;
    try testing.expectEqualStrings("database_unavailable", label(.database_unavailable));
    try testing.expectEqualStrings("operation_uncertain", label(.operation_uncertain));
}
