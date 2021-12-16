#This file will import all of the underwriting data form SDC and format them nicely in a database
from settings import  RAW_DATA_SDC_PATH,EQUITY_ISSUANCE_TABLE,DEBT_ISSUANCE_TABLE,MA_ISSUANCE_TABLE
import os
import pandas as pd
import re
import numpy as np

#todo It is possible that the column lengths would change when I download different years.
#If this occurs, need to figure out a more automated way. Even worse, the order of the columns
#See if I can standardize them in SDC
#todo need to download all years

COLSPECS_EQUITY = [(1, 9), (10, 40), (41, 161), (162, 171), (172, 202), \
            (203, 217), (218, 232), (233, 239), (240, 255), \
            (256, 272), (273, 296), (297, 327), (328, 337), (338, 347), (348, 357), \
            (358, 367), (368, 377), (378, 390), (391, 401), (402, 414), \
            (415, 427), (428, 440), (441, 452), (453, 467), (468, 480), \

            (481, 489), (490, 503), (504, 516), (517, 532), (533, 578), \
            (579, 588), (589, 606), (607, 615), (616, 624), \
            (625, 641), (642, 658), (659, 675), (676, 689), (690, 703), \
            (704, 716), (717, 729), (730, 737), (738, 758), \
            (759, 777), (778, 797), (798, 815), \
            (816, 827), (828, 837), (838, 868), (869, 876), (877, 884)]
NAMES_EQUITY = ['issue_date', 'issuer', 'business_desc', 'sic', 'high_tech_ind', \
         'state', 'nation', 'ticker','ticker_exch', \
         'ind', 'bookrunners', 'all_managers', 'gross_spread_per_unit', 'management_fee_dol','underwriting_fee_dol', \
         'selling_conc_dol', 'reallowance_dol', 'gross_spread_perc', 'management_fee_perc','underwriting_fee_perc', \
         'selling_conc_perc', 'reallowance_perc', 'gross_spread_dol', 'principal_local', 'principal_global', \
         'proceeds_local', 'proceeds_global', 'offer_price', 'sec_type', 'desc', \
         'currency', 'marketplace', 'prim_exch', 'filing_date', \
         'orig_price_high', 'orig_price_low', 'orig_price_mid', 'shares_filed_local', 'shares_filed_global', \
         'amt_filed_local', 'amt_filed_global', 'ipo_ind', 'shares_offered_local', \
         'prim_shares_offered_local', 'sec_shares_offered_local', 'shares_offered_global', \
         'yest_stock_price', 'stock_price_close_offer', 'spinoff_parent', 'perc_owned_before_spinoff','perc_owned_after_spinoff']

COLSPECS_DEBT = [(1, 9), (10, 18), (19, 27), (28, 36), (37, 67), (68, 188), \
            (189, 198), (199, 229),(230, 244),(245, 259), (260, 266),(267, 282), \
            (283, 299), (300, 323), (324, 354), (355, 364), (365, 374), \
            (375, 384), (385, 394), (395, 404), (405, 417),  \
            (418, 428), (429, 441), (442, 454), (455, 467),  \
            (468, 479),(480, 494), (495, 507), (508, 516), (517, 530),  \
            (531, 543),(544, 559), (560, 605), (606, 615), (616, 633), (634, 642), \
            (643, 659), (660, 676), (677, 693), (694, 707), \
            (708, 721), (722, 734), (735, 747), (748, 758), (759, 774)]
NAMES_DEBT = ['maturity_final','maturity','filing_date','issue_date', 'issuer', 'business_desc', \
              'sic', 'high_tech_ind', 'state', 'nation', 'ticker','ticker_exch', \
         'ind', 'bookrunners', 'all_managers', 'gross_spread_per_unit', 'management_fee_dol', \
         'underwriting_fee_dol', 'selling_conc_dol', 'reallowance_dol', 'gross_spread_perc', \
        'management_fee_perc','underwriting_fee_perc', 'selling_conc_perc', 'reallowance_perc', \
        'gross_spread_dol', 'principal_local', 'principal_global',  'proceeds_local', 'proceeds_global', \
        'offer_price', 'sec_type', 'desc', 'currency', 'marketplace', 'prim_exch', \
        'orig_price_high', 'orig_price_low', 'orig_price_mid', 'shares_filed_local', \
        'shares_filed_global', 'amt_filed_local', 'amt_filed_global', 'coupon', 'offer_ytm']

