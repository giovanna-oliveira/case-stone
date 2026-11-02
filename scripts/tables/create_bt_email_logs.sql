CREATE TABLE IF NOT EXISTS SILVER_CLIENT_DATA.BT_EMAIL_LOGS (
  event_id VARCHAR(255) PRIMARY KEY COMMENT "Event identification, formatted as evt_XXXXXXXX",
  user_id VARCHAR(255) COMMENT  "User identification associated with this e-mail. Source: CRM",
  user_email VARCHAR(255) COMMENT "User email that received the event, formatted as lower case and trimmed",
  event_timestamp TIMESTAMP COMMENT "Timestamp when event was created, set in the America/Sao Paulo timezone",
  event_type VARCHAR(255) COMMENT "Event type, being either sent, open or click",
  campaign_code VARCHAR(255) COMMENT "Code from the campaign that originated the email",
  AUD_INS_DTTM DATETIME NOT NULL COMMENT 'Datetime when the record was inserted in the table. Created for audit purposes',
  AUD_UPD_DTTM DATETIME NOT NULL COMMENT 'Datetime when the record was updated in the table. Created for audit purposes'
  )
COMMENT="Table containing e-mails events for each e-mail sent under a campaign. Source BRONZE_CLIENT_DATA.RAW_SFMC_EMAIL_LOGS"