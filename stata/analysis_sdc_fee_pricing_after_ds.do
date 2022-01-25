*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

*Use the all possible relationships data
use "$data_path/sdc_dealscan_pairwise_5yrs_post_ds", clear
gen years_out = floor(days_from_ds_to_sdc/365.25)
replace years_out = 1 if years_out ==0
*Analyses
forval i = 1/5 {
	gen same_lender_years_out_`i' = (same_lender ==1 & years_out == `i')
}
*Make interactions between equity and debt
foreach type in term_loan rev_loan other_loan log_facilityamt {
	gen same_lender_`type' = same_lender*`type'
}

gen same_lender_discount = same_lender * rev_discount_1_simple
*E.g. regress loan pricing of dealscan loans on past SDC issuance
*Observation should be a dealscan lender x facility, regression is indicator of future issuance with t days on nothign, and then on discount
*Max vars are the DS variables  , last_vars are SDC variables(which don't change by obs)
local max_vars same_lender* spread rev_discount_* term_loan rev_loan other_loan ///
	log_facilityamt maturity
local last_vars equity debt conv gross_spread_perc log_proceeds
*The sample here is sdc lender x facilityid 
collapse (max) `max_vars' constant (last) `last_vars' ///
	, by(facilityid)


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

	foreach lhs in gross_spread_perc {
		reghdfe `lhs' same_lender `cond', a(constant) vce(robust)
		estadd local fe = "No"
		estimates store est`i'
		local ++i
		
		reghdfe `lhs' same_lender_years_out_2 same_lender_years_out_3 same_lender_years_out_4 same_lender_years_out_5 `cond', a(constant) vce(robust)
		estadd local fe = "No"
		estimates store est`i'
		local ++i

		reghdfe `lhs' same_lender same_lender_log_facilityamt log_proceeds `cond', a(constant) vce(robust)
		estadd local fe = "No"
		estimates store est`i'
		local ++i

		reghdfe `lhs' same_lender same_lender_log_facilityamt log_proceeds same_lender_discount `cond', a(constant) vce(robust)
		estadd local fe = "No"
		estimates store est`i'
		local ++i

		reghdfe `lhs' same_lender_log_facilityamt log_proceeds same_lender_discount `cond' & same_lender==1, a(constant) vce(robust)
		estadd local fe = "No"
		estimates store est`i'
		local ++i


	}

	esttab est* using "$regression_output_path/regressions_sdc_fees_after_ds_`type'.tex", replace b(%9.3f) se(%9.3f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
	title("Pricing of SDC Fees after Dealscan Loans -`type'") scalars("fe Fixed Effects" ) ///
	 addnotes("Robust SE" "Observation is SDC deal x lender")

}
