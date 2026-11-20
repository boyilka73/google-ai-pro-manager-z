-- Google AI Pro Manager Z
-- Initial metadata-only schema for SurrealDB 4.0.1 / SurrealKV.
-- Apply only to a fresh development database until migration tooling and
-- live integration tests are committed. No credentials or payment secrets.

DEFINE TABLE IF NOT EXISTS account SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS account_key ON account TYPE string;
DEFINE FIELD IF NOT EXISTS label ON account TYPE string;
DEFINE FIELD IF NOT EXISTS created_at ON account TYPE datetime;
DEFINE FIELD IF NOT EXISTS updated_at ON account TYPE datetime;
DEFINE INDEX IF NOT EXISTS account_key_unique ON account FIELDS account_key UNIQUE;

DEFINE TABLE IF NOT EXISTS subscription_stage SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS account_key ON subscription_stage TYPE string;
DEFINE FIELD IF NOT EXISTS stage_index ON subscription_stage TYPE int ASSERT $value >= 0 AND $value <= 2;
DEFINE FIELD IF NOT EXISTS months ON subscription_stage TYPE int ASSERT $value IN [6, 12];
DEFINE FIELD IF NOT EXISTS state ON subscription_stage TYPE string ASSERT $value IN ['pending', 'active', 'expired', 'unknown'];
DEFINE FIELD IF NOT EXISTS valid_from ON subscription_stage TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS valid_until ON subscription_stage TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS observed_at ON subscription_stage TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at ON subscription_stage TYPE datetime;
DEFINE FIELD IF NOT EXISTS updated_at ON subscription_stage TYPE datetime;
DEFINE INDEX IF NOT EXISTS subscription_stage_account_stage_unique ON subscription_stage FIELDS account_key, stage_index UNIQUE;

DEFINE TABLE IF NOT EXISTS workflow_operation SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS operation_id ON workflow_operation TYPE string;
DEFINE FIELD IF NOT EXISTS account_key ON workflow_operation TYPE string;
DEFINE FIELD IF NOT EXISTS stage_index ON workflow_operation TYPE int ASSERT $value >= 0 AND $value <= 2;
DEFINE FIELD IF NOT EXISTS state ON workflow_operation TYPE string ASSERT $value IN ['pending', 'running', 'succeeded', 'failed', 'uncertain', 'reconciled'];
DEFINE FIELD IF NOT EXISTS attempt ON workflow_operation TYPE int ASSERT $value >= 0;
DEFINE FIELD IF NOT EXISTS idempotency_key ON workflow_operation TYPE string;
DEFINE FIELD IF NOT EXISTS started_at ON workflow_operation TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS completed_at ON workflow_operation TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at ON workflow_operation TYPE datetime;
DEFINE FIELD IF NOT EXISTS updated_at ON workflow_operation TYPE datetime;
DEFINE INDEX IF NOT EXISTS workflow_operation_id_unique ON workflow_operation FIELDS operation_id UNIQUE;
DEFINE INDEX IF NOT EXISTS workflow_operation_idempotency_unique ON workflow_operation FIELDS account_key, idempotency_key UNIQUE;

DEFINE TABLE IF NOT EXISTS provider_observation SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS observation_id ON provider_observation TYPE string;
DEFINE FIELD IF NOT EXISTS account_key ON provider_observation TYPE string;
DEFINE FIELD IF NOT EXISTS stage_index ON provider_observation TYPE int ASSERT $value >= 0 AND $value <= 2;
DEFINE FIELD IF NOT EXISTS source ON provider_observation TYPE string ASSERT $value IN ['official_user_visible_account_page'];
DEFINE FIELD IF NOT EXISTS active ON provider_observation TYPE bool;
DEFINE FIELD IF NOT EXISTS observed_at ON provider_observation TYPE datetime;
DEFINE FIELD IF NOT EXISTS valid_from ON provider_observation TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS valid_until ON provider_observation TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS evidence_fingerprint ON provider_observation TYPE string ASSERT string::len($value) = 64;
DEFINE FIELD IF NOT EXISTS created_at ON provider_observation TYPE datetime;
DEFINE INDEX IF NOT EXISTS provider_observation_id_unique ON provider_observation FIELDS observation_id UNIQUE;
DEFINE INDEX IF NOT EXISTS provider_observation_account_stage_time ON provider_observation FIELDS account_key, stage_index, observed_at;

DEFINE TABLE IF NOT EXISTS account_lease SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS account_key ON account_lease TYPE string;
DEFINE FIELD IF NOT EXISTS owner_id ON account_lease TYPE string;
DEFINE FIELD IF NOT EXISTS fencing_token ON account_lease TYPE int ASSERT $value > 0;
DEFINE FIELD IF NOT EXISTS acquired_at ON account_lease TYPE datetime;
DEFINE FIELD IF NOT EXISTS expires_at ON account_lease TYPE datetime;
DEFINE FIELD IF NOT EXISTS updated_at ON account_lease TYPE datetime;
DEFINE INDEX IF NOT EXISTS account_lease_account_key_unique ON account_lease FIELDS account_key UNIQUE;

DEFINE TABLE IF NOT EXISTS audit_event SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS event_id ON audit_event TYPE string;
DEFINE FIELD IF NOT EXISTS account_key ON audit_event TYPE string;
DEFINE FIELD IF NOT EXISTS operation_id ON audit_event TYPE option<string>;
DEFINE FIELD IF NOT EXISTS event_type ON audit_event TYPE string;
DEFINE FIELD IF NOT EXISTS occurred_at ON audit_event TYPE datetime;
DEFINE FIELD IF NOT EXISTS actor_id ON audit_event TYPE string;
DEFINE FIELD IF NOT EXISTS safe_details ON audit_event TYPE object;
DEFINE INDEX IF NOT EXISTS audit_event_id_unique ON audit_event FIELDS event_id UNIQUE;
DEFINE INDEX IF NOT EXISTS audit_event_account_time ON audit_event FIELDS account_key, occurred_at;
