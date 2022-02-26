*Random stuff to explore data
use "$data_path/sdc_equity_clean", clear

bys cusip_6 date_quarterly (date_daily): gen N = _N

local collapse_vars sec_type
local max_vars ipo debt equity convertible
local last_vars issuer business_desc currency bookrunners all_managers
local sum_vars management_fee_dol underwriting_fee_dol selling_conc_dol ///
	reallowance_dol gross_spread_dol proceeds_local num_units
local mean_vars gross_spread_per_unit gross_spread_perc management_fee_perc underwriting_fee_perc ///
	selling_conc_perc reallowance_perc 
local weight_var proceeds_local

collapse (rawsum) `sum_vars' (max) `max_vars' (last) `last_vars' ///
	(mean) `mean_vars' [aweight=`weight_var'], by(cusip_6 date_quarterly)

foreach var in `sum_vars' `mean_vars' {
	replace `var' = . if `var' ==0
}

rename proceeds_local proceeds
*Most important variables: The gross spread_percent, gross_spread_dollar, the proceeds, the cusip_6 and the date_quarterly
*From here I have whether there is a deal (make an indicator for whether it gets merged on?
*And then I also have data on the "price" and the size
isid cusip_6 date_quarterly


*Todo, figure out how to deal with bookrunners? some sort of egen to combine information? Need to standardize names


use "$data_path/compustat_clean", clear
bys cusip_6 date_quarterly: gen N = _N

use "$data_path/dealscan_quarterly", clear

*

/* If I want to merge a different way
joinby borrowercompanyid date_quarterly using "$data_path/dealscan_facility_level", ///
unmatched(master) _merge(dealscan_merge_cat)
*Now I have a dataset that may have multiple observations for the same cusip_6 date_quarterly if there are multiple
*Facilities. It is a company x quarter x facility dataset
save "$data_path/merged_data_comp_quart_fac", replace

use "$data_path/merged_data_comp_quart", clear
sort cusip_6 date_quarterly
br merge_equity conm issuer_equity date_quarterly cusip_6 cusip cik public_equity private_equity withdrawn_equity
br conm issuer_equity cik date_quarterly merge_equity  cusip_6 borrowercompanyid  merge_dealscan
br merge_equity conm issuer_equity date_quarterly cusip_6 cusip cik public private withdrawn if merge_equity == 2
*/

*Start standardizing bookrunners
use "$data_path/sdc_debt_clean", clear
br issuer date_daily bookrunners all_managers bookrunner_*
sort bookrunner_1
br issuer date_daily bookrunners all_managers bookrunner_* if bookrunner_1 == "Ameritas"

*
use "$data_path/dealscan_facility_lender_level", clear


use "$data_path/dealscan_lender_level", clear
bys lender: gen N = _N

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
*/
*Do joinbys on the same dataset to make matches

use "$data_path/sdc_all_clean", clear
rename * *_copy
rename cusip_6_copy cusip_6

joinby cusip_6 using "$data_path/sdc_deal_bookrunner",unmatched(none)
*Cannot do this, has 222m observations (obviously we have duplicates but this is unreasonable)

*As inputs it will take the following:
*Number of lenders per deal
local n_lenders 20
*Get the skeleton dataset (sdc_deal_id x lender)
make_skeleton "ds" `n_lenders'

use "$data_path/sdc_deals_with_past_relationships_20", clear

/*
egen past_relationship = rowmax(rel_equity rel_debt rel_conv rel_rev_loan rel_term_loan rel_other_loan)
reg hire past_relationship
*/

gen rev_loan_discount_inter = 0
replace rev_loan_discount_inter = rev_discount_1_simple_rev_loan*rel_rev_loan if !mi(rev_discount_1_simple_rev_loan)
*br rev_loan_discount_inter rev_discount_1_simple_rev_loan rel_rev_loan

foreach type in all equity debt {

	if "`type'" == "equity" {
		local cond "if `type' ==1" 
	}
	if "`type'" == "debt" {
		local cond "if `type'==1" 
	}
	if "`type'" == "all" {
		local cond "if 1 ==1" 
	}
	estimates clear
	local i = 1

	reg hire rel* `cond'
	
	reg hire rel* rev_loan_discount_inter `cond'
	
}

*Make some figures
use "$data_path/sdc_deals_with_past_relationships_20", clear
gen count =1
*sort cusip_6 sdc_deal_id lender
collapse (sum) count (mean) rel_*, by(hire equity_base debt_base conv_base)
*

