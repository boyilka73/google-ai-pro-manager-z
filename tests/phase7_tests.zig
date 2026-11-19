const recovery = @import("../src/core/recovery_policy.zig");
const diagnostics = @import("../src/security/safe_diagnostics.zig");

test "Phase 7 modules are included" {
    _ = recovery;
    _ = diagnostics;
}
