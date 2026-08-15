-- up
ALTER TABLE billing_plan ADD COLUMN price_minor BIGINT NOT NULL DEFAULT 0;
ALTER TABLE billing_plan ADD COLUMN currency VARCHAR(3) NOT NULL DEFAULT 'USD';

UPDATE billing_plan SET price_minor = 0, currency = 'USD' WHERE name = 'free';
UPDATE billing_plan SET price_minor = 2900, currency = 'USD' WHERE name = 'pro';
UPDATE billing_plan SET price_minor = 19900, currency = 'USD' WHERE name = 'enterprise';

ALTER TABLE billing_subscription ADD COLUMN pending_plan_id BIGINT REFERENCES billing_plan(id) ON DELETE SET NULL;

-- down
ALTER TABLE billing_subscription DROP COLUMN pending_plan_id;
ALTER TABLE billing_plan DROP COLUMN currency;
ALTER TABLE billing_plan DROP COLUMN price_minor;
