-- up
ALTER TABLE billing_invoice ADD COLUMN line_items TEXT NOT NULL DEFAULT '[]';

-- down
ALTER TABLE billing_invoice DROP COLUMN line_items;
