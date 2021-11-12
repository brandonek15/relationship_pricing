#This file will import all of the underwriting data form SDC and format them nicely in a database
from settings import  RAW_DATA_SDC_PATH
import os
import pandas as pd

def read_in_sdc():
    '''This function will loop over all of the equity, debt, files and then upload them
    to a database'''

    #Load in the equity issuance file
    type = 'equity'
    year = 2020
    file_name = type + '_issuance_' + str(year) + '.txt'
    file_location = os.path.join(RAW_DATA_SDC_PATH,file_name)
    #Read in text file

    #This file will import the txt file, create and create the appropriate column headers for stata.
    colspecs = [(1,9),(10,40),(41,161),(162,171),(172,202),(203,217),(218,232),(233,239),(240,255) , \
                (256,272),(273,296),(297,327),(328,337),(338,347),(348,357), \
                (358,367),(368,377),(378,390),(391,401),(402,414), \
                (415,427),(428,440),(441,452),(453,467),(468,480), \
                (481,489),(490,503),(504,516),(517,532),(533,578), \
                (579,588),(589,606),(607,615),(616,624), \
                (625,641),(642,658),(659,675),(676,689),(690,703), \
                (704,716),(717,729),(730,737),(738,758), \
                (759,777),(778,797),(798,815), \
                (816,827),(828,837),(838,868),(869,876),(877,884)]
    names = ['issue_date','issuer','business_desc','sic','high_tech_ind','state','nation','ticker','ticker_exch', \
             'ind','bookrunners','all_managers','gross_spread_per_unit','management_fee_dol','underwriting_fee_dol', \
             'selling_conc_dol','reallowance_dol','gross_spread_perc','management_fee_perc','underwriting_fee_perc', \
             'selling_conc_perc','reallowance_perc','gross_spread_dol','principal_local','principal_global', \
             'proceeds_local','proceeds_global','offer_price','sec_type','desc', \
             'currency','marketplace','prim_exch','filing_date', \
             'orig_price_high','orig_price_low','orig_price_mid','shares_filed_local','shares_filed_global', \
             'amt_filed_local','amt_filed_global','ipo_ind','shares_offered_local',\
             'prim_shares_offered_local','sec_shares_offered_local','shares_offered_global', \
             'yest_stock_price','stock_price_close_offer','spinoff_parent','perc_owned_before_spinoff','perc_owned_after_spinoff']
    df = pd.read_fwf(file_location,colspecs = colspecs,names=names,index_col=False)
    #Now need to write code that goes line by line and collapses observations between dotted lines into observations
    #Save it?
    #df.to_csv(il_path_adj, index=False, mode='w',sep=';')
    print('jeff')