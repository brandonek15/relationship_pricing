cap program drop merge_time_between
program define merge_time_between
	*Merge variables from SDC
	local sdc_vars date_daily
	merge m:1 sdc_deal_id using "$data_path/sdc_all_clean", keepusing(`sdc_vars') keep(3) nogen
	rename date_daily date_daily_sdc
	*Merge dealscan deal data
	local dealscan_vars  facilitystartdate 
	merge m:1 facilityid using "$data_path/stata_temp/dealscan_discounts_facilityid", ///
		keepusing(`dealscan_vars') keep(3) nogen
	rename facilitystartdate date_daily_dealscan
	
	gen days_from_ds_to_sdc = date_daily_sdc - date_daily_dealscan
	drop date_daily_sdc date_daily_dealscan

end


cap program drop merge_info_onto_joined_data
program define merge_info_onto_joined_data
	args matched_dummy
	*Merge dealscan lender variables
	local dealscan_lender_vars lenderrole bankallocation
	merge m:1 facilityid lender using "$data_path/dealscan_facility_lender_level", ///
		keepusing(`dealscan_lender_vars') keep(3) nogen
	rename bankallocation loan_share
	rename lenderrole role

	*Merge variables from SDC
	local sdc_vars issuer date_daily equity debt conv gross_spread_perc proceeds
	merge m:1 sdc_deal_id using "$data_path/sdc_all_clean", keepusing(`sdc_vars') keep(3) nogen
	rename date_daily date_daily_sdc
	*Merge dealscan deal data
	local dealscan_vars date_quarterly facilitystartdate loantype packageid facilityamt maturity rev_discount_* 
	merge m:1 facilityid using "$data_path/stata_temp/dealscan_discounts_facilityid", ///
		keepusing(`dealscan_vars') keep(3) nogen
	rename date_quarterly date_quarterly_dealscan
	rename facilitystartdate date_daily_dealscan
	
	if "`matched_dummy'" == "unmatched" {
		rename lender lender_dealscan
		*Make an indicator for whether the lender is the same
		gen same_lender = (lender_sdc == lender_dealscan)
	}
end

*This program will do the joinby to get all pairwise combinations of dealscan and SDC data
use "$data_path/sdc_deal_bookrunner", clear
joinby lender cusip_6 using "$data_path/lender_facilityid_cusip6" ,unmatched(none)
merge_time_between
save "$data_path/sdc_dealscan_pairwise_combinations", replace
*Repeat the same analysis but get all lender/ cusip and bookrunner/cusip pairs
use "$data_path/sdc_deal_bookrunner", clear
rename lender lender_sdc
joinby cusip_6 using "$data_path/lender_facilityid_cusip6" ,unmatched(none)
merge_time_between
save "$data_path/sdc_dealscan_pairwise_combinations_matched_unmatched", replace

*Now we will create samples for analyses
*E.G. All interactions three years after a dealscan observation
*Let's say I only want deals within three years
use "$data_path/sdc_dealscan_pairwise_combinations_matched_unmatched", clear
keep if days_from_ds_to_sdc <= 3*365 & days_from_ds_to_sdc >=0
merge_info_onto_joined_data unmatched
save "$data_path/sdc_dealscan_pairwise_3yrs_post_ds", replace
