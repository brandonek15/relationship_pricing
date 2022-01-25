
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
