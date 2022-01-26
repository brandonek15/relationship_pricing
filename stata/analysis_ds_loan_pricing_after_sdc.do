*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

*Use the all possible relationships data
use "$data_path/sdc_dealscan_pairwise_5yrs_post_sdc", clear
gen years_out = -floor(days_from_ds_to_sdc/365.25)
replace years_out = 1 if years_out ==0
*Analyses
forval i = 1/5 {
	gen same_lender_years_out_`i' = (same_lender ==1 & years_out == `i')
}
*Make interactions between equity and debt
foreach type in equity debt conv {
	gen same_lender_`type' = same_lender*`type'
}
*E.g. regress loan pricing of dealscan loans on past SDC issuance
*Observation should be a dealscan lender x facility, regression is indicator of future issuance with t days on nothign, and then on discount
*Max vars are the SDC variables , last_vars are DS variables (which don't change by obs)
local max_vars same_lender* equity debt conv
local last_vars spread rev_discount_* term_loan rev_loan other_loan ///
	log_facilityamt maturity
*The sample here is sdc lender x facilityid 
collapse (max) `max_vars' constant (last) `last_vars' ///
	, by(facilityid)


foreach type in all term rev {

	if "`type'" == "term" {
		local cond "if `type'_loan ==1" 
	}
	if "`type'" == "rev" {
		local cond "if `type'_loan ==1" 
	}
	if "`type'" == "all" {
		local cond "" 
	}
	estimates clear
	local i = 1

	foreach lhs in spread rev_discount_1_simple {
		reg `lhs' same_lender `cond',  vce(robust)
		estadd local fe = "No"
		estimates store est`i'
		local ++i
		
		reg `lhs' same_lender_equity same_lender_debt same_lender_conv `cond',  vce(robust)
		estadd local fe = "No"
		estimates store est`i'
		local ++i

		reg `lhs' same_lender_years_out_2 same_lender_years_out_3 same_lender_years_out_4 same_lender_years_out_5 `cond',  vce(robust)
		estadd local fe = "No"
		estimates store est`i'
		local ++i

		reg `lhs' same_lender log_facilityamt maturity `cond',  vce(robust)
		estadd local fe = "No"
		estimates store est`i'
		local ++i

	}

	esttab est* using "$regression_output_path/regressions_ds_pricing_after_sdc_`type'.tex", ///
	 replace b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) ///
	title("Pricing of Dealscan Loans after SDC issuance -`type'") scalars("fe Fixed Effects" ) ///
	 addnotes("Robust SE" "Observation is SDC deal x lender")

}
