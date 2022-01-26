*This program will prepare the datasets needed for the dynamic analyses
cap program drop merge_info_onto_joined_data
program define merge_info_onto_joined_data
	args matched_dummy sdc_vars_add dealscan_vars_add
	*Merge dealscan lender variables
	local dealscan_lender_vars lenderrole bankallocation lead_arranger_credit agent_credit
	merge m:1 facilityid lender using "$data_path/dealscan_facility_lender_level", ///
		keepusing(`dealscan_lender_vars') keep(3) assert(2 3) nogen
	rename bankallocation loan_share
	rename lenderrole role

	*Merge variables from SDC
	local sdc_vars issuer date_daily equity debt conv gross_spread_perc proceeds log_proceeds `sdc_vars_add'
	merge m:1 sdc_deal_id using "$data_path/sdc_all_clean", keepusing(`sdc_vars') keep(3) assert(2 3) nogen
	rename date_daily date_daily_sdc
	*Merge dealscan deal data
	local dealscan_vars date_quarterly facilitystartdate loantype packageid log_facilityamt maturity rev_discount_* ///
		term_loan rev_loan other_loan spread `dealscan_vars_add'
	merge m:1 facilityid using "$data_path/stata_temp/dealscan_discounts_facilityid", ///
		keepusing(`dealscan_vars') keep(3) nogen
	rename date_quarterly date_quarterly_dealscan
	rename facilitystartdate date_daily_dealscan
	
	if "`matched_dummy'" == "unmatched" {
		rename lender lender_dealscan
		*Make an indicator for whether the lender is the same
		gen same_lender = (lender_sdc == lender_dealscan)
	}
	gen constant = 1
end

*We will create samples for analyses

*E.G. All SDC interactions five years after a dealscan observation
use "$data_path/sdc_dealscan_pairwise_combinations_matched_unmatched", clear
keep if days_from_ds_to_sdc <= 5*365 & days_from_ds_to_sdc >=0
merge_info_onto_joined_data unmatched "gross_spread_dol proceeds" "leveraged asset_based"
save "$data_path/sdc_dealscan_pairwise_5yrs_post_ds", replace
*This is an analysis code that uses this dataset
do "$code_path/analysis_sdc_issuance_after_ds.do"
do "$code_path/analysis_ds_loan_pricing_after_sdc.do"

*All dealscan interactions five years after an SDC observation
use "$data_path/sdc_dealscan_pairwise_combinations_matched_unmatched", clear
keep if days_from_ds_to_sdc >= -5*365 & days_from_ds_to_sdc <=0
merge_info_onto_joined_data unmatched "gross_spread_dol proceeds" "leveraged asset_based"
save "$data_path/sdc_dealscan_pairwise_5yrs_post_sdc", replace
do "$code_path/analysis_ds_lending_after_sdc.do"
do "$code_path/analysis_sdc_fee_pricing_after_ds.do"
