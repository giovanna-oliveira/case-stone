-- inserts new records
INSERT INTO GOLD_CLIENT_DATA.FCT_ATTRIBUTION (
    user_id,
    email,
    phone,
    conversion_at,
    interaction_timestamp,
    interaction_type,
    campaign_code,
    channel,
    AUD_INS_DTTM,
    AUD_UPD_DTTM
)
SELECT 
	user_id,
	email,
	phone,
	conversion_at,
	interaction_timestamp,
	interaction_type,
	campaign_code,
	channel,
    AUD_INS_DTTM,
    AUD_UPD_DTTM
FROM ( 
	WITH interaction AS (
	  SELECT 
	  user_id,
	  user_email,
	  null as phone,
	  event_timestamp AS interaction_timestamp,
	  event_type AS interaction,
	  campaign_code,
	  CASE 
		  WHEN event_type = 'sent' THEN 4 -- lowest priority for email
		  WHEN event_type = 'open' THEN 3
		  WHEN event_type = 'click' THEN 2
	  ELSE NULL END as priority,
	  'email' AS channel
	FROM SILVER_CLIENT_DATA.BT_EMAIL_LOGS

	UNION ALL

	SELECT
	  user_id,
	  null as user_email,
	  phone,
	  sent_at AS interaction_timestamp,
	  status AS interaction,
	  campaign_code,
	  CASE 
		  WHEN status = 'delivered' THEN 4 -- lowest priority for whatsapp
		  WHEN status = 'read' THEN 1
	  ELSE NULL END as priority,
	  'whatsapp' AS channel
	FROM SILVER_CLIENT_DATA.BT_WHATSAPP_PROVIDER
	),

	/*
	After uniting both tables, we create associate a Row_number based on the Business Rule, considering both the interaction timestamp and priority. 
	This will result in a SINGLE campaign for each user_id. (Rather than RANK(), that would result in multiple campaign in cenarios where the interactions happened at the exact same time for example)
	*/
	interaction_rn AS (
	SELECT 
	  c.user_id,
	  c.email,
	  c.phone,
	  c.conversion_at,
	  i.interaction_timestamp,
	  i.interaction AS interaction_type,
	  i.campaign_code,
	  i.channel,
	  ROW_NUMBER() OVER(PARTITION BY c.user_id, c.conversion_at ORDER BY priority ASC, interaction_timestamp DESC, campaign_code ASC) AS rn_interaction,
      NOW() AS AUD_INS_DTTM,
	  NOW() AS AUD_UPD_DTTM
	FROM SILVER_CLIENT_DATA.BT_CRM_USER_BASE AS c
	INNER JOIN interaction AS i
	  ON c.user_id = i.user_id 
	  AND i.interaction_timestamp BETWEEN DATE_SUB(c.conversion_at, INTERVAL 7 DAY) AND c.conversion_at
	WHERE c.conversion_at IS NOT NULL
    -- after first run, use this filter
    -- AND DATE(c.conversion_at) >= CURRENT_DATE() - INTERVAL 1 DAY
	)
    -- filter only the relevant interaction
	SELECT 
	  user_id,
	  email,
	  phone,
	  conversion_at,
	  interaction_timestamp,
	  interaction_type,
	  campaign_code,
	  channel,
      AUD_INS_DTTM,
      AUD_UPD_DTTM
	FROM interaction_rn
	WHERE rn_interaction = 1
) AS stg
-- if the record (checks for user_id+conversion_at) already exists on the table, it'll only update the information
ON DUPLICATE KEY UPDATE
    email = stg.email,
    phone = stg.phone,
    interaction_timestamp = stg.interaction_timestamp,
    interaction_type = stg.interaction_type,
    campaign_code = stg.campaign_code,
    channel = stg.channel,
    AUD_UPD_DTTM = NOW()
