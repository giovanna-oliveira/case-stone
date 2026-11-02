CREATE TABLE IF NOT EXISTS SILVER_CLIENT_DATA.BT_CRM_USER_BASE
(
    user_id VARCHAR(255) PRIMARY KEY COMMENT 'User identification, formatted as u_XXXX',
    email VARCHAR(255) COMMENT 'User email, formatted as lower case and trimmed',
    phone VARCHAR(50) COMMENT 'User phone number, formatted with only numbers',
    conversion_at TIMESTAMP NULL COMMENT 'Timestamp when conversion happened, set in the America/Sao Paulo timezone',
    AUD_INS_DTTM DATETIME NOT NULL COMMENT 'Datetime when the record was inserted in the table. Created for audit purposes',
    AUD_UPD_DTTM DATETIME NOT NULL COMMENT 'Datetime when the record was updated in the table. Created for audit purposes'
)
COMMENT='Table containing User Data. Source BRONZE_CLIENT_DATA.RAW_CRM_USER_BASE';