*See what autocorrelations exist
use "$data_path/dealscan_compustat_lender_loan_level", clear
bys lender: gen N = _N 
*keep only largest 20 lenders
keep lender N
duplicates drop
gsort -N
keep if _n<=20
*store them as a local 
levelsof lender, local(lenders)
*Mark the 20 biggest lenders
use "$data_path/dealscan_compustat_lender_loan_level", clear
gen keep_obs = 0
foreach lend in `lenders' {
	replace keep_obs = 1 if lender == "`lend'"
}
keep if category == "Revolver" | category == "Bank Term"
keep if !mi(discount_1_simple) & keep_obs==1
collapse (sum) constant (mean) discount* , by(lender category date_quarterly)
encode lender, gen(lender_numeric)

label var discount_1_simple "Di-1-S"
label var discount_2_simple "Di-2-S"
label var discount_1_controls "Di-1-C"
label var discount_2_controls "Di-2-C"

estimates clear
local i =1

preserve
keep if category == "Revolver"
xtset lender_numeric date_quarterly
foreach lhs in discount_1_simple discount_1_controls discount_2_simple discount_2_controls { 
	reghdfe `lhs' L1.`lhs' L2.`lhs' L3.`lhs' L4.`lhs' if category == "Revolver", absorb(lender)
	estadd local fe = "Lender"
	estadd local sample = "Rev"
	estimates store est`i'
	local ++i
}
xtset, clear
restore

*Temp
*reghdfe discount_1_simple L.discount_1_simple L2.discount_1_simple L3.discount_1_simple L4.discount_1_simple  if category == "Revolver", absorb(lender)

preserve
keep if category == "Bank Term"
xtset lender_numeric date_quarterly
foreach lhs in discount_1_simple discount_1_controls discount_2_simple discount_2_controls { 
	reghdfe `lhs' L1.`lhs' L2.`lhs' L3.`lhs' L4.`lhs' if category == "Bank Term", absorb(lender)
	estadd local fe = "Lender"
	estadd local sample = "Term"
	estimates store est`i'
	local ++i
}
xtset, clear
restore

esttab est* using "$regression_output_path/discount_autocorr_lender.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
title("Discount Autocorrelations - Lender") scalars("fe Fixed Effects" "sample Sample") ///
addnotes("SEs clustered at firm level" "Sample are the 20 largest lead arrangers avg quarterly discount from 2000Q1-2020Q4")	

*Do similar exercise for SIC_2
use "$data_path/dealscan_compustat_loan_level", clear
collapse (sum) constant (mean) discount* , by(sic_2 category date_quarterly)

label var discount_1_simple "Di-1-S"
label var discount_2_simple "Di-2-S"
label var discount_1_controls "Di-1-C"
label var discount_2_controls "Di-2-C"

estimates clear
local i =1

preserve
keep if category == "Revolver"
xtset sic_2 date_quarterly
foreach lhs in discount_1_simple discount_1_controls discount_2_simple discount_2_controls { 
	reghdfe `lhs' L1.`lhs' L2.`lhs' if category == "Revolver", absorb(sic_2)
	estadd local fe = "SIC2"
	estadd local sample = "Rev"
	estimates store est`i'
	local ++i
}
xtset, clear
restore

preserve
keep if category == "Bank Term"
xtset sic_2 date_quarterly
foreach lhs in discount_1_simple discount_1_controls discount_2_simple discount_2_controls { 
	reghdfe `lhs' L1.`lhs' L2.`lhs' if category == "Bank Term", absorb(sic_2)
	estadd local fe = "SIC2"
	estadd local sample = "Term"
	estimates store est`i'
	local ++i
}
xtset, clear
restore

esttab est* using "$regression_output_path/discount_autocorr_sic_2.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
title("Discount Autocorrelations - Industries") scalars("fe Fixed Effects" "sample Sample") ///
addnotes("SEs clustered at firm level" "Sample are the avg quarterly discount for SIC_2s from 2000Q1-2020Q4")	

