
cap program drop merge_time_between_sdc_sdc
program define merge_time_between_sdc_sdc
	*Merge on dates
	local sdc_vars date_daily
	merge m:1 sdc_deal_id using "$data_path/sdc_all_clean", keepusing(`sdc_vars') keep(3) nogen
	rename date_daily date_daily_sdc
	
	rename sdc_deal_id sdc_deal_id_temp
	rename sdc_deal_id_copy sdc_deal_id
	
	local sdc_vars date_daily
	merge m:1 sdc_deal_id using "$data_path/sdc_all_clean", keepusing(`sdc_vars') keep(3) nogen
	rename date_daily date_daily_sdc_copy
	
	rename sdc_deal_id sdc_deal_id_copy
	rename sdc_deal_id_temp sdc_deal_id
	gen days_between_match = date_daily_sdc - date_daily_sdc_copy
	drop date_daily_sdc date_daily_sdc_copy

end

do "$code_path/standardize_sdc.do"

*Make an only equity/conv dataset and only debt to decrease size
use "$data_path/sdc_all_clean", clear
keep if equity ==1 | conv ==1
sdc_wide_to_long
save "$data_path/sdc_deal_bookrunner_equity_conv" , replace

use "$data_path/sdc_all_clean", clear
keep if debt==1
sdc_wide_to_long
save "$data_path/sdc_deal_bookrunner_debt", replace

*Do equity to equity
use "$data_path/sdc_deal_bookrunner_equity_conv", clear
rename * *_copy
rename cusip_6_copy cusip_6

joinby cusip_6 using "$data_path/sdc_deal_bookrunner_equity_conv",unmatched(none)
*Don't want to keep matches that come from the same deal_id
drop if sdc_deal_id == sdc_deal_id_copy
*Only want to keep one set of matches (bc there are essentially duplicates)
keep if sdc_deal_id>sdc_deal_id_copy
merge_time_between_sdc_sdc
gen same_lender = (lender == lender_copy)

save "$data_path/sdc_equity_to_equity_match", replace

*Do equity to debt/debt to equity
use "$data_path/sdc_deal_bookrunner_equity_conv", clear
rename * *_copy
rename cusip_6_copy cusip_6
*Note here that copy is the equity

joinby cusip_6 using "$data_path/sdc_deal_bookrunner_debt",unmatched(none)
*Don't want to drop anything yet
merge_time_between_sdc_sdc
rename *_copy *_equity
rename lender lender_debt
rename sdc_deal_id sdc_deal_id_debt
gen same_lender = (lender_debt == lender_equity)
*Now save a "equity to debt" where each observation will be a debt deal id 
*and	  a "debt to equity" where each observation will be an equity deal id
preserve
*days_between_match is date of debt - date of equity
*so if it is positive, debt is issued after the equity match
*First let's make a "equity to debt"
keep if days_between_match>=0 //keeping debt issuances after an equity match
rename sdc_deal_id_debt sdc_deal_id //to make it work with a standardized form
save "$data_path/sdc_equity_to_debt_match", replace

restore

preserve 
*Next let's make a "debt to equity"
keep if days_between_match<=0 //keeping equity issuances after an debt match
replace days_between_match = - days_between_match //make it days after debt issuance
rename sdc_deal_id_debt sdc_deal_id //to make it work with a standardized form
save "$data_path/sdc_debt_to_equity_match", replace

restore

if $run_big_data_code == 1 {
	*Do debt to debt * Very Slow (15 min on server + merges)
	use "$data_path/sdc_deal_bookrunner_debt", clear
	rename * *_copy
	rename cusip_6_copy cusip_6

	joinby cusip_6 using "$data_path/sdc_deal_bookrunner_debt",unmatched(none)
	*Don't want to keep matches that come from the same deal_id
	drop if sdc_deal_id == sdc_deal_id_copy
	*Only want to keep one set of matches (bc there are essentially duplicates)
	keep if sdc_deal_id>sdc_deal_id_copy

	merge_time_between_sdc_sdc
	gen same_lender = (lender == lender_copy)

	save "$data_path/sdc_debt_to_debt_match", replace
}
/*
*Need to still do dealscan to dealscan, which has problems due to size
use "$data_path/lender_facilityid_cusip6", clear

rename * *_copy
rename cusip_6_copy cusip_6

joinby cusip_6 using "$data_path/lender_facilityid_cusip6",unmatched(none)

	*Merge on dates
	local ds_vars facilitystartdate 
	merge m:1 facilityid using "$data_path/stata_temp/dealscan_discounts_facilityid", keepusing(`ds_vars') keep(3) nogen
	rename facilitystartdate  facilitystartdate_ds
	
	rename facilityid facilityid_temp
	rename facilityid_copy facilityid
	
	local ds_vars facilitystartdate 
	merge m:1 facilityid using "$data_path/stata_temp/dealscan_discounts_facilityid", keepusing(`ds_vars') keep(3) nogen
	rename facilitystartdate facilitystartdate_ds_copy
	
	rename facilityid facilityid_copy
	rename facilityid_temp facilityid
	gen days_between_match = facilitystartdate_ds - facilitystartdate_ds_copy
	drop facilitystartdate_*

drop if facilityid == facilityid_copy

gen same_lender = (lender == lender_copy)
