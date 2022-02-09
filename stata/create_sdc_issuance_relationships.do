*This program will create a dataset where each observation is a "lender" x sdc_deal_id
* and the set of lenders is the set of biggest lenders/bookrunners
*Then it will merge on the most recent information from an equity, debt, conv offering
*and term, revolving, and other loan from the same lender.

*Make a skeleton dataset
do "$code_path/programs_relationship"

*As inputs it will take the following:
*Number of lenders per deal
local n_lenders 20
*Get the skeleton dataset (sdc_deal_id x lender)
make_skeleton "sdc" `n_lenders'

*Now fill out the skeleton. Need to pass the function 5 arguments
*Type is either SDC or DS (it is what the baseline structure of the skeleton is made of)
local type "sdc"
*base_vars are the variables you want about the current observation (meaning the deal/loan is the unit)
local base_vars issuer equity debt conv gross_spread_perc
*sdc_vars are the variables you want from the most recent equity,debt,conv offerings
local sdc_vars gross_spread_perc proceeds log_proceeds
*ds_vars are the variables you want from the most recent term,rev,other loans 
local ds_vars loantype packageid log_facilityamt maturity rev_discount_1_simple spread
*ds_lender_vars are the variables you want abou the most recent dealscan lenders.
local ds_lender_vars lenderrole bankallocation lead_arranger_credit agent_credit
fill_out_skeleton "`type'" "`base_vars'" "`sdc_vars'" "`ds_vars'" "`ds_lender_vars'"

isid sdc_deal_id lender
save "$data_path/sdc_deals_with_past_relationships_`n_lenders'", replace 

/*
*Now merge on who was truly a lender on the deal
merge 1:1 sdc_deal_id lender using "$data_path/sdc_deal_bookrunner", keep(1 3)
gen hire = (_merge ==3)
labe var hire "Hire"
drop cusip_6 _merge

*Get basic deal characteristics I always want
merge m:1 sdc_deal_id using "$data_path/sdc_all_clean", keepusing(issuer date_daily cusip_6) assert(3) nogen

*Now get the deal characteristics you want from the current sdc_deal
local sdc_char_base equity debt conv gross_spread_perc 
merge m:1 sdc_deal_id using "$data_path/sdc_all_clean", keepusing(`sdc_char_current') assert(3) nogen
foreach var of local sdc_char_base {
	rename `var' `var'_base
}

*I am making 6 types of matches. For each type of match, first I merge on the most recent match for each
*deal id x lender. Then I get the relevant variables by using the id

local sdc_vars gross_spread_perc proceeds log_proceeds
local ds_vars loantype packageid log_facilityamt maturity rev_discount_1_simple spread
local ds_lender_vars lenderrole bankallocation lead_arranger_credit agent_credit

local base_type sdc

if "`base_type'" == "sdc" {
	local base_dataset "$data_path/sdc_deal_bookrunner"
	local base_dataset_info "$data_path/sdc_all_clean"
	local id sdc_deal_id
}
else if "`base_type'" == "ds" {
	local base_dataset "$data_path/lender_facilityid_cusip6"
	local base_dataset_info "$data_path/stata_temp/dealscan_discounts_facilityid"
	local id facilityid
}

foreach subset_type in equity debt conv rev_loan term_loan other_loan {
	if "`subset_type'" == "equity" | "`subset_type'" == "debt" | "`subset_type'" == "conv" {
		local subset_deal_data "$data_path/sdc_all_clean"
		local subset_id sdc_deal_id
		local merge_vars `sdc_vars'
	}
	else if "`subset_type'" == "rev_loan" | "`subset_type'" == "term_loan" | "`subset_type'" == "other_loan" {
		local subset_deal_data "$data_path/stata_temp/dealscan_discounts_facilityid"
		local subset_id facilityid
		local merge_vars `ds_vars'
	}
	*Get the most recent matches
	merge 1:1 `id' lender using "$data_path/stata_temp/matches_sdc_`subset_type'", keep(1 3) nogen
	*Now rename the base `id' for mergin reasons
	rename `id' `id'_base
	*Now merge on the information from that past relationship (but first need to rename `subset_id'_`subset_type' to `subset_id'
	rename `subset_id'_`subset_type' `subset_id'
	*In order for merge to work, need to make it not be missing
	replace `subset_id' = -1 if mi(`subset_id')
	merge m:1 `subset_id' using `subset_deal_data', keepusing(`merge_vars') keep(1 3)
	*Generate an indicator for relationship_`subset_type'
	gen rel_`subset_type' = (_merge==3)
	drop _merge
	*Make them missing again
	replace `subset_id' = . if `subset_id'==-1
	*Rename all of the variables with the suffix _`subset_type'
	foreach var in `merge_vars' `subset_id' {
		rename `var' `var'_`subset_type'
	}
	*Need to rename `id'_base back to its original form
	rename `id'_base `id' 
}

*First get the list of biggest "lenders"
use "$data_path/sdc_deal_bookrunner", clear
bys lender: gen N = _N 
tab lender if N >500

use "$data_path/lender_facilityid_cusip6", clear
bys lender: gen N = _N 
tab lender if N >500

use "$data_path/lender_facilityid_cusip6", clear
append using "$data_path/sdc_deal_bookrunner"
bys lender: gen N = _N 
tab lender if N >500


/*
use "$data_path/sdc_all_clean", clear
isid sdc_deal_id
use "$data_path/stata_temp/dealscan_discounts_facilityid", clear
isid facilityid
use "$data_path/sdc_deal_bookrunner", clear
isid sdc_deal_id lender
use "$data_path/lender_facilityid_cusip6", clear
isid facilityid lender
*/
