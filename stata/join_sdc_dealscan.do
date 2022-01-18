*This program will do the joinby to get all pairwise combinations of dealscan and SDC data
use "$data_path/sdc_deal_bookrunner", clear
joinby lender cusip_6 using "$data_path/lender_facilityid_cusip6" ,unmatched(none)

*Now we merge on the relevant data from dealscan and sdc
*Merge variable from SDC (need to do something about date_quarterly
local sdc_vars issuer date_quarterly_sdc equity debt conv gross_spread_perc
merge m:1 sdc_deal_id using "$data_path/sdc_all_clean", keepusing(`sdc_vars') keep(3) nogen

*Need to make a better way where I spread the discount information (to do in clean_dealscan)
*from each package across facility
local dealscan_vars date_quarterly loantype packageid facilityamt maturity rev_discount_* 
merge m:1 facilityid using "$data_path/stata_temp/dealscan_discounts_facilityid", ///
	keepusing(`dealscan_vars') keep(3) nogen
rename date_quarterly date_quarterly_dealscan

*Now we have our dataset to do analyses
save "$data_path/sdc_dealscan_pairwise_combinations", replace
