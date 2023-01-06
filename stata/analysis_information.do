*Look at how ratings are correlated with discounts
use "$data_path/dealscan_compustat_loan_level_with_loan_num", clear

local content `"discount_1_simple rating_numeric if category == "Revolver""'
corr `content'
local corr = round(r(rho),.01)
reg `content'
local beta = _b[rating_numeric]
scatter `content'

twoway (scatter `content') (lfit `content') ///
, ytitle("Discount",axis(1))  ///
 title("Discounts and Ratings - Rev",size(medsmall)) ///
graphregion(color(white))  xtitle("Ratings Numeric") ///
 note("Ratings on a Numeric Scale: 1 = AAA, 22=D""Correlation: `corr', beta on regression: `beta'")
gr export "$figures_output_path/ratings_discount_1_simple_rev.png", replace 


binscatter `content' ///
, ytitle("Discount",axis(1))  ///
 title("Discounts and Ratings - Rev",size(medsmall)) ///
graphregion(color(white))  xtitle("Ratings Numeric") ///
 note("Ratings on a Numeric Scale: 1 = AAA, 22=D""Correlation: `corr', beta on regression: `beta'")
gr export "$figures_output_path/ratings_discount_1_simple_binscatter_rev.png", replace 
