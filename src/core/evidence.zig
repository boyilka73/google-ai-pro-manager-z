const std = @import("std");
const account = @import("account.zig");

pub const Source = enum { unknown, official_user_visible_account_page };
pub const max_age_seconds: u64 = 300;

/// A normalized observation, not cryptographic proof of origin. The trusted
/// adapter must construct it only after a user-visible provider page was
/// inspected. Core validation checks identity, freshness and completeness.
pub const ProviderObservation = struct {
    source: Source = .unknown,
    account_id: account.AccountId,
    stage_index: u8,
    active: bool,
    observed_at_unix: u64,
    fingerprint_hex: []const u8,

    pub const Error = error{
        UntrustedSource,
        AccountMismatch,
        InvalidStage,
        MissingFingerprint,
        InvalidFingerprint,
        ObservationFromFuture,
        StaleObservation,
    };

    pub fn validate(self: ProviderObservation, expected_account: account.AccountId, now_unix: u64) Error!void {
        if (self.source != .official_user_visible_account_page) return error.UntrustedSource;
        if (!std.mem.eql(u8, self.account_id[0..], expected_account[0..])) return error.AccountMismatch;
        if (self.stage_index > 2) return error.InvalidStage;
        if (self.fingerprint_hex.len != 64) return error.MissingFingerprint;
        for (self.fingerprint_hex) |c| {
            if (!((c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F'))) return error.InvalidFingerprint;
        }
        if (self.observed_at_unix > now_unix) return error.ObservationFromFuture;
        if (now_unix - self.observed_at_unix > max_age_seconds) return error.StaleObservation;
    }
};

test "provider observations require trusted source, matching account, freshness and fingerprint" {
    const id = [_]u8{9} ** 16;
    const good = ProviderObservation{
        .source = .official_user_visible_account_page,
        .account_id = id,
        .stage_index = 0,
        .active = true,
        .observed_at_unix = 1000,
        .fingerprint_hex = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    };
    try good.validate(id, 1100);
    try std.testing.expectError(error.AccountMismatch, good.validate([_]u8{8} ** 16, 1100));
    try std.testing.expectError(error.StaleObservation, good.validate(id, 1301));
    var bad = good;
    bad.source = .unknown;
    try std.testing.expectError(error.UntrustedSource, bad.validate(id, 1100));
    bad = good;
    bad.fingerprint_hex = "not-a-fingerprint";
    try std.testing.expectError(error.MissingFingerprint, bad.validate(id, 1100));
}
