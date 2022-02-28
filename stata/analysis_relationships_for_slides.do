*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

use "$data_path/sdc_deals_with_past_relationships_20", clear
append using "$data_path/ds_lending_with_past_relationships_20"

egen sdc_obs = rowmax(equity_base debt_base conv_base)
egen ds_obs = rowmax(rev_loan_base term_loan_base other_loan_base)

*Past relationship and future pricing
*Six specifications (discount on any past relationship, then add lender FE and then split up by type of relationship, for discount and spread)
local drop_add 

estimates clear
local i = 1
foreach lhs in rev_discount_1_simple_base spread_base {

	if "`lhs'" == "spread_base" {
		local rhs_add maturity_base log_facilityamt_base
	}
	
	reghdfe `lhs' past_relationship `rhs_add' `cond' if rev_loan_base ==1 & hire !=0 , absorb(constant) vce(robust)
	estadd local fe = "None"
	estadd local sample = "Rev Loan"
	estimates store est`i'
	local ++i
	reghdfe `lhs' past_relationship `rhs_add' `cond' if rev_loan_base ==1 & hire !=0, absorb(lender) vce(robust)
	estadd local fe = "Lender"
	estadd local sample = "Rev Loan"
	estimates store est`i'
	local ++i
	reghdfe `lhs' rel_* `rhs_add' `cond' if rev_loan_base ==1 & hire !=0, absorb(lender) vce(robust)
	estadd local fe = "Lender"
	estadd local sample = "Rev Loan"
	estimates store est`i'
	local ++i

}

esttab est* using "$regression_output_path/regressions_exten_pricing_rel_rev_discount_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Pricing/Discounts after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Observation is DS loan x lender" "Sample is DS revolving loans x lender on loan" "Robust SEs" )

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
	
	reghdfe hire `rhs' `cond', absorb(`absorb') vce(robust)
	estadd local fe = "`fe_local'"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}

esttab est* using "$regression_output_path/regressions_inten_baseline_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Likelihood of hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" ///
"Hire indicator either 0 or 100 for readability" "Robust SEs" )

*Past discounts and future business
local rhs rel_* i_rev_discount_1_simple* mi_rev_discount_1_simple* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* 
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
	
	reghdfe hire `rhs' `cond', absorb(`absorb') vce(robust)
	estadd local fe = "`fe_local'"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}

esttab est* using "$regression_output_path/regressions_inten_ds_chars_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Likelihood of hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Table suppresses past relationship indicators and Other Loan characteristics"  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" ///
"Hire indicator either 0 or 100 for readability" "Robust SEs" )

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
	
	reghdfe `lhs' rel_* `rhs_add' `cond', absorb(constant) vce(robust)
	estadd local fe = "None"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}


esttab est* using "$regression_output_path/regressions_exten_pricing_rel_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Pricing/Discounts after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Observation is DS loan x lender or SDC deal x lender" "Sample is DS loans/SDC deal x lender on loan/deal" "Robust SEs" )


*Look at price recouping (look at previous discounts and fees charged)
local rhs rel_* i_rev_discount_1_simple* mi_rev_discount_1_simple* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* 
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
	
	reghdfe `lhs' `rhs' `rhs_add' `cond', absorb(constant) vce(robust)
	estadd local fe = "None"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}


esttab est* using "$regression_output_path/regressions_exten_pricing_ds_chars_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Pricing After Previous Loan Characteristics") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Table suppresses past relationship indicators and Other Loan characteristics" ///
  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" "Robust SEs" )

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
	
	reghdfe hire `rhs' `cond', absorb(constant) vce(robust)
	estadd local fe = "None"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}


esttab est* using "$regression_output_path/regressions_inten_ds_lender_type_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Likelihood of hiring after relationships - Lender Type") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Table suppresses past relationship indicators and Other Loan characteristics"  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" ///
"Hire indicator either 0 or 100 for readability" "Robust SEs" )
