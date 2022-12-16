*Do analysis of discounts and loan sizes/ proportions of loans that are revolvers
use "$data_path/dealscan_compustat_loan_level_with_loan_num", clear

estimates clear 
local i = 1
local cond `" if category == "Revolver""'


forval i = 1/8 {
	if `i' == 1 {
		local rhs log_total_package_amount 
	}
	if `i' == 2 {
		local rhs log_total_rev log_total_i_term  
	}
	if `i' == 3 {
		local rhs log_total_rev log_total_i_term log_total_package_amount
	}
	if `i' == 4 {
		local rhs prop_rev_total
	}
	if `i' == 5 {
		local rhs prop_rev_inst
	}
	if `i' == 6 {
		local rhs prop_rev_total prop_rev_inst
	}
	if `i' == 7 {
		local rhs prop_rev_inst log_total_rev log_total_i_term log_total_package_amount 
	}
	if `i' == 8 {
		local rhs prop_rev_total prop_rev_inst log_total_rev log_total_i_term log_total_package_amount
	}
	reghdfe discount_1_simple `rhs' `cond', a(date_quarterly) vce(cl borrowercompanyid)
	estadd local fe = "Date"
	estadd local disc "Rev"
	estimates store est`i'
	local ++i

}

*Make a table with the analysis
esttab est* using "$regression_output_path/discounts_loan_size_proportion.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
title("Discounts and Loan Sizes/ Proportions") scalars("fe Fixed Effects" "disc Discount Type") ///
addnotes("SEs clustered at firm level" "Proportion of Revolver Amt to Inst. Amt is winsorized at 95 percent.")	
