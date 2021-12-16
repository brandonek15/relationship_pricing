from settings import COMPUSTAT_DEALSCAN_LINK
import pandas as pd
import numpy as np

COMP_VARS = ['datadate', 'fyearq', 'fqtr', 'rdq', 'atq',
             'ceqq','chq','cheq','cshoq,''ltq',
             'dlcq','dlttq','ibq',
             'mkvaltq','gdwlq','ppentq','actq',
             'oibdpq','prccq','nopiq','saleq','lctq',
             'niq','pstkq','revtq','seqq','xintq',
             'cogsq','xsgaq','wcapq',
              'intanq','capxy',
             'xrdy','prstkcy', 'aqcy', 'dvy', 'gvkey']

def pull_raw(wrds_conn,conn):
    '''Pulls raw data from WRDS and uploads it SQL lite database'''
    #Comment 1: When uploading to the database, it will make it lowercase so the dictionaries must be
    #Comment 2: Including a dictionary of datatypes for variables we merge on to make sure
    #Pandas doesn't screw it up on accident
    # Add all of the data needed necessary to do the CRSP computstat merge
    dtypes = {'borrowercompanyid': int, 'facilityid': int, 'packageid': int}
    cols=['FacilityID','PackageID','BorrowerCompanyID','FacilityStartDate','FacilityEndDate',\
          'comment','LoanType','PrimaryPurpose','SecondaryPurpose','FacilityAmt',\
          'Currency','ExchangeRate','Maturity','Secured','DistributionMethod','Seniority']
    retrieve_table(wrds=wrds_conn, connection=conn, library='dealscan',table = 'facility' \
                   , heading='facility',columns_to_pull=cols,dtypes_for_upload=dtypes)

    dtypes = {'packageid': int}
    cols =['PackageID','SalesAtClose','DealAmount','RefinancingIndicator']
    retrieve_table(wrds=wrds_conn, connection=conn, library='dealscan',table = 'package' \
                   , heading='package',columns_to_pull=cols,dtypes_for_upload=dtypes)

    dtypes = {'companyid': int}
    cols =['CompanyID','Company','UltimateParentID','Ticker','PublicPrivate','Country',\
           'InstitutionType','PrimarySICCode']
    retrieve_table(wrds=wrds_conn, connection=conn, library='dealscan',table = 'company' \
                   , heading='company',columns_to_pull=cols,dtypes_for_upload=dtypes)

    dtypes = {'facilityid': int}
    cols =['FacilityID','MarketSegment']
    retrieve_table(wrds=wrds_conn, connection=conn, library='dealscan',table = 'marketsegment' \
                   , heading='marketsegment',columns_to_pull=cols,dtypes_for_upload=dtypes)

    dtypes = {'facilityid': int}
    cols =['FacilityID','BorrowerBaseType','BorrowerBasePercentage']
    retrieve_table(wrds=wrds_conn, connection=conn, library='dealscan',table = 'borrowerbase' \
                   , heading='borrowerbase',columns_to_pull=cols,dtypes_for_upload=dtypes)

    dtypes = {'facilityid': int}
    cols =['FacilityID','BaseRate','Fee','MinBps','MaxBps','AllInDrawn','AllInUndrawn']
    retrieve_table(wrds=wrds_conn, connection=conn, library='dealscan',table = 'currfacpricing' \
                   , heading='currfacpricing',columns_to_pull=cols,dtypes_for_upload=dtypes)

    dtypes = {'facilityid': int}
    cols =['FacilityID','Lender','LenderRole','BankAllocation','AgentCredit','LeadArrangerCredit']
    retrieve_table(wrds=wrds_conn, connection=conn, library='dealscan',table = 'lendershares' \
                   , heading='lendershares',columns_to_pull=cols,dtypes_for_upload=dtypes)

    dtypes = {'packageid': int}
    cols =['PackageID','CovenantType','InitialRatio']
    retrieve_table(wrds=wrds_conn, connection=conn, library='dealscan',table = 'financialcovenant' \
                   , heading='financialcovenant',columns_to_pull=cols,dtypes_for_upload=dtypes)

    dtypes = {'packageid': int}
    cols =['PackageID','CovenantType','BaseAmt','PercentofNetIncome']
    retrieve_table(wrds=wrds_conn, connection=conn, library='dealscan',table = 'networthcovenant' \
                   , heading='networthcovenant',columns_to_pull=cols,dtypes_for_upload=dtypes)

    #Pull Compustat Data
    dtypes = {'gvkey': int}
    retrieve_table(wrds_conn, conn, 'comp', 'fundq', 'comp_quarter', \
                   columns_to_pull = COMP_VARS,dtypes_for_upload=dtypes)
    #Pull Compustat Identifying info
    dtypes = {'gvkey': int}
    cols = ['gvkey','conm','cusip','cik','sic','naics']
    retrieve_table(wrds_conn, conn, 'comp', 'names', 'comp_identity', \
                   columns_to_pull=cols,dtypes_for_upload=dtypes)


def retrieve_table(wrds, connection, library, table, heading, columns_to_pull='all', \
                   dtypes_for_upload = None):
    """Pull the WRDS table using the get_table command and upload to SQL lite database"""
    print("Pulling library: " + library + ", table: " + table)
    if columns_to_pull == 'all':
        wrds_table = wrds.get_table(library, table)
    else:
        wrds_table = wrds.get_table(library, table, columns=columns_to_pull)

    wrds_table.drop_duplicates()
    #Convert variables to datatypes
    if dtypes_for_upload != None:
        wrds_table = wrds_table.astype(dtypes_for_upload)

    wrds_table.to_sql(heading, connection, if_exists="replace", index=False)
    print("Finished pulling library: " + library + ", table: " + table)

def clean_link_table(conn):
    '''This program uses the Chava and Roberts linking table and uploads to the database'''
    link_df = pd.read_excel(COMPUSTAT_DEALSCAN_LINK,sheet_name='link_data',\
                            usecols=['bcoid','gvkey'],dtype={'bcoid':np.int32,'gvkey':np.int32})
    limited_df = link_df[['bcoid','gvkey']].drop_duplicates()
    #Assert the index is unique
    assert limited_df.set_index(['bcoid','gvkey']).index.is_unique,'Borrower Company ID - GVkey match not unique'
    limited_df.to_sql("dealscan_compustat_crosswalk", conn, if_exists="replace", index=False)
    print("Finished Uploading Dealscan Compustat Crosswalk")