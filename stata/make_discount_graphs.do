
use "$data_path/stata_temp/dealscan_discounts.dta", clear
set scheme david4

label var rev_discount_1_simple "Discount 1 (No Controls)"
label var rev_discount_1_controls "Discount 1 (w. Controls)"
label var rev_discount_2_simple "Discount 2 (No Controls)"
label var rev_discount_2_controls "Discount 2 (w. Controls)"

* Correlation between Different Measures 
graph drop _all
local i = 0
foreach var1 of varlist rev* {
	foreach var2 of varlist rev* {
		if "`var1'" != "`var2'" {
			di "`var1' `var2'"
			local i = `i' + 1
			scatter `var1' `var2' , name(g`i') 
			local graphs "`graphs' g`i'"
		}
	}
}



gr combine `graphs', col(3) xcommon ycommon title("Discount Measures")
gr export "$figures_output_path/discount_corr.pdf", as(pdf) replace

* Time Series of Different Measures

use "$data_path/stata_temp/dealscan_discounts.dta", clear

collapse (mean) rev_*  , by(date_quarterly)


preserve
	freduse USRECM, clear
	gen date_quarterly = qofd(daten)
	collapse (max) USRECM, by(date_quarterly)
	keep date_quarterly USRECM
	tempfile rec
	save `rec', replace
restore

joinby date_quarterly using `rec', unmatched(master)
egen y = rowmax(rev*)
qui su y
replace USRECM = `r(max)'*USRECM*1.05

tw  (bar USRECM date_quarterly, color(gs14) lcolor(none)) ///
(line rev* date_quarterly, ///
	legend(order(1 "Recession" 2 "1 (Simple)" 3 "1 (Controls)" 4 "2 (Simple)"  5 "2 (Controls)"))) ///
	, title("Discount Procyclicality")  ytitle("Mean Discount (bps)") 
	
gr export "$figures_output_path/time_series_discount.pdf", as(pdf) replace 


