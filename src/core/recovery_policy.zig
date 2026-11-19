/// Pure recovery policy for operations whose external side effect may have
/// completed before a process or network failure. This module never performs
/// retries; it only returns a decision for the coordinator to enforce.
pub const OperationState = enum { pending, running, succeeded, failed, uncertain, reconciled };
pub const ProviderObservation = enum { unknown, effect_present, effect_absent };
pub const Decision = enum {
    mark_uncertain,
    wait_for_provider_read,
    mark_reconciled,
    allow_new_attempt,
    do_not_retry_terminal,
    manual_review,
};

pub fn decide(state: OperationState, observation: ProviderObservation) Decision {
    return switch (state) {
        .pending, .running => .mark_uncertain,
        .succeeded, .reconciled => .do_not_retry_terminal,
        .failed => .manual_review,
        .uncertain => switch (observation) {
            .unknown => .wait_for_provider_read,
            .effect_present => .mark_reconciled,
            .effect_absent => .allow_new_attempt,
        },
    };
}

test "interrupted operations become uncertain" {
    const testing = @import("std").testing;
    try testing.expectEqual(Decision.mark_uncertain, decide(.pending, .unknown));
    try testing.expectEqual(Decision.mark_uncertain, decide(.running, .effect_absent));
}
test "uncertain operations require provider observation" {
    const testing = @import("std").testing;
    try testing.expectEqual(Decision.wait_for_provider_read, decide(.uncertain, .unknown));
    try testing.expectEqual(Decision.mark_reconciled, decide(.uncertain, .effect_present));
    try testing.expectEqual(Decision.allow_new_attempt, decide(.uncertain, .effect_absent));
}
test "terminal operations are never replayed" {
    const testing = @import("std").testing;
    try testing.expectEqual(Decision.do_not_retry_terminal, decide(.succeeded, .effect_absent));
    try testing.expectEqual(Decision.manual_review, decide(.failed, .effect_absent));
}
