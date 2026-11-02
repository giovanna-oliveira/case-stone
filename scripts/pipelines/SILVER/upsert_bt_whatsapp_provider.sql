-- inserts new records
INSERT INTO SILVER_CLIENT_DATA.BT_WHATSAPP_PROVIDER (
    message_id,
    user_id,
    phone,
    sent_at,
    status,
    campaign_code,
    AUD_INS_DTTM,
    AUD_UPD_DTTM
)
SELECT 
	message_id,
    user_id,
    phone_clean,
    sent_at_brt,
    status,
    campaign_code,
    AUD_INS_DTTM,
    AUD_UPD_DTTM
FROM (
	SELECT
		  r.message_id,
		  c.user_id,
		  CAST(r.phone_clean AS CHAR) AS phone_clean,
		  r.sent_at_brt, 
		  r.status,
		  -- this will delimit the text based on - and will return the second part of the text
		  TRIM(REGEXP_SUBSTR(r.campaign_tag, '[^-]+', 1, 2)) AS campaign_code,
		  NOW() AS AUD_INS_DTTM,
		  NOW() AS AUD_UPD_DTTM
	FROM BRONZE_CLIENT_DATA.RAW_WHATSAPP_PROVIDER r

	LEFT JOIN SILVER_CLIENT_DATA.BT_CRM_USER_BASE c
	ON CAST(r.phone_clean AS CHAR) = c.phone
		-- after first run, use this filter
		-- WHERE DATE(sent_at_brt) >= CURRENT_DATE() - INTERVAL 1 DAY
) AS stg
-- if the record (checks for event_id) already exists on the table, it'll only update the information
ON DUPLICATE KEY UPDATE
	user_id = stg.user_id,
    phone = stg.phone_clean,
    sent_at = stg.sent_at_brt,
    status = stg.status,
    campaign_code = stg.campaign_code,
    AUD_UPD_DTTM = NOW();