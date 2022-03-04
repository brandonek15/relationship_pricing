*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

use "$data_path/sdc_deals_with_past_relationships_20", clear
append using "$data_path/ds_lending_with_past_relationships_20"

egen sdc_obs = rowmax(equity_base debt_base conv_base)
egen ds_obs = rowmax(rev_loan_base term_loan_base other_loan_base)
*Date quarterly
gen date_quarterly = qofd(date_daily)
format date_quarterly %tq

winsor2 rev_*, replace cut(1 99)

foreach ds_type in rev_loan term_loan other_loan {

	local rel_label : variable label rel_`ds_type'

	gen i_discount_1_pos_`ds_type' = discount_1_simple_`ds_type'>10e-6 & !mi(discount_1_simple_`ds_type')
	label var i_discount_1_pos_`ds_type' "`rel_label' X Disc+"
	gen mi_discount_1_pos_`ds_type' = mi(discount_1_simple_`ds_type')

}

*Create a positive discount indicator 
gen discount_1_pos_base = discount_1_simple_base >10e-6
replace discount_1_pos_base = . if mi(discount_1_simple_base)
label var discount_1_pos_base "Disc+"

*Past relationship and future pricing
*Six specifications (discount on any past relationship, then add lender FE and then split up by type of relationship, for discount and spread)
*Figure out how to incorporate term loan disocunts
local drop_add 

estimates clear
local i = 1
foreach lhs in discount_1_simple_base spread_base /*discount_1_pos_base*/ {

	if "`lhs'" == "spread_base" {
		local rhs_add maturity_base log_facilityamt_base
	}
	
	reghdfe `lhs' past_relationship `rhs_add' `cond' if rev_loan_base ==1 & hire !=0 , absorb(date_quarterly) vce(cl cusip_6)
	estadd local fe = "Time"
	estadd local sample = "Rev Loan"
	estimates store est`i'
	local ++i
	reghdfe `lhs' past_relationship `rhs_add' `cond' if rev_loan_base ==1 & hire !=0, absorb(date_quarterly lender) vce(cl cusip_6)
	estadd local fe = "Time,Len"
	estadd local sample = "Rev Loan"
	estimates store est`i'
	local ++i
	reghdfe `lhs' rel_* `rhs_add' `cond' if rev_loan_base ==1 & hire !=0, absorb(date_quarterly lender) vce(cl cusip_6)
	estadd local fe = "Time,Len"
	estadd local sample = "Rev Loan"
	estimates store est`i'
	local ++i

}

esttab est* using "$regression_output_path/regressions_exten_pricing_rel_discount_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Pricing/Discounts after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Observation is DS loan x lender" "Sample is DS revolving loans x lender on loan" "SEs clustered at firm level" )

*Simple past relationship table
local rhs rel_* 
local drop_add 
local absorb constant
local fe_local "None"

estimates clear
local i = 1

foreach type in all_sdc all_ds equity debt term rev {

	if "`type'" == "all_sdc" {
		local cond "if sdc_obs==1" 
	}
	if "`type'" == "all_ds" {
		local cond "if ds_obs==1" 
	}
	if "`type'" == "equity" {
		local cond "if `type' ==1" 
	}
	if "`type'" == "debt" {
		local cond "if `type' ==1" 
	}
	if "`type'" == "term" {
		local cond "if `type'_loan ==1" 
	}
	if "`type'" == "rev" {
		local cond "if `type'_loan ==1" 
	}
	
	reghdfe hire `rhs' `cond', absorb(`absorb') vce(cl cusip_6)
	estadd local fe = "`fe_local'"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}

esttab est* using "$regression_output_path/regressions_inten_baseline_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Likelihood of hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" ///
"Hire indicator either 0 or 100 for readability" "SEs clustered at firm level" )

*Past discounts and future business
local rhs rel_*  i_discount_1_simple* mi_discount_1_simple* /* i_discount_1_pos* mi_discount_1_pos* */ i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* 
local drop_add mi_* rel_* *_other
local absorb constant
local fe_local "None"

estimates clear
local i = 1