def read_in_sdc(conn):
    '''This function will loop over all of the equity, debt, files and then upload them
    to a database'''

    year = 2020
    #Loop over debt and equity
    for type in ['equity','debt']:
    #for type in ['debt']:
        if type == 'equity':
            table_name = EQUITY_ISSUANCE_TABLE
            colspecs = COLSPECS_EQUITY
            names = NAMES_EQUITY
        elif type == 'debt':
            table_name = DEBT_ISSUANCE_TABLE
            colspecs = COLSPECS_DEBT
            names = NAMES_DEBT

        file_name = type + '_issuance_' + str(year) + '.txt'
        file_location = os.path.join(RAW_DATA_SDC_PATH,file_name)
        #Read in text file
        # Load in the equity issuance file
        #This file will import the txt file, create and create the appropriate column headers for stata.
        df = pd.read_fwf(file_location,colspecs = colspecs,names=names,index_col=False)
        #Get the aggregated dataframe based off of the one we read in
        df = aggregate_df(df)
        #Save it?
        df.to_sql(name=table_name, con=conn, if_exists="append", index=False)
        print('added file' + file_location + ' to database')
    print('jeff')

def get_list_of_indices(date_array):
    '''This function returns the list of indices to create a dataframe'''
    regex = re.compile('[0-9/ ]+', flags=re.DOTALL)
    start_flag = False
    list_of_indices = []
    for index in range(len(date_array)):
        regex_search = regex.search(str(date_array[index]))
        #If the observation is the date
        if regex_search != None:
            #If this is the first time, it is different
            if start_flag == True:
                #Now need to get the end_index
                #Check the observation before. Once I find dashes, then the end index is one before
                shifter = 1
                while date_array[index-shifter] != '--------':
                    #Add one to the shifter
                    shifter+=1
                #Now we know the end_index, add it to the list
                end_index = index-shifter-1
                list_of_indices.append([start_index,end_index])
                #Now reset the new start index
                start_index = index
            elif start_flag==False:
                start_index = index
                start_flag=True

    return list_of_indices

def aggregate_df(df):
    '''This function returns a clean dataframe from the one that is read in'''
    #Now need to write code that goes line by line and collapses observations between dotted lines into observations
    #WFirst I need to get a list of indices, that determine the relevant
    list_of_indices = get_list_of_indices(df['issue_date'])
    aggregated_df = 1
    # Loop over the list of indices
    df_dict = {}
    #Need to go and create a dictionary with keys as the columsn and values are lists
    for index_pair in list_of_indices:
        for col in df.columns:
            #This list will be added to the list inside the dictionary
            temp_list = []
            # If a value already does not exist, create an empty list in the dictionary
            if col not in df_dict.keys():
                dict_update = {col: []}
                df_dict.update(dict_update)
            #Loop over the indices in the respective pair
            for index in range(index_pair[0],index_pair[1]+1):
                #Add the values from the indices to the list if it isn't nan
                if str(df[col][index]) != 'nan':
                    temp_list.append(str(df[col][index]))
            #Update the list by appending to the current list
            updated_list = df_dict[col].copy()
            updated_list.append(','.join(temp_list))
            dict_update = {col:updated_list}
            df_dict.update(dict_update)

    #Turn the dictionary into a new dataframe
    aggregated_df = pd.DataFrame.from_dict(df_dict)
    #Only keep observations that have a date (remove bad observations)
    aggregated_df = aggregated_df[aggregated_df['issue_date'].str.contains('[0-9/]{8}',regex=True,na=False)]
    return aggregated_df