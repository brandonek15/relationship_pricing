*Make a do file with all of the figures for the paper (and slides, why not).

*Split up the dealscan loans into how many packages have each combination
use "$data_path/dealscan_compustat_loan_level", clear
*br if borrowercompanyid == 11649 & date_quarterly == tq(2007q3)
drop if category == "Other"
gen rev_loan_cat = (category == "Revolver")
gen bank_term_loan_cat = (category == "Bank Term")
gen inst_term_loan_cat = (category == "Inst. Term")
collapse (sum) facilityamt (max) *_cat, by(borrowercompanyid date_quarterly merge_compustat)
isid borrowercompanyid date_quarterly
gen package_type = ""
replace package_type = "Only Revolver" if rev_loan_cat ==1 & bank_term_loan_cat ==0 & inst_term_loan_cat ==0
replace package_type = "Only Bank Term" if rev_loan_cat ==0 & bank_term_loan_cat ==1 & inst_term_loan_cat ==0
replace package_type = "Only Inst. Term" if rev_loan_cat ==0 & bank_term_loan_cat ==0 & inst_term_loan_cat ==1
replace package_type = "Rev + Bank Term" if rev_loan_cat ==1 & bank_term_loan_cat ==1 & inst_term_loan_cat ==0
replace package_type = "Rev + Inst. Term" if rev_loan_cat ==1 & bank_term_loan_cat ==0 & inst_term_loan_cat ==1
replace package_type = "Bank Term + Inst. Term" if rev_loan_cat ==0 & bank_term_loan_cat ==1 & inst_term_loan_cat ==1
replace package_type = "Rev + Bank Term + Inst. Term" if rev_loan_cat ==1 & bank_term_loan_cat ==1 & inst_term_loan_cat ==1
drop if mi(package_type)
*Specify order
gen order = .
replace order = 1 if package_type == "Only Revolver"
replace order = 2 if package_type == "Only Bank Term"
replace order = 3 if package_type == "Only Inst. Term"
replace order = 4 if package_type == "Rev + Bank Term"
replace order = 5 if package_type == "Rev + Inst. Term"
replace order = 6 if package_type == "Bank Term + Inst. Term"
replace order = 7 if package_type == "Rev + Bank Term + Inst. Term"

qui sum rev_loan_cat
local num_obs = `r(N)'

graph pie, over(package_type) ///
allcategories sort(order) ///
	 graphregion(color(white)) title("Distribution of Loans Packages") ///
	  note("Number of Packages: `num_obs'" "Loans to the same firm in the same quarter considered to be in the same package" "Not including other categories of loans") legend(rows(2))
	graph export "$figures_output_path/package_type_pie_paper.png", replace

graph pie [aweight=facilityamt], over(package_type) ///
allcategories sort(order) ///
	 graphregion(color(white)) title("Distribution of Loans Packages - Weighted by Loan Amount") ///
	  note("Number of Packages: `num_obs'" "Loans to the same firm in the same quarter considered to be in the same package" "Not including categories of loans") legend(rows(2))
	graph export "$figures_output_path/package_type_pie_wtd.png", replace


*Make a graph of average discont over time, by type of discount

use "$data_path/dealscan_compustat_loan_level", clear
drop if other_loan ==1
*Get a sample to keep. Keep if you have an institutional loan and either a rev loan or term loan
gen inst_term = category== "Inst. Term"
gen noninst_term = category == "Bank Term"
egen  rev_loan_max = max(rev_loan), by(borrowercompanyid date_quarterly)
egen  inst_term_max = max(inst_term), by(borrowercompanyid date_quarterly)
egen  noninst_term_max = max(noninst_term), by(borrowercompanyid date_quarterly)
keep if inst_term_max ==1 & (rev_loan_max==1 | noninst_term_max==1)

*Keep only pe of loan per category
bys borrowercompanyid date_quarterly category: keep if _n ==1

collapse (mean) discount_* spread, by(date_quarterly category)


preserve
	freduse USRECM BAMLC0A4CBBB BAMLC0A1CAAA, clear
	gen date_quarterly = qofd(daten)
	collapse (max) USRECM , by(date_quarterly)
	tsset date_quarterly
	keep date_quarterly USRECM 
	tempfile rec
	save `rec', replace
restore

joinby date_quarterly using `rec', unmatched(master)
egen y = rowmax(discount_*)
qui su y
replace USRECM = `r(max)'*USRECM*1.05

*Make the same graph for both term and revolver loans, but only the first
local recession (bar USRECM date_quarterly, color(gs14) lcolor(none))
local rev_discount_simple (line discount_1_simple date_quarterly if category == "Revolver", color(midblue) yaxis(1))
local rev_discount_controls (scatter discount_1_controls date_quarterly if category == "Revolver", mcolor(midblue) msymbol(triangle) msize(small) yaxis(1))
local term_discount_simple (line discount_1_simple date_quarterly if category == "Bank Term", col(orange) yaxis(1))
local term_discount_controls(scatter discount_1_controls date_quarterly if category == "Bank Term", msymbol(triangle) msize(small) mcolor(orange) yaxis(1))


tw  `recession' `rev_discount_simple' `rev_discount_controls' `term_discount_simple' `term_discount_controls' , ///
	legend(order(1 "Recession" 2 "Rev Disc (Simple)" 3 "Rev Disc (Controls)" 4 "Term Disc (Simple)"  5 "Term Disc (Controls)") rows(2)) ///
	title("Discounts Over Time")  ytitle("Mean Discount (bps)") 	
	
gr export "$figures_output_path/time_series_discount_mean_all_rev_term_paper.png", replace 



**** Customized distribution of discount graph - kdensity
use "$data_path/dealscan_compustat_loan_level", clear

