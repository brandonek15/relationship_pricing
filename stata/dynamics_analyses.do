*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

*Use the all possible relationships data
use "$data_path/sdc_dealscan_pairwise_combinations_matched_unmatched", clear
br issuer lender* same_lender cusip_6  date_daily_sdc date_daily_dealscan loantype loan_share ///
	rev_discount_1_simple gross_spread_perc proceeds sdc_deal_id facilityid

*Analyses
*E.g. regress any future SDC issuance on whether the bookrunner of the issuance
*Observation should be a dealscan lender x facility, regression is indicator of future issuance with t days on nothign, and then on discount

*Let's say I only want deals within three years
keep if days_from_ds_to_sdc <= 3*365 & days_from_ds_to_sdc >=0

local max_vars same_lender
local last_vars rev_discount_* 

collapse (max) `max_vars' (last) `last_vars' ///
	, by(lender_dealscan facilityid)
reg same_lender 
reg same_lender rev_discount_1_simple

/* All the datasets
use "$data_path/sdc_dealscan_pairwise_combinations", clear
isid sdc_deal_id facilityid lender cusip_6
*Other data I may need to merge on
use "$data_path/sdc_all_clean", clear
isid sdc_deal_id
use "$data_path/stata_temp/dealscan_discounts_facilityid", clear
isid facilityid
use "$data_path/sdc_deal_bookrunner", clear
isid sdc_deal_id lender
use "$data_path/lender_facilityid_cusip6", clear
isid facilityid lender
