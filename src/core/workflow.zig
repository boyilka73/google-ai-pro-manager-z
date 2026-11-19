const std = @import("std");
const price_guard = @import("../security/price_guard.zig");
const subscription = @import("subscription.zig");
const evidence = @import("evidence.zig");
const account = @import("account.zig");

pub const State = enum {
    idle,
    checking_offer,
    offer_unavailable,
    awaiting_user_review,
    waiting_for_official_checkout,
    checkout_blocked,
    awaiting_final_user_confirmation,
    awaiting_provider_verification,
    active_confirmed,
    failed,
    retry_ready,
    canceled,
};

pub const Workflow = struct {
    state: State = .idle,
    stage_index: u8 = 0,
    attempts_by_stage: [3]u8 = [_]u8{0} ** 3,
    last_price_decision: ?price_guard.Decision = null,

    pub const Error = error{
        InvalidTransition,
        StageOutOfOrder,
        RetryLimitReached,
        UnverifiedProvider,
        ProviderEvidenceMismatch,
        RetryRequiresReconciliation,
    };

    pub fn start(self: *Workflow, plan: *const subscription.Plan, stage_index: usize) Error!void {
        if (self.state != .idle and self.state != .retry_ready and self.state != .offer_unavailable) return error.InvalidTransition;
        if (stage_index >= plan.stages.len) return error.StageOutOfOrder;
        if (self.state == .retry_ready and stage_index != self.stage_index) return error.StageOutOfOrder;
        if (!plan.canAttemptStage(stage_index)) return error.StageOutOfOrder;
        if (plan.stages[stage_index].state == .active) return error.StageOutOfOrder;
        if (self.attempts_by_stage[stage_index] >= 3) return error.RetryLimitReached;
        self.stage_index = @intCast(stage_index);
        self.attempts_by_stage[stage_index] += 1;
        self.last_price_decision = null;
        self.state = .checking_offer;
    }

    pub fn recordOffer(self: *Workflow, available: bool) Error!void {
        if (self.state != .checking_offer) return error.InvalidTransition;
        self.state = if (available) .awaiting_user_review else .offer_unavailable;
    }

    pub fn approveOffer(self: *Workflow) Error!void {
        if (self.state != .awaiting_user_review) return error.InvalidTransition;
        self.state = .waiting_for_official_checkout;
    }

    pub fn inspectCheckout(self: *Workflow, snapshot: price_guard.Snapshot) Error!price_guard.Decision {
        if (self.state != .waiting_for_official_checkout) return error.InvalidTransition;
        const decision = price_guard.evaluate(snapshot);
        self.last_price_decision = decision;
        if (decision == .eligible_for_explicit_user_review) {
            self.state = .awaiting_final_user_confirmation;
        } else {
            self.state = .checkout_blocked;
        }
        return decision;
    }

    /// Records the user's explicit action outside the application. This method
    /// does not click Subscribe, submit payment data, or call a private API.
    pub fn confirmUserCompletedCheckout(self: *Workflow) Error!void {
        if (self.state != .awaiting_final_user_confirmation) return error.InvalidTransition;
        self.state = .awaiting_provider_verification;
    }

    pub fn recordProviderObservation(
        self: *Workflow,
        observation: evidence.ProviderObservation,
        expected_account: account.AccountId,
        now_unix: u64,
        plan: *subscription.Plan,
    ) Error!void {
        if (self.state != .awaiting_provider_verification) return error.InvalidTransition;
        observation.validate(expected_account, now_unix) catch return error.UnverifiedProvider;
        if (observation.stage_index != self.stage_index or self.stage_index >= plan.stages.len) return error.ProviderEvidenceMismatch;
        if (!observation.active) {
            self.state = .failed;
            return;
        }
        plan.stages[self.stage_index].state = .active;
        self.state = .active_confirmed;
    }

    /// A failed operation can be retried only after an explicit fresh provider
    /// read establishes that the previous attempt had no external effect.
    pub fn authorizeRetryAfterNoEffect(
        self: *Workflow,
        observation: evidence.ProviderObservation,
        expected_account: account.AccountId,
        now_unix: u64,
    ) Error!void {
        if (self.state != .failed) return error.InvalidTransition;
        observation.validate(expected_account, now_unix) catch return error.RetryRequiresReconciliation;
        if (observation.stage_index != self.stage_index or observation.active) return error.RetryRequiresReconciliation;
        self.state = .retry_ready;
    }

    pub fn cancel(self: *Workflow) void {
        self.state = .canceled;
    }
};

