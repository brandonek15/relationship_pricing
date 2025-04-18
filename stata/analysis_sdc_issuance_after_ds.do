*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

*Use the all possible relationships data
use "$data_path/sdc_dealscan_pairwise_post_ds", clear
*Don't want to make it run this, but this is the identifier
*isid facilityid lender_dealscan lender_sdc sdc_deal_id

*We only want to keep the most recent match
sort facilityid days_from_ds_to_sdc
egen min_days_from_ds_to_sdc = min(days_from_ds_to_sdc), by(facilityid) 
br issuer facilityid sdc_deal_id lender_dealscan lender_sdc  same_lender term_loan rev_loan other_loan equity debt conv
keep if days_from_ds_to_sdc == min_days_from_ds_to_sdc

br facilityid lender_dealscan lender_sdc sdc_deal_id same_lender term_loan rev_loan other_loan equity debt conv
sort facilityid sdc_deal_id lender_dealscan

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

replace same_lender = same_lender *100

br lender_dealscan facilityid same_lender term_loan rev_loan other_loan equity debt conv
*Simple correlations
corr same_lender agent_credit
corr same_lender lead_arranger_credit
corr same_lender rev_discount_1_simple
corr same_lender spread
corr same_lender rev_discount_1_simple if lead_arranger_credit ==1 & rev_loan ==1
corr same_lender spread if lead_arranger_credit ==1


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

	reg same_lender `cond',  vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reg same_lender rev_loan term_loan other_loan `cond',  vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reg same_lender lead_arranger_credit agent_credit `cond',  vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reg same_lender loan_share `cond',  vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reg same_lender spread maturity log_facilityamt `cond',  vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reg same_lender rev_discount_1_simple `cond',  vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reg same_lender rev_loan term_loan other_loan lead_arranger_credit agent_credit ///
	loan_share spread maturity log_facilityamt  rev_discount_1_simple `cond',  vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	esttab est* using "$regression_output_path/regressions_likelihood_from_ds_to_sdc_`type'.tex", ///
	replace b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) ///
	title("Likelihood of future SDC issuance after Dealscan loan -`type'") scalars("fe Fixed Effects" ) ///
	addnotes("Robust SEs" "Observation is Dealscan facility x lender" "Same Lender is either 0 or 100 for readability of coeffs")

}
