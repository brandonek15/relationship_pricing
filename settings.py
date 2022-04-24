import os
import platform
import pandas as pd

# Set the directory
if platform.system() == 'Windows':
    ROOT = 'C:\\Users\\Brand\\OneDrive\\Econ\\Northwestern\\Asset Pricing 3\\Problem Sets'
elif platform.system() == 'Linux':
    #For the terminal
    ROOT = '/kellogg/proj/blz782/bank_relationship_pricing'


#Import the merge_data function from previous hw
DATA_PATH = os.path.join(ROOT,'data')
RAW_DATA_PATH = os.path.join(DATA_PATH,'raw')
RAW_DATA_SDC_PATH = os.path.join(RAW_DATA_PATH,'sdc')
INPUTS_DATA_PATH = os.path.join(DATA_PATH,'inputs')

CODE_PATH = os.path.join(ROOT, 'code')
FINAL_OUTPUT_PATH = os.path.join(ROOT, "output")
INTERMEDIATE_DATA_PATH = os.path.join(ROOT,'intermediate_data')
SQL_LITE_PATH = os.path.join(ROOT,'sql_lite')

SQLITE_FILE = os.path.join(SQL_LITE_PATH, 'database_relationship_pricing.sqlite')
DEALSCAN_MERGE_FILE = os.path.join(INTERMEDIATE_DATA_PATH,'dealscan_merge.pkl')
COMP_MERGE_FILE = os.path.join(INTERMEDIATE_DATA_PATH,'compustat_merge.pkl')
CAPIQ_MERGE_FILE = os.path.join(INTERMEDIATE_DATA_PATH,'capiq_merge.pkl')


EQUITY_ISSUANCE_TABLE = 'equity_issuance'
DEBT_ISSUANCE_TABLE = 'debt_issuance'
MA_ISSUANCE_TABLE = 'ma_issuance'

COMPUSTAT_DEALSCAN_LINK = os.path.join(RAW_DATA_PATH,'ds_cs_link_April_2018_post.xlsx')

DIRECTORY_LIST = [FINAL_OUTPUT_PATH, CODE_PATH,DATA_PATH,INTERMEDIATE_DATA_PATH,\
                  SQL_LITE_PATH,RAW_DATA_PATH,INPUTS_DATA_PATH,RAW_DATA_SDC_PATH]

START_DATE = pd.to_datetime('2001-01-01')
END_DATE = pd.to_datetime('2020-12-31')
#Delete SDC Tables Only set to 1 if you are sure you want to delete
DELETE_SDC =0
# Set to 1 if you want all of the raw data to be pulled
PULL_RAW = 0
GET_WRDS_DEALSCAN_LINK = 0
MERGE_DEALSCAN_COMPUSTAT = 1
READ_IN_SDC = 0
EXPORT_SDC = 0