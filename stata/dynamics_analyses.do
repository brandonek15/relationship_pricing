*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

*Use the all possible relationships data
use "$data_path/sdc_dealscan_pairwise_3yrs_post_ds", clear

*isid cusip_6 lender_dealscan lender_sdc sdc_deal_id facilityid 
br issuer lender* same_lender cusip_6  date_daily_sdc date_daily_dealscan loantype loan_share ///
	rev_discount_1_simple gross_spread_perc proceeds sdc_deal_id facilityid

*Analyses
*E.g. regress any future SDC issuance on whether the bookrunner of the issuance
*Observation should be a dealscan lender x facility, regression is indicator of future issuance with t days on nothign, and then on discount

local max_vars same_lender
local last_vars rev_discount_* 

collapse (max) `max_vars' (last) `last_vars' ///
	, by(lender_dealscan facilityid)
reg same_lender 
reg same_lender rev_discount_1_simple
