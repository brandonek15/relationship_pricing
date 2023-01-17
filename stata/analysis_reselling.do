*Do some simple correlations of discounts with number of instittional lenders on the instittional loans
use "$data_path/dealscan_compustat_loan_level_with_loan_num", clear
winsor2 i_lender_count i_non_inst_lender_count i_institutional_lender_count, cuts (0 95) replace

gen i_share_i_lend_0_25 = i_share_institutional_lender>0 & i_share_institutional_lender <=.25
gen i_share_i_lend_25_50 = i_share_institutional_lender>.25 & i_share_institutional_lender <=.5
gen i_share_i_lend_50_100 = i_share_institutional_lender>.5 & i_share_institutional_lender <=1
label var i_share_i_lend_0_25 "Inst. Share = (0,0.25] for Inst. Loan"
label var i_share_i_lend_25_50 "Inst. Share = (.25,0.5] for Inst. Loan"
label var i_share_i_lend_50_100 "Inst. Share = (0.5,1] for Inst. Loan"

foreach type in rev b_term {
	
	if "`type'" == "rev" {
		local suffix 
		local cat "Revolver"
		local disc_type "Rev"
	}
	if "`type'" == "b_term" {
		local suffix "_b_term"
		local cat "Bank Term"
		local disc_type "Term"
	}

	estimates clear
	local i = 1

	reghdfe discount_1_simple i_lender_count if category == "`cat'", a(date_quarterly) vce(cl borrowercompanyid)
	estadd local fe = "Date"
	estadd local disc "`disc_type'"
	estimates store est`i'
	local ++i

	reghdfe discount_1_simple i_non_inst_lender_count i_institutional_lender_count if category == "`cat'", a(date_quarterly) vce(cl borrowercompanyid)
	estadd local fe = "Date"
	estadd local disc "`disc_type'"
	estimates store est`i'
	local ++i

	reghdfe discount_1_simple i_share_institutional_lender if category == "`cat'", a(date_quarterly) vce(cl borrowercompanyid)
	estadd local fe = "Date"
	estadd local disc "`disc_type'"
	estimates store est`i'
	local ++i

	reghdfe discount_1_simple i_non_inst_lender_count i_institutional_lender_count i_share_institutional_lender if category == "`cat'", a(date_quarterly) vce(cl borrowercompanyid)
	estadd local fe = "Date"
	estadd local disc "`disc_type'"
	estimates store est`i'
	local ++i

	reghdfe discount_1_simple i_non_inst_lender_count i_institutional_lender_count ///
	log_total_`type' log_total_i_term log_total_package_amount if category == "`cat'", a(date_quarterly) vce(cl borrowercompanyid)
	estadd local fe = "Date"
	estadd local disc "`disc_type'"
	estimates store est`i'
	local ++i

	reghdfe discount_1_simple i_non_inst_lender_count i_institutional_lender_count i_share_institutional_lender ///
	log_total_`type' log_total_i_term log_total_package_amount if category == "`cat'", a(date_quarterly) vce(cl borrowercompanyid)
	estadd local fe = "Date"
	estadd local disc "`disc_type'"
	estimates store est`i'
	local ++i

	*Make a table with the analysis
	esttab est* using "$regression_output_path/discounts_and_syndicate`suffix'.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
	title("Discounts and Institutional Involvement") scalars("fe Fixed Effects" "disc Discount Type") ///
	addnotes("SEs clustered at firm level" "Number of Lenders in Syndicate Winsorized at 95")	
}

/*
	reghdfe discount_1_simple i_non_inst_lender_count i_institutional_lender_count i_share_i_lend_* if category == "`cat'", a(date_quarterly) vce(cl borrowercompanyid)
	estadd local fe = "Date"
	estadd local disc "`disc_type'"
	estimates store est`i'
	local ++i

*/
