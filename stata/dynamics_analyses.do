*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC
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

*Use the all possible relationships data
use "$data_path/sdc_dealscan_pairwise_combinations_matched_unmatched", clear
br issuer lender* cusip_6  date_daily_sdc date_daily_dealscan loantype loan_share ///
	rev_discount_1_simple gross_spread_perc proceeds sdc_deal_id facilityid

*For each deal in dealscan, see if a bookrunner for that deal was on a previous dealscan deal
/*
use "$data_path/sdc_deal_bookrunner", clear
joinby cusip_6 using "$data_path/lender_facilityid_cusip6" ,unmatched(none)
*
use "$data_path/sdc_deal_bookrunner", clear
merge 1:m sdc_deal_id lender cusip_6 using "$data_path/sdc_dealscan_pairwise_combinations"
*Figure out why this isn't working