test "workflow requires order, user review, zero final total, and provider confirmation" {
    var plan = subscription.Plan{};
    var workflow = Workflow{};
    try std.testing.expectError(error.StageOutOfOrder, workflow.start(&plan, 1));
    try workflow.start(&plan, 0);
    try workflow.recordOffer(true);
    try workflow.approveOffer();
    const decision = try workflow.inspectCheckout(.{
        .source = .official_google_checkout,
        .final_amount_minor = 0,
        .currency = "USD",
        .explicit_final_total = true,
        .taxes_and_fees_included = true,
    });
    try std.testing.expectEqual(price_guard.Decision.eligible_for_explicit_user_review, decision);
    try workflow.confirmUserCompletedCheckout();
    const account_id = [_]u8{1} ** 16;
    const observation = evidence.ProviderObservation{
        .source = .official_user_visible_account_page,
        .account_id = account_id,
        .stage_index = 0,
        .active = true,
        .observed_at_unix = 1000,
        .fingerprint_hex = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    };
    try workflow.recordProviderObservation(observation, account_id, 1100, &plan);
    try std.testing.expectEqual(State.active_confirmed, workflow.state);
    try std.testing.expectEqual(@as(u32, 12), plan.confirmedMonths());
    try std.testing.expectError(error.InvalidTransition, workflow.start(&plan, 0));
}

test "nonzero checkout is blocked and cannot be confirmed" {
    var plan = subscription.Plan{};
    var workflow = Workflow{};
    try workflow.start(&plan, 0);
    try workflow.recordOffer(true);
    try workflow.approveOffer();
    _ = try workflow.inspectCheckout(.{
        .source = .official_google_checkout,
        .final_amount_minor = 1,
        .currency = "USD",
        .explicit_final_total = true,
        .taxes_and_fees_included = true,
    });
    try std.testing.expectEqual(State.checkout_blocked, workflow.state);
    try std.testing.expectError(error.InvalidTransition, workflow.confirmUserCompletedCheckout());
}

test "failed workflow cannot retry until provider confirms no effect" {
    var plan = subscription.Plan{};
    var workflow = Workflow{};
    try workflow.start(&plan, 0);
    try workflow.recordOffer(true);
    try workflow.approveOffer();
    _ = try workflow.inspectCheckout(.{
        .source = .official_google_checkout,
        .final_amount_minor = 0,
        .currency = "USD",
        .explicit_final_total = true,
        .taxes_and_fees_included = true,
    });
    try workflow.confirmUserCompletedCheckout();
    const id = [_]u8{2} ** 16;
    const observation = evidence.ProviderObservation{
        .source = .official_user_visible_account_page,
        .account_id = id,
        .stage_index = 0,
        .active = false,
        .observed_at_unix = 1000,
        .fingerprint_hex = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    };
    try workflow.recordProviderObservation(observation, id, 1100, &plan);
    try std.testing.expectError(error.InvalidTransition, workflow.start(&plan, 0));
    try std.testing.expectError(error.RetryRequiresReconciliation, workflow.authorizeRetryAfterNoEffect(observation, id, 1301));
    try workflow.authorizeRetryAfterNoEffect(observation, id, 1100);
    try workflow.start(&plan, 0);
}