*Understand the discount
use "$data_path/stata_temp/dealscan_discounts_facilityid", clear
br borrowercompanyid date_quarterly packageid facilityid rev_loan rev_discount* ///
 allindrawn spread spread_2
br borrowercompanyid date_quarterly packageid facilityid rev_loan term_loan other_loan rev_discount* ///
spread if borrowercompanyid == 19196 & date_quarterly == tq(2003q2)

*Check to see if the first discount given to each firm is bigger than later ones?
use "$data_path/stata_temp/dealscan_discounts_facilityid", clear
keep if rev_loan ==1 & !mi(cusip_6)
bys cusip_6 (facilitystartdate): gen n = _n
bys cusip_6 (facilitystartdate): gen N = _N
sum rev_discount_1_simple if n ==1
sum rev_discount_1_simple if n >1

sum rev_discount_1_simple if n ==1 & N>1
sum rev_discount_1_simple if n >1 & N>1

reghdfe rev_discount_1_simple n, absorb(cusip_6)
reghdfe rev_discount_1_simple n, absorb(cusip_6 date_quarterly)
reghdfe rev_discount_2_simple n, absorb(cusip_6 date_quarterly)


*Make a simple graph of the average discount by observation num
collapse (mean) rev_discount*, by(n)
twoway line rev_discount_1_simple n

*Do other specifications
use "$data_path/sdc_deals_with_past_relationships_20", clear
egen past_relationship = rowmax(rel_equity rel_debt rel_conv rel_rev_loan rel_term_loan rel_other_loan)
gen constant = 1
egen cusip_6_lender = group(cusip_6 lender)
egen lender_relationship = group(lender past_relationship)
*Make a marker for which deal number for cusip_6 this is
bys cusip_6 lender (date_daily sdc_deal_id): gen cusip_6_deal_num = _n
*Intensive margin analyses
reg hire rel_*
br issuer cusip_6 lender date_daily sdc_deal_id cusip_6_deal_num debt equity conv

*Make hire 0 or 100 for readability
replace hire = hire*100

*Create some variables
foreach ds_type in rev_loan term_loan other_loan {

	foreach ds_inter_var in rev_discount_1_simple spread maturity log_facilityamt ///
	agent_credit lead_arranger_credit bankallocation days_after_match {

	
		if "`ds_type'" == "rev_loan" {
			local type_name "rev"
		}
		if "`ds_type'" == "term_loan" {
			local type_name "term"
		}
		if "`ds_type'" == "other_loan" {
			local type_name "other"
		}
	
		gen i_`ds_inter_var'_`type_name' = 0
		replace i_`ds_inter_var'_`type_name' = `ds_inter_var'_`ds_type'*rel_`ds_type' if !mi(`ds_inter_var'_`ds_type')
		gen mi_`ds_inter_var'_`type_name' = mi(`ds_inter_var'_`ds_type')
	}

}

foreach sdc_type in debt equity conv {

	foreach sdc_inter_var in log_proceeds gross_spread_perc days_after_match {

		local type_name `sdc_type'
		
		gen i_`sdc_inter_var'_`type_name' = 0
		replace i_`sdc_inter_var'_`type_name' = `sdc_inter_var'_`sdc_type'*rel_`sdc_type' if !mi(`sdc_inter_var'_`sdc_type')
		gen mi_`sdc_inter_var'_`type_name' = mi(`sdc_inter_var'_`sdc_type')
	}

} 

*Get the first company observation such that a previous revolving relationship exists
bys cusip_6 lender rel_rev_loan (date_daily sdc_deal_id): gen cusip_6_deal_num_rel_rev_loan = _n
local absorb constant
local rhs rel_* i_maturity_* i_log_facilityamt_* i_spread_* i_rev_discount_1_simple* mi_rev_discount_1_simple* ///
	i_agent_credit_* i_lead_arranger_* i_bankallocation_* mi_bankallocation_*
*reghdfe hire `rhs' if cusip_6_deal_num_rel_rev_loan==1 & rel_rev_loan ==1, absorb(`absorb') vce(robust)
*local rhs rel_* i_rev_discount_1_simple* mi_rev_discount_1_simple*
reghdfe hire `rhs' , absorb(`absorb') vce(robust)

*
use "$data_path/ds_lending_with_past_relationships_20", clear
reghdfe log_facilityamt_base rel_* spread_base if rev_loan_base ==1 & hire !=0, absorb(constant) vce(robust)
