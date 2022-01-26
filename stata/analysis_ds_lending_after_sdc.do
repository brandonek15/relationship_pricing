*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

*Use the all possible relationships data
use "$data_path/sdc_dealscan_pairwise_5yrs_post_sdc", clear

*Analyses
*E.g. regress any future DS issuance on whether the lender of the loan is the bookrunner of the sdc issuance
*Observation should be a dealscan lender x facility, regression is indicator of future issuance with t days on nothign, and then on discount
*Max vars are the DS variables, last_vars are the SDC variables (which don't change by obs)
local max_vars same_lender rev_discount_* agent_credit lead_arranger_credit term_loan rev_loan other_loan 
local last_vars equity debt conv log_proceeds gross_spread_dol gross_spread_perc
*The sample here is sdc lender x facilityid 
collapse (max) `max_vars' constant (last) `last_vars' ///
	, by(lender_sdc sdc_deal_id)

replace same_lender = same_lender *100


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

	reg same_lender `cond',  vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reg same_lender debt equity `cond',  vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reg same_lender lead_arranger_credit agent_credit `cond',  vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reg same_lender log_proceeds gross_spread_perc `cond',  vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reg same_lender rev_discount_1_simple `cond',  vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reg same_lender debt equity lead_arranger_credit agent_credit ///
	log_proceeds gross_spread_perc rev_discount_1_simple `cond',  vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	esttab est* using "$regression_output_path/regressions_likelihood_from_sdc_to_ds_`type'.tex", ///
	replace b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) ///
	title("Likelihood of receiving a Dealscan Loan after SDC issuance - `type'") scalars("fe Fixed Effects" ) ///
	 addnotes("Robust SE" "Observation is SDC deal x lender" "Same Lender is either 0 or 100 for readability of coeffs")

}
