-- Migration: 0003_add_preview_image_url.sql
-- Domain: deployments
-- Purpose: Store a screenshot/preview image URL for the dashboard's device-frame deployment preview.
--
-- Nullable because nothing captures screenshots automatically yet; this column is a landing
-- spot for a future capture pipeline (or manual upload) and degrades to a placeholder in the
-- UI until populated.

-- up
ALTER TABLE deployments_deployment ADD COLUMN preview_image_url VARCHAR(500);

-- down
ALTER TABLE deployments_deployment DROP COLUMN IF EXISTS preview_image_url;
