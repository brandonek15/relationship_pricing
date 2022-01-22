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
