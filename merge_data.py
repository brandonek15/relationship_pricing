from settings import DEALSCAN_MERGE_FILE,INTERMEDIATE_DATA_PATH,START_DATE, \
    END_DATE,SQLITE_FILE,COMP_MERGE_FILE,EQUITY_ISSUANCE_TABLE,DEBT_ISSUANCE_TABLE, \
    CAPIQ_MERGE_FILE
import os
import ibis
import pandas as pd

def merge_data():
    '''This program will create the query using IBIS, execute the query, and save the file
    for later use'''
    client = create_client()

    #Get the dealscan only data
    #Creates the query
    merge = merge_dealscan(client)

    # Execute executes the query
    print("Beginning to execute Dealscan query")
    merge_df = merge.execute()

    #Save file
    merge_df.to_pickle(DEALSCAN_MERGE_FILE)
    #output to CSV
    path = os.path.join(INTERMEDIATE_DATA_PATH,'dealscan_merge.csv')
    merge_df.to_csv(path,index=False)

    #Also get the dealscan facilitypaymentscheduledata only and output it as is
    facilitypaymentschedule_df= client.table('facilitypaymentschedule').execute()
    path = os.path.join(INTERMEDIATE_DATA_PATH,'dealscan_facilitypaymentscheduledata.csv')
    facilitypaymentschedule_df.to_csv(path,index=False)

    #Also get the compustat file (to play with in another project potentially)
    #Creates the query
    merge = merge_compustat(client)

    # Execute executes the query
    print("Beginning to execute Compustat query")
    merge_df = merge.execute()

    #Save file
    merge_df.to_pickle(COMP_MERGE_FILE)
    #output to CSV
    path = os.path.join(INTERMEDIATE_DATA_PATH,'compustat_merge.csv')
    merge_df.to_csv(path,index=False)

    #Also get the capiq file (to merge onto compustat in Stata)
    #Creates the query
    merge = merge_capiq(client)

    # Execute executes the query
    print("Beginning to execute Capital IQ query")
    merge_df = merge.execute()

    #Save file
    merge_df.to_pickle(CAPIQ_MERGE_FILE)
    #output to CSV
    path = os.path.join(INTERMEDIATE_DATA_PATH,'capiq_merge.csv')
    merge_df.to_csv(path,index=False)


def merge_dealscan(client):
    #This program only pulls dealscan and saves only the dealscan file
    #This will give us a facility file
    # Load in tables "facility", "marketsegment", "company"
    facility= client.table('facility')
    package = client.table('package')
    marketsegment = client.table('marketsegment')
    company = client.table('company')
    bb = client.table('borrowerbase')
    pricing = client.table('currfacpricing')
    lender_shares = client.table('lendershares')
    fin_cov = client.table('financialcovenant')
    worth_cov = client.table('networthcovenant')

    #Aggregate pricing to make it only observation per facilityid
    pricing = pricing.group_by('facilityid').aggregate([
        pricing['baserate'].max().name('baserate'),
        pricing['minbps'].max().name('minbps'),
        pricing['maxbps'].max().name('maxbps'),
        pricing['allindrawn'].max().name('allindrawn'),
        pricing['allinundrawn'].max().name('allinundrawn')
        ])

    # Keep only observations from the facility file that are starting in date range
    facility = facility[facility['facilitystartdate'].between(START_DATE, END_DATE)]

    #Merge on company data by mering on Company ID
    joined = facility.inner_join(company, [
        facility['borrowercompanyid'] == company['companyid']
    ])

    # Add marketsegment data by merging on facilityID
    joined = joined.left_join(marketsegment, [
        facility['facilityid'] == marketsegment['facilityid']
    ])

    #Add borrowing base, lender shares, financial cov, net worth cov
    joined = joined.left_join(bb, [
        facility['facilityid'] == bb['facilityid']
    ])
    joined = joined.left_join(pricing, [
        facility['facilityid'] == pricing['facilityid']
    ])
    joined = joined.left_join(lender_shares, [
        facility['facilityid'] == lender_shares['facilityid']
    ])
    joined = joined.left_join(package, [
        facility['packageid'] == package['packageid']
    ])
    joined = joined.left_join(fin_cov, [
        facility['packageid'] == fin_cov['packageid']
    ])
    joined = joined.left_join(worth_cov, [
        facility['packageid'] == worth_cov['packageid']
    ])

    #Because there are two variables called covenanttype, I need to rename one of them
    covenanttype_nw = (worth_cov.covenanttype).name('covenanttype_nw')

    final_merge = joined[facility,
                         company['company'], company['ultimateparentid'],
                         company['ticker'],company['publicprivate'],
                         company['country'], company['institutiontype'],
                         company['primarysiccode'],
                         package['salesatclose'],package['dealamount'],
                         package['refinancingindicator'],
                         marketsegment['marketsegment'],
                         bb['borrowerbasetype'],bb['borrowerbasepercentage'],
                         pricing['baserate'],
                         pricing['minbps'], pricing['maxbps'],
                         pricing['allindrawn'], pricing['allinundrawn'],
                         fin_cov['covenanttype'],fin_cov['initialratio'],
                         worth_cov['baseamt'],
                         worth_cov['percentofnetincome'],covenanttype_nw,
                         lender_shares['lender'],lender_shares['lenderrole'],
                         lender_shares['bankallocation'],lender_shares['agentcredit'],
                         lender_shares['leadarrangercredit']
    ]

    return final_merge

