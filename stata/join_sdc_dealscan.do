*This program will do the joinby to get all pairwise combinations of dealscan and SDC data
use "$data_path/sdc_deal_bookrunner", clear
joinby lender cusip_6 using "$data_path/lender_facilityid_cusip6" ,unmatched(none)

*Now we merge on the relevant data from dealscan and sdc
*Merge variable from SDC (need to do something about date_quarterly
local sdc_vars issuer date_daily equity debt conv gross_spread_perc proceeds
merge m:1 sdc_deal_id using "$data_path/sdc_all_clean", keepusing(`sdc_vars') keep(3) nogen
rename date_daily date_daily_sdc
*Need to make a better way where I spread the discount information (to do in clean_dealscan)
*from each package across facility
local dealscan_vars date_quarterly facilitystartdate loantype packageid facilityamt maturity rev_discount_* 
merge m:1 facilityid using "$data_path/stata_temp/dealscan_discounts_facilityid", ///
	keepusing(`dealscan_vars') keep(3) nogen
rename date_quarterly date_quarterly_dealscan
rename facilitystartdate date_daily_dealscan

duplicates drop
*Now we have our dataset to do analyses
save "$data_path/sdc_dealscan_pairwise_combinations", replace
sort cusip_6 date_daily_sdc date_daily_dealscan
br issuer lender cusip_6  date_daily_sdc date_daily_dealscan loantype loan_share ///
	rev_discount_1_simple gross_spread_perc proceeds sdc_deal_id facilityid
	
*Repeat the same analysis but get all lender/ cusip and bookrunner/cusip pairs
use "$data_path/sdc_deal_bookrunner", clear
rename lender lender_sdc
joinby cusip_6 using "$data_path/lender_facilityid_cusip6" ,unmatched(none)
rename lender lender_dealscan
*Now we merge on the relevant data from dealscan and sdc
*Merge variable from SDC (need to do something about date_quarterly
local sdc_vars issuer date_daily equity debt conv gross_spread_perc proceeds
merge m:1 sdc_deal_id using "$data_path/sdc_all_clean", keepusing(`sdc_vars') keep(3) nogen
rename date_daily date_daily_sdc
*Need to make a better way where I spread the discount information (to do in clean_dealscan)
*from each package across facility
local dealscan_vars date_quarterly facilitystartdate loantype packageid facilityamt maturity rev_discount_* 
merge m:1 facilityid using "$data_path/stata_temp/dealscan_discounts_facilityid", ///
	keepusing(`dealscan_vars') keep(3) nogen
rename date_quarterly date_quarterly_dealscan
rename facilitystartdate date_daily_dealscan

*Make an indicator for whether the lender is the same
gen same_lender = (lender_sdc == lender_dealscan)
gen days_from_ds_to_sdc = date_daily_sdc - date_daily_dealscan
gen days_from_sdc_to_ds = date_daily_dealscan - date_daily_sdc

*Now we have our dataset to do analyses
save "$data_path/sdc_dealscan_pairwise_combinations_matched_unmatched", replace
