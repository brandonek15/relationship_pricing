*Make a graph of average discont over time, by type of discount - including
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
local rev_discount_simple (line discount_1_simple date_quarterly if category == "Revolver", color(orange) yaxis(1))
local rev_discount_controls (line discount_1_controls date_quarterly if category == "Revolver", color(red) yaxis(1))
local rev_discount_controls_np (line discount_1_controls_np date_quarterly if category == "Revolver", color(green) yaxis(1))

/*
tw  `recession' `rev_discount_simple' `rev_discount_controls' `term_discount_simple' `term_discount_controls' , ///
	legend(order(1 "Recession" 2 "Rev Disc (Simple)" 3 "Rev Disc (Controls)" 4 "Term Disc (Simple)"  5 "Term Disc (Controls)") rows(2)) ///
	title("Discounts Over Time")  ytitle("Mean Discount (bps)") 	
	
gr export "$figures_output_path/time_series_discount_mean_all_rev_term_paper.png", replace 
*/
*Make a simpler version

tw  `recession' `rev_discount_simple' `rev_discount_controls'  , ///
	legend(order(1 "Recession" 2 "Rev Disc (Simple)" 3 "Rev Disc (Controls)")) ///
	title("Discounts Over Time")  ytitle("Mean Discount (bps)") 	
	
gr export "$figures_output_path/time_series_discount_mean_all_rev.png", replace 

tw  `recession' `rev_discount_simple' `rev_discount_controls' `rev_discount_controls_np' , ///
	legend(order(1 "Recession" 2 "Rev Disc (Simple)" 3 "Rev Disc (Controls)" 4 "Rev Disc (Controls -NP)")) ///
	title("Discounts Over Time")  ytitle("Mean Discount (bps)") 	
	
gr export "$figures_output_path/time_series_discount_mean_all_rev_with_np.png", replace 


**** Customized distribution of discount graph - kdensity
use "$data_path/dealscan_compustat_loan_level", clear

local rev (kdensity  discount_1_simple if category == "Revolver", color(orange) bwidth(20)  lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))
local rev_controls (kdensity  discount_1_controls if category == "Revolver", color(red) bwidth(20)  lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))
local rev_controls_np (kdensity  discount_1_controls_np if category == "Revolver", color(green) bwidth(20)  lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))

twoway `rev' `rev_controls'  ///
, ytitle("Density",axis(1))  ///
 title("Kernel Density of Discount - Simple vs Controls",size(medsmall)) ///
graphregion(color(white))  xtitle("Discount") ///
legend(order(1 "Simple Revolving Discount" 2 "Residualized Revolving Discount")) ///
 note("" "Epanechnikov kernel with bandwidth 20")
graph export "$figures_output_path/discount_kdensity_simple_controls.png", replace

twoway `rev' `rev_controls' `rev_controls_np'  ///
, ytitle("Density",axis(1))  ///
 title("Kernel Density of Discount - Simple vs Controls vs Controls - Non Parametric",size(medsmall)) ///
graphregion(color(white))  xtitle("Discount") ///
legend(order(1 "Simple Revolving Discount" 2 "Residualized Revolving Discount" 3 "Residualized Revolving Discount - NP")) ///
 note("" "Epanechnikov kernel with bandwidth 20")
graph export "$figures_output_path/discount_kdensity_simple_controls_with_np.png", replace
