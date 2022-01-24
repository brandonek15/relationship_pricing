*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

*Use the all possible relationships data
use "$data_path/sdc_dealscan_pairwise_5yrs_post_ds", clear

*Analyses
*E.g. regress any future SDC issuance on whether the bookrunner of the issuance
*Observation should be a dealscan lender x facility, regression is indicator of future issuance with t days on nothign, and then on discount
*Can seperate by whether the issuance is equity, debt, convertible
*Max vars are the SDC variables, last_vars are the Dealscan variables (which don't change by obs)
local max_vars same_lender equity debt conv  
local last_vars spread rev_discount_* loan_share maturity log_facilityamt  ///
	agent_credit lead_arranger_credit term_loan rev_loan other_loan
*The sample here is dealscan lender x facilityid 
collapse (max) `max_vars' constant (last) `last_vars' ///
	, by(lender_dealscan facilityid)


foreach type in all equity debt {

	if "`type'" == "equity" {
		local cond "if `type' ==1" 
	}
	if "`type'" == "debt" {
		local cond "if `type' ==1" 
	}
	if "`type'" == "all" {
		local cond "" 
	}
	estimates clear
	local i = 1

	reghdfe same_lender `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reghdfe same_lender rev_loan term_loan other_loan `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reghdfe same_lender lead_arranger_credit agent_credit `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reghdfe same_lender loan_share `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reghdfe same_lender spread maturity log_facilityamt `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reghdfe same_lender rev_discount_1_simple `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reghdfe same_lender rev_loan term_loan other_loan lead_arranger_credit agent_credit ///
	loan_share spread maturity log_facilityamt  rev_discount_1_simple `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	esttab est* using "$regression_output_path/regressions_likelihood_from_ds_to_sdc_`type'.tex", replace b(%9.3f) se(%9.3f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
	title("Likelihood of future SDC issuance after Dealscan loan -`type'") scalars("fe Fixed Effects" ) ///
	addnotes("Robust SEs" "Observation is Dealscan facility x lender")

}
