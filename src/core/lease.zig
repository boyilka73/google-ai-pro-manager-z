const std = @import("std");

/// In-memory lease primitive with fencing tokens. A durable multi-process
/// implementation must perform the same compare-and-swap atomically in DB.
pub const Lease = struct {
    owner: u128 = 0,
    expires_at_ms: u64 = 0,
    fencing_token: u64 = 0,

    pub const Error = error{ InvalidOwner, LeaseHeld, StaleFence, InvalidDuration, FenceExhausted };

    pub fn acquire(self: *Lease, owner: u128, now_ms: u64, duration_ms: u64) Error!u64 {
        if (owner == 0) return error.InvalidOwner;
        if (duration_ms == 0 or duration_ms > 24 * 60 * 60 * 1000) return error.InvalidDuration;
        if (self.owner != 0 and now_ms < self.expires_at_ms) return error.LeaseHeld;
        if (self.fencing_token == std.math.maxInt(u64)) return error.FenceExhausted;
        self.fencing_token += 1;
        self.owner = owner;
        self.expires_at_ms = std.math.add(u64, now_ms, duration_ms) catch return error.InvalidDuration;
        return self.fencing_token;
    }

    pub fn validate(self: *const Lease, owner: u128, token: u64, now_ms: u64) Error!void {
        if (self.owner != owner or owner == 0 or token != self.fencing_token or token == 0) return error.StaleFence;
        if (now_ms >= self.expires_at_ms) return error.StaleFence;
    }

    pub fn release(self: *Lease, owner: u128, token: u64) Error!void {
        if (self.owner != owner or token != self.fencing_token or token == 0) return error.StaleFence;
        self.owner = 0;
        self.expires_at_ms = 0;
    }
};

test "lease excludes concurrent owner and fencing token increases after expiry" {
    var lease = Lease{};
    const first = try lease.acquire(11, 100, 50);
    try std.testing.expectError(error.LeaseHeld, lease.acquire(22, 120, 50));
    try lease.validate(11, first, 120);
    const second = try lease.acquire(22, 150, 50);
    try std.testing.expect(second > first);
    try std.testing.expectError(error.StaleFence, lease.validate(11, first, 151));
}

test "expired lease cannot authorize work and invalid durations fail" {
    var lease = Lease{};
    const token = try lease.acquire(7, 100, 10);
    try std.testing.expectError(error.StaleFence, lease.validate(7, token, 110));
    try std.testing.expectError(error.InvalidDuration, lease.acquire(8, 110, 0));
}
