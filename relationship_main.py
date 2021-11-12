'''
#this will import the Dealscan computstat related data straight from the WRDS server
, do basic cleaning, and put it into the sqlite database.
#At the end I will have a dataset with Dealscan Compustat
'''

import os
import wrds
import sqlite3
import pandas as pd

from settings import DIRECTORY_LIST,PULL_RAW,MERGE_DEALSCAN_COMPUSTAT,GET_WRDS_DEALSCAN_LINK, \
    SQLITE_FILE,READ_IN_SDC,EQUITY_ISSUANCE_TABLE,DEBT_ISSUANCE_TABLE,MA_ISSUANCE_TABLE,DELETE_SDC

import pull_raw_wrds
import merge_data
import read_in_sdc

# Configurations for WRDS
DB = wrds.Connection(wrds_username='zborowsk')
# Uncomment next line to create pgpass file
#DB.create_pgpass_file()

'''
# Browse databases
print(DB.list_libraries())
print(DB.list_tables(library="dealscan"))
print(DB.describe_table(library="dealscan", table="facility"))
print(DB.describe_table(library="comp", table="fundq"))
print("hello")
'''


def create_dir():
    #This function creates directories and removes the text file so the output is "new"
    for path in DIRECTORY_LIST:
        try:
            os.mkdir(path)
        except OSError:
            print("Creation of the directory " + path + " failed")
        else:
            print("Successfully created the directory " + path)


def main():
    #Create directroy
    create_dir()
    # Create/Connect to the database
    conn = sqlite3.connect(SQLITE_FILE)
    cursor = conn.cursor()

    # Delete if you are recreating the database (you may change a variable)
    if DELETE_SDC == 1:
        try:
            cursor.execute('DROP TABLE ' + EQUITY_ISSUANCE_TABLE )
            print("Successfully deleted the equity table")
        except:
            print("Equity table already deleted")
        try:
            cursor.execute('DROP TABLE ' + DEBT_ISSUANCE_TABLE )
            print("Successfully deleted the debt table")
        except:
            print("Debt table already deleted")
        try:
            cursor.execute('DROP TABLE ' + MA_ISSUANCE_TABLE )
            print("Successfully deleted the Mergers and Aquisitions table")
        except:
            print("Mergers and Aquisitions table already deleted")

    #Pull the raw files we need and upload them to a local database
    if PULL_RAW == 1:
        pull_raw_wrds.pull_raw(DB,conn)
    #Get the linking table between Dealscan and Compustat
    if GET_WRDS_DEALSCAN_LINK == 1:
        pull_raw_wrds.clean_link_table(conn)

    #Merge the files into one from the local database
    if MERGE_DEALSCAN_COMPUSTAT == 1:
        merge_data.merge_data()

    #Import SDC platinum files
    if READ_IN_SDC ==1:
        read_in_sdc.read_in_sdc(conn)

    # Commit and close the connection
    conn.commit()
    conn.close()

    print('finished the program successfully')

if __name__ == '__main__':
    main()
