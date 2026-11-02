CREATE TABLE IF NOT EXISTS GOLD_CLIENT_DATA.FCT_ATTRIBUTION
(
  user_id VARCHAR(255) COMMENT "User identification associated with the conversion",
  email VARCHAR(255) COMMENT "User email address",
  phone VARCHAR(255) COMMENT "User phone number",
  conversion_at TIMESTAMP COMMENT "Timestamp when the conversion happened",
  interaction_timestamp TIMESTAMP COMMENT "Timestamp when the attributed interaction occurred",
  interaction_type VARCHAR(255) COMMENT "Type of interaction, being either read, click, open, delivered, sent)",
  campaign_code VARCHAR(255) COMMENT "Code of the campaign that originated the conversion",
  channel VARCHAR(255) COMMENT "Channel through which the interaction occurred, being email or whatsapp",
  AUD_INS_DTTM DATETIME NOT NULL COMMENT 'Datetime when the record was inserted in the table. Created for audit purposes',
  AUD_UPD_DTTM DATETIME NOT NULL COMMENT 'Datetime when the record was updated in the table. Created for audit purposes',
	-- in a scenario where this table could be used for more than one conversion campaign, we use user_id and conversion_at
    -- as a key. If it's 100% chance that there will be no more conversions for the same user, we can simply use only user_id.
	PRIMARY KEY (user_id, conversion_at)
) 
COMMENT = "Attribution fact table using Weighted Last Touch logic within a 7-day lookback window."