foreach type in all_sdc all_ds equity debt term rev {

	if "`type'" == "all_sdc" {
		local cond "if sdc_obs==1" 
	}
	if "`type'" == "all_ds" {
		local cond "if ds_obs==1" 
	}
	if "`type'" == "equity" {
		local cond "if `type' ==1" 
	}
	if "`type'" == "debt" {
		local cond "if `type' ==1" 
	}
	if "`type'" == "term" {
		local cond "if `type'_loan ==1" 
	}
	if "`type'" == "rev" {
		local cond "if `type'_loan ==1" 
	}
	
	reghdfe hire `rhs' `cond', absorb(`absorb') vce(cl cusip_6)
	estadd local fe = "`fe_local'"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}

esttab est* using "$regression_output_path/regressions_inten_ds_chars_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Likelihood of hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Table suppresses past relationship indicators and Other Loan characteristics"  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" ///
"Hire indicator either 0 or 100 for readability" "SEs clustered at firm level" )

*Look at pricing after previous relationship (sprd and SDC fee) 
local drop_add 
estimates clear
local i = 1

foreach type in all_sdc all_ds equity debt term rev {

	if "`type'" == "all_sdc" {
		local cond "if sdc_obs==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "equity" {
		local cond "if `type'_base ==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "debt" {
		local cond "if `type'_base ==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "all_ds" {
		local cond "if ds_obs==1" 
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	if "`type'" == "term" {
		local cond "if `type'_loan_base ==1" 
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	if "`type'" == "rev" {
		local cond "if `type'_loan_base ==1"
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	
	reghdfe `lhs' rel_* `rhs_add' `cond' & hire !=0, absorb(date_quarterly) vce(cl cusip_6)
	estadd local fe = "Time"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}


esttab est* using "$regression_output_path/regressions_exten_pricing_rel_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Pricing/Discounts after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Observation is DS loan x lender or SDC deal x lender" "Sample is DS loans/SDC deal x lender on loan/deal" "SEs clustered at firm level" )


*Look at price recouping (look at previous discounts and fees charged)
local rhs rel_* i_discount_1_simple* mi_discount_1_simple* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* 
local drop_add mi_* rel_* *_other
local absorb constant
local fe_local "None"

estimates clear
local i = 1

foreach type in all_sdc all_ds equity debt term rev {

	if "`type'" == "all_sdc" {
		local cond "if sdc_obs==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "equity" {
		local cond "if `type'_base ==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "debt" {
		local cond "if `type'_base ==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "all_ds" {
		local cond "if ds_obs==1" 
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	if "`type'" == "term" {
		local cond "if `type'_loan_base ==1" 
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	if "`type'" == "rev" {
		local cond "if `type'_loan_base ==1"
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	
	reghdfe `lhs' `rhs' `rhs_add' `cond' & hire !=0, absorb(date_quarterly) vce(cl cusip_6)
	estadd local fe = "Time"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}


esttab est* using "$regression_output_path/regressions_exten_pricing_ds_chars_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Pricing After Previous Loan Characteristics") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Table suppresses past relationship indicators and Other Loan characteristics" ///
  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" "SEs clustered at firm level" )

*Type of lender and likelihood of hiring
local rhs rel_* i_agent_credit_* i_lead_arranger_* i_bankallocation_* mi_bankallocation_*
local drop_add mi_* rel_* *_other
local absorb constant
local fe_local "None"

estimates clear
local i = 1

foreach type in all_sdc all_ds equity debt term rev {

	if "`type'" == "all_sdc" {
		local cond "if sdc_obs==1" 
	}
	if "`type'" == "equity" {
		local cond "if `type'_base ==1" 
	}
	if "`type'" == "debt" {
		local cond "if `type'_base ==1" 
	}
	if "`type'" == "all_ds" {
		local cond "if ds_obs==1" 
	}
	if "`type'" == "term" {
		local cond "if `type'_loan_base ==1" 
	}
	if "`type'" == "rev" {
		local cond "if `type'_loan_base ==1"
	}
	
	reghdfe hire `rhs' `cond', absorb(constant) vce(cl cusip_6)
	estadd local fe = "None"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}


esttab est* using "$regression_output_path/regressions_inten_ds_lender_type_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Likelihood of hiring after relationships - Lender Type") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Table suppresses past relationship indicators and Other Loan characteristics"  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" ///
"Hire indicator either 0 or 100 for readability" "SEs clustered at firm level" )
