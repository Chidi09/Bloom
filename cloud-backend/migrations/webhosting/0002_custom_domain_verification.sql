-- Migration: 0002_custom_domain_verification.sql
-- Domain: webhosting
-- Purpose: Add verification_token and failure_reason to webhosting_customdomain (Phase 12)

-- up
ALTER TABLE webhosting_customdomain ADD COLUMN verification_token VARCHAR(64) NOT NULL DEFAULT '';
ALTER TABLE webhosting_customdomain ADD COLUMN failure_reason TEXT;

-- down
ALTER TABLE webhosting_customdomain DROP COLUMN failure_reason;
ALTER TABLE webhosting_customdomain DROP COLUMN verification_token;