def merge_compustat(client):
    '''This file merges only compustat tables and saves them to csv (for playing
    in another project. This provides a firm x quarter file'''

    # Load in compustat tables
    comp_quarter = client.table('comp_quarter')
    comp_identity = client.table('comp_identity')
    comp_ipo = client.table('comp_ipo')
    #Load in crosswalk
    crosswalk = client.table('dealscan_compustat_crosswalk')

    # Keep only observations within the start and end dage
    comp_quarter = comp_quarter[comp_quarter['rdq'].between(START_DATE, END_DATE)]
    # Get company information
    joined = comp_quarter.inner_join(comp_identity, [
        comp_quarter['gvkey'] == comp_identity['gvkey']
    ])
    #Get company ipodate
    joined = joined.inner_join(comp_ipo, [
        comp_quarter['gvkey'] == comp_ipo['gvkey']
    ])
    #Merge on crosswalk
    joined = joined.left_join(crosswalk, [
        comp_quarter['gvkey'] == crosswalk['gvkey']
        ])

    final_merge = joined[comp_quarter,
                         comp_identity['conm'], comp_identity['cusip'],
                         comp_identity['cik'], comp_identity['sic'],
                         comp_identity['naics'],comp_ipo['ipodate'],
                         crosswalk['bcoid']

    ]

    return final_merge

def merge_capiq(client):
    '''This file merges only capitaliq rating data
    I will end up with a gvkey by ratingdate dataset'''

    # Load in capiq tables
    capiq_ratings = client.table('capiq_ratings')
    capiq_ratings_types = client.table('capiq_ratings_types')
    capiq_gvkey = client.table('capiq_gvkey')

    #Limit the sample to only ones where the rating type code is "Local Currency LT"
    capiq_ratings_types = capiq_ratings_types[capiq_ratings_types['ratingtypename']== "Local Currency LT"]

    #Get ratingtype description
    joined = capiq_ratings.inner_join(capiq_ratings_types, [
        capiq_ratings['ratingtypecode'] == capiq_ratings_types['ratingtypecode']
    ])

    #Limit the sample to only ones where the rating type code is "Local Currency LT"
    #joined = joined[capiq_ratings_types['ratingtypecode']== "Local Currency LT"]

    #Merge on GVKEY for the appropriate time periods
    joined = joined.left_join(capiq_gvkey, [
        capiq_ratings['company_id'] == capiq_gvkey['companyid'],
        (capiq_ratings['ratingdate']<= capiq_gvkey['enddate']) | (capiq_gvkey['enddate']==ibis.NA),
        (capiq_ratings['ratingdate'] >= capiq_gvkey['startdate']) | (capiq_gvkey['startdate'] == ibis.NA)
    ])

    final_merge = joined[capiq_ratings,
                         capiq_ratings_types['ratingtypename'],
                         capiq_gvkey['gvkey']
    ]

    return final_merge

def create_client():
    """Create and configure a database client"""
    ibis.options.interactive = True
    ibis.options.sql.default_limit = None
    # For testing, set to 10000
    # ibis.options.sql.default_limit = 10000
    return ibis.sqlite.connect(SQLITE_FILE)

def export_sdc(conn):
    '''This file will read in the SDC tables using SQL and export them as csv's for Stata'''
    for type in ['equity','debt']:
        if type == 'equity':
            table_name = EQUITY_ISSUANCE_TABLE
            file_name = 'sdc_equity_issuance_all.csv'
        elif type == 'debt':
            table_name = DEBT_ISSUANCE_TABLE
            file_name = 'sdc_debt_issuance_all.csv'

        query = "SELECT * FROM " + table_name
        df = pd.read_sql_query(query, conn)
        # save the file to csv
        file_loc = os.path.join(INTERMEDIATE_DATA_PATH,file_name)
        df.to_csv(file_loc, index=False, mode='w')
        print('Finished saving file: ' + file_loc)
