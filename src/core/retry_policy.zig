const std = @import("std");

/// Retry decisions are intentionally conservative. Only failures known to have
/// happened before an external side effect may be retried automatically.
pub const FailureClass = enum {
    transient_before_effect,
    rate_limited_before_effect,
    permanent,
    effect_may_have_occurred,
};

pub const Decision = enum { retry, retry_after_delay, stop, reconcile_first };

pub const Input = struct {
    failure: FailureClass,
    attempt: u8,
    max_attempts: u8 = 3,
    retry_after_seconds: ?u32 = null,
};

pub const Output = struct {
    decision: Decision,
    delay_seconds: u32 = 0,
};

pub fn evaluate(input: Input) Output {
    if (input.failure == .effect_may_have_occurred) return .{ .decision = .reconcile_first };
    if (input.failure == .permanent) return .{ .decision = .stop };
    if (input.max_attempts == 0 or input.attempt >= input.max_attempts) return .{ .decision = .stop };
    if (input.failure == .rate_limited_before_effect) {
        const requested = input.retry_after_seconds orelse 1;
        return .{ .decision = .retry_after_delay, .delay_seconds = @min(requested, 3600) };
    }
    const shift: u5 = @min(input.attempt, 8);
    const delay: u32 = @min(@as(u32, 1) << shift, 300);
    return .{ .decision = .retry, .delay_seconds = delay };
}

test "uncertain external effects always require reconciliation" {
    const result = evaluate(.{ .failure = .effect_may_have_occurred, .attempt = 0 });
    try std.testing.expectEqual(Decision.reconcile_first, result.decision);
}

test "permanent and exhausted failures stop" {
    try std.testing.expectEqual(Decision.stop, evaluate(.{ .failure = .permanent, .attempt = 0 }).decision);
    try std.testing.expectEqual(Decision.stop, evaluate(.{ .failure = .transient_before_effect, .attempt = 3 }).decision);
}

test "retry delay is bounded" {
    const backoff = evaluate(.{ .failure = .transient_before_effect, .attempt = 2 });
    try std.testing.expectEqual(Decision.retry, backoff.decision);
    try std.testing.expectEqual(@as(u32, 4), backoff.delay_seconds);
    const limited = evaluate(.{ .failure = .rate_limited_before_effect, .attempt = 0, .retry_after_seconds = 99999 });
    try std.testing.expectEqual(@as(u32, 3600), limited.delay_seconds);
}
