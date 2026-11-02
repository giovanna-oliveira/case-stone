CREATE TABLE IF NOT EXISTS SILVER_CLIENT_DATA.BT_WHATSAPP_PROVIDER 
(
  message_id VARCHAR(255) PRIMARY KEY COMMENT "Message identification, formatted as wa_XXXXXXXX",
  user_id VARCHAR(255) COMMENT  "User identification associated with this phone number. Source: CRM",
  phone VARCHAR(255) COMMENT "Phone number that received the message, formatted with only numbers",
  sent_at TIMESTAMP COMMENT "Timestamp when message was sent, set in the America/Sao Paulo timezone",
  status VARCHAR(255) COMMENT "Message status, being either delivered, failed or read",
  campaign_code VARCHAR(255) COMMENT "Code from the campaign that originated the message",
  AUD_INS_DTTM DATETIME NOT NULL COMMENT 'Datetime when the record was inserted in the table. Created for audit purposes',
    AUD_UPD_DTTM DATETIME NOT NULL COMMENT 'Datetime when the record was updated in the table. Created for audit purposes'
  )
COMMENT="Table containing Whatsapp Message status for each message sent under a campaign. Source BRONZE_CLIENT_DATA.RAW_WHATSAPP_PROVIDER"