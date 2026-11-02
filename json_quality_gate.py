# import libraries
import pandas as pd
import json
import logging # to report logs in the Airflow interface
from datetime import datetime

# set logger
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# set files names
input_file = "./data/raw_data/raw_sfmc_email_logs.csv"
valid_rows_file = "./data/clean_data/sfmc_email_logs_valid.csv"
rejected_rows_file = "./data/rejected_data/sfmc_email_logs_rejected.csv"

def check_valid_json(json_value):
  # check if json_value is not either a string value or empty (null or "")
  if not isinstance(json_value, str) or not json_value:
    return False
  # if it's a string and not empty, check if it's able to convert into a json
  try:
    json.loads(json_value)
    return True
  except (ValueError, TypeError) as error:
    logger.error(
            f"Invalid JSON: {json_value}. Error: {error}"
        )
    return False

def validate_email_message(df_data):
  logger.info('---- Starting validation ----')

  # creates a new column (is_valid) that will store the result of the function
  # previosly created. Such function will be executed for each row in the file.
  df_data['is_valid'] = df_data['message_details'].apply(check_valid_json)

  # creates 2 new dataframes, one for valid message_details and the other with the rest
  valid_json = df_data[df_data['is_valid'] == True].drop(columns=['is_valid'])
  rejected_json = df_data[df_data['is_valid'] == False].drop(columns=['is_valid'])

  return valid_json, rejected_json

def ingest_file():
  try:
    df_raw = pd.read_csv(input_file)

    # runs the function created and receives the returned values
    valid_json, rejected_json = validate_email_message(df_raw)

    if not rejected_json.empty:
      rejected_json.to_csv(rejected_rows_file, index = False)
      logger.warning(f"Rejected records {len(rejected_json)}: {rejected_rows_file}")

    valid_json.to_csv(valid_rows_file,index=False)
    logger.info(f"Finish: {len(valid_json)} valid records")


  except Exception:
      logger.exception("Error during the process.")
      raise

if __name__ == "__main__":
    ingest_file()