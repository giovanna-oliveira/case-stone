-- inserts new records
INSERT INTO SILVER_CLIENT_DATA.BT_EMAIL_LOGS (
    event_id,
    user_id,
    user_email,
    event_timestamp,
    event_type,
    campaign_code,
    AUD_INS_DTTM,
    AUD_UPD_DTTM
)
SELECT 
	event_id,
    user_id,
    clean_email,
    formatted_event_timestamp,
    event_type,
    campaign_code,
    AUD_INS_DTTM,
    AUD_UPD_DTTM
FROM (
	SELECT 
		e.event_id,
        c.user_id,
        -- remove empty spaces at the beginning and end of the e-mail, and set as lower case 
		LOWER(TRIM(e.user_email)) as clean_email,
		CONVERT_TZ(
			STR_TO_DATE(REPLACE(REPLACE(event_timestamp, 'T', ' '), 'Z', ''), '%Y-%m-%d %H:%i:%s'),
			'+00:00', 
			'-03:00'
		) AS formatted_event_timestamp,
		e.event_type,
		JSON_UNQUOTE(JSON_EXTRACT(e.message_details, '$.campaign_code')) AS campaign_code,
        NOW() AS AUD_INS_DTTM,
		NOW() AS AUD_UPD_DTTM
	FROM BRONZE_CLIENT_DATA.RAW_SFMC_EMAIL_LOGS e
    LEFT JOIN SILVER_CLIENT_DATA.BT_CRM_USER_BASE c
		ON LOWER(TRIM(e.user_email)) = c.email
	-- after first run, use this filter
	-- WHERE DATE(e.event_timestamp) >= CURRENT_DATE() - INTERVAL 1 DAY
) AS stg
-- if the record (checks for event_id) already exists on the table, it'll only update the information
ON DUPLICATE KEY UPDATE
	user_id = stg.user_id,
    user_email = stg.clean_email,
    event_timestamp = stg.formatted_event_timestamp,
    event_type = stg.event_type,
    campaign_code = stg.campaign_code,
    AUD_UPD_DTTM = NOW();