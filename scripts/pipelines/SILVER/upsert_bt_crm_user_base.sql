-- inserts new records
INSERT INTO SILVER_CLIENT_DATA.BT_CRM_USER_BASE (
    user_id,
    email,
    phone,
    conversion_at,
    AUD_INS_DTTM,
    AUD_UPD_DTTM
)
SELECT 
    user_id,
    clean_email,
    clean_phone,
    formatted_conversion_at,
    AUD_INS_DTTM,
    AUD_UPD_DTTM
FROM (
		SELECT 
			user_id,
			-- remove empty spaces at the beginning and end of the e-mail, and set as lower case 
			LOWER(TRIM(email)) AS clean_email,
			 -- it's better to store the phone number with just the numbers
			REGEXP_REPLACE(phone, '[^0-9]', '') AS clean_phone,
			CONVERT_TZ(STR_TO_DATE(NULLIF(TRIM(conversion_at), ''),'%Y-%m-%d %H:%i:%s'), '+00:00', '-03:00') AS formatted_conversion_at,
			NOW() AS AUD_INS_DTTM,
			NOW() AS AUD_UPD_DTTM
		FROM BRONZE_CLIENT_DATA.RAW_CRM_USER_BASE 
		WHERE 
			-- check for valid emails
			email REGEXP '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$'
) AS stg
-- if the record (checks for user_id) already exists on the table, it'll only update the information
ON DUPLICATE KEY UPDATE
    email = stg.clean_email,
    phone = stg.clean_phone,
    conversion_at = stg.formatted_conversion_at,
    AUD_UPD_DTTM = NOW();