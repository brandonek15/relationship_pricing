
use "$data_path/dealscan_compustat_loan_level", clear
keep if category == "Revolver" | category == "Bank Term"
*Want the spreads to only be collapsed if they are used to calculate discounts
replace spread = . if category == "Revolver" & discount_obs_rev ==0
replace spread = . if category == "Bank Term" & discount_obs_b_term ==0

*Chart with loan size * discount time series
gen year = yofd(facilitystartdate)
gen dollar_discount = discount_1_simple * facilityamt/10000
collapse (sum) dollar_discount (mean) discount_1_simple spread (sd) spread_sd = spread, by(year category) 
replace dollar_discount = dollar_discount / 1000000
label var dollar_discount "Total Dollar Discount (Millions)"
replace dollar_discount = dollar_discount *.56 if category == "Revolver"
*For revolvers, average utilization is 56% so let's adjust that


drop if year <1990

local dol_discount_rev (line dollar_discount year if category == "Revolver", color(midblue) lpattern(solid) yaxis(1))
local dol_discount_term (line dollar_discount year if category == "Bank Term", col(orange) lpattern(solid) yaxis(1))

twoway `dol_discount_rev' `dol_discount_term' , ///
	legend(order(1 "Revolver Discount" 2 "Term Discount") size(medium)) xtitle("Year") ///
	title("Total Dollar Discounts Over Time") note("Total revolver dollar discount incorporates average utilization of 56 percent")  ytitle("Discount (Millions)", axis(1))
gr export "$figures_output_path/dollar_discounts_over_time.png", replace 

*Also want to do graphs of average discount / average spread and avg discount / sd(spread)
gen discount_ratio_mean_spread = discount_1_simple/spread
gen discount_ratio_sd_spread = discount_1_simple/spread_sd

local ratio_mean_rev (line discount_ratio_mean_spread year if category == "Revolver", color(midblue) lpattern(solid) yaxis(1))
local ratio_mean_term (line discount_ratio_mean_spread year if category == "Bank Term", col(orange) lpattern(solid) yaxis(1))

local ratio_sd_rev (line discount_ratio_sd_spread year if category == "Revolver", color(midblue) lpattern(dash) yaxis(1))
local ratio_sd_term (line discount_ratio_sd_spread year if category == "Bank Term", col(orange) lpattern(dash) yaxis(1))

twoway `ratio_mean_rev' `ratio_mean_term' , ///
	legend(order(1 "Revolver" 2 "Term") size(medium)) xtitle("Year") ///
	title("Avg Discount / Avg Spread") ytitle("Avg Discount / Avg Spread", axis(1))
gr export "$figures_output_path/avg_discounts_ratio_mean_over_time.png", replace 

twoway `ratio_sd_rev' `ratio_sd_term' , ///
	legend(order(1 "Revolver" 2 "Term") size(medium)) xtitle("Year") ///
	title("Avg Discount / SD Spread") ytitle("Avg Discount / SD Spread", axis(1))
gr export "$figures_output_path/avg_discounts_ratio_sd_over_time.png", replace 