local rev (kdensity  discount_1_simple if category == "Revolver", color(midblue) bwidth(20)  lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))
local b_term (kdensity discount_1_simple if category == "Bank Term", col(orange) bwidth(20) lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))
local rev_controls (kdensity  discount_1_controls if category == "Revolver", color(blue) bwidth(20)  lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))

twoway `rev' `b_term'  ///
, ytitle("Density",axis(1))  ///
 title("Kernel Density of Discount - Revolving vs Bank Term",size(medsmall)) ///
graphregion(color(white))  xtitle("Discount") ///
legend(order(1 "Revolving Discount" 2 "Bank Term Discount")) ///
 note("" "Epanechnikov kernel with bandwidth 20")
graph export "$figures_output_path/discount_kdensity_rev_term_paper.png", replace

twoway `rev' `rev_controls'  ///
, ytitle("Density",axis(1))  ///
 title("Kernel Density of Discount - Simple vs Controls",size(medsmall)) ///
graphregion(color(white))  xtitle("Discount") ///
legend(order(1 "Simple Revolving Discount" 2 "Residualized Revolving Discount")) ///
 note("" "Epanechnikov kernel with bandwidth 20")
graph export "$figures_output_path/discount_kdensity_simple_controls_paper.png", replace

*Make one where include overlap only
gen not_mi_discount = !mi(discount_1_simple)
egen max_not_mi_discount_rev_t = max(not_mi_discount) if category == "Revolver", by(borrowercompanyid date_quarterly)
egen max_not_mi_discount_term_t = max(not_mi_discount) if category == "Bank Term", by(borrowercompanyid date_quarterly)
egen max_not_mi_discount_rev = mean(max_not_mi_discount_rev_t), by(borrowercompanyid date_quarterly)
egen max_not_mi_discount_term = mean(max_not_mi_discount_term_t), by(borrowercompanyid date_quarterly)
*br borrowercompanyid date_quarterly category discount_1_simple max_not* 
keep if max_not_mi_discount_rev ==1 & max_not_mi_discount_term==1


local rev (kdensity  discount_1_simple if category == "Revolver" &max_not_mi_discount_rev ==1 & max_not_mi_discount_term==1, color(midblue) bwidth(20)  lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))
local b_term (kdensity discount_1_simple if category == "Bank Term" &max_not_mi_discount_rev ==1 & max_not_mi_discount_term==1, col(orange) bwidth(20) lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))

twoway `rev' `b_term'  ///
, ytitle("Density",axis(1))  ///
 title("Kernel Density of Discount - Revolving vs Bank Term - Packages with Both Discounts Only",size(medsmall)) ///
graphregion(color(white))  xtitle("Discount") ///
legend(order(1 "Revolving Discount" 2 "Bank Term Discount")) ///
 note("" "Epanechnikov kernel with bandwidth 20")
graph export "$figures_output_path/discount_kdensity_rev_term_both_packages_paper.png", replace


*See fraction 0 over time
use "$data_path/dealscan_compustat_loan_level", clear
keep if category == "Revolver" | category == "Bank Term"
keep if !mi(discount_1_simple)
gen zero_discount = abs(discount_1_simple)<10e-6
replace discount_1_simple = . if zero_discount
collapse (mean) zero_discount discount_1_simple, by(date_quarterly category)
twoway (line zero_discount date_quarterly if category == "Revolver") (line zero_discount date_quarterly if category == "Bank Term"), ///
ytitle("Fraction of Loans with Zero Discount") title("Fraction of Loans with Zero Discount", size(medsmall)) ///
		 note("`note'") ///
		graphregion(color(white))  xtitle("Quarter") ///
		legend(order(1 "Revolving Discount" 2 "Term Discount"))
		graph export "$figures_output_path/discount_frac_zero_paper.png", replace
		
		
*Alternative graph using coeff plot
*Split rev and term discount by loan number
use "$data_path/stata_temp/dealscan_discount_prev_lender", clear
keep if (category =="Revolver" | category == "Bank Term")  & !mi(borrowercompanyid) 
keep borrowercompanyid category facilitystartdate discount_1_simple first_loan prev_lender switcher_loan
duplicates drop
*In case there is a missing and a discount calculated, keep the not missing obs
bys borrowercompanyid category facilitystartdate first_loan prev_lender switcher_loan (discount_1_simple): keep if _n == 1

bys borrowercompanyid category (facilitystartdate): gen n = _n
bys borrowercompanyid category (facilitystartdate): gen N = _N

*Make a simple graph of the average discount by observation num
forval i = 1/10 {
	gen n_`i' = n == `i'
	label var n_`i' "Loan Num `i'"
}
reg discount_1_simple n_* if category == "Revolver", nocons
estimates store Rev
reg discount_1_simple n_* if category == "Bank Term", nocons
estimates store Term

coefplot (Rev, label(Revolving Discount) pstyle(p3)) (Term, label(Term Discount) pstyle(p4)) ///
, vertical ytitle("Discount") title("Regression Coefficient of Discount on Loan Number") ///
	graphregion(color(white))  xtitle("Discount Number") xlabel(, angle(45)) ///
	 note("Constant Omitted. Loan numbers greater than 10 omitted due to small sample (less than 10)") levels(90)
	gr export "$figures_output_path/discounts_across_loan_number_coeff_paper.png", replace 

*Also do tests to see if slope is indeed negative (only for Revolvers!)
gen count = 1
reghdfe discount_1_simple n if category == "Revolver", absorb(count)
reghdfe discount_1_simple n if category == "Bank Term", absorb(count)
reghdfe discount_1_simple n if category == "Revolver", absorb(borrowercompanyid)
reghdfe discount_1_simple n if category == "Bank Term", absorb(borrowercompanyid)
