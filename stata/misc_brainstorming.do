*Do some analysis for N_book
*All daily dataset
use "$data_path/stata_temp/sdc_all_clean_temp", clear

*Create N_book variable for number of bookrunners
gen N_book = .
label var N_book "Num Book"

forvalues i = 26(-1)1 {
	
	if `i' == 26 {
		replace N_book = `i' if !mi(bookrunner_`i')
	}
	else  {
		replace N_book = `i' if !mi(bookrunner_`i') & mi(N_book)
	}

}

drop if bookrunner_1 == "NA" | bookrunner_1 == "TBD"

*Do the same for comanagers
split all_managers, gen(manager_) parse(",")
gen N_all_manager = .
label var N_all_manager "Num Managers"

forvalues i = 46(-1)1 {
	
	if `i' == 26 {
		replace N_all_manager = `i' if !mi(manager_`i')
	}
	else  {
		replace N_all_manager = `i' if !mi(manager_`i') & mi(N_all_manager)
	}

}

*Comanagers are everyone that is a manager but not bookrunner
gen N_all_comanager = N_all_manager - N_book
label var N_all_comanager "Num CoManagers"

*Make some graphs of n_book over time.
*Want raw N_book average over time (daily?)
gen category = ""
replace category = "Equity" if equity ==1
replace category = "Debt" if debt ==1
replace category = "Conv" if conv ==1

gen month = month(date_daily)
gen year = year(date_daily)

gen date_monthly = ym(year,month)
format date_monthly %tm

save "$data_path/stata_temp/sdc_all_with_N_book", replace

use "$data_path/stata_temp/sdc_all_with_N_book", clear

collapse (mean) N_book N_all_manager N_all_comanager proceeds , by(year category)

twoway line N_book year if category == "Equity"
twoway line N_book year if category == "Debt"

replace proceeds = proceeds/1000000000

*Want avg bookrunner / dollar over time
gen N_book_per_billion = N_book/ proceeds
gen N_manager_per_billion = N_all_comanager/ proceeds
gen N_comanager_per_billion = N_all_comanager/ proceeds

foreach N_type in N_book N_all_manager N_all_comanager N_book_per_billion N_manager_per_billion  N_comanager_per_billion proceeds {

	if "`N_type'" == "N_book" {
		local title "Avg Num of Bookrunners"
		local save_name "bookrunners_avg"
	}
	if "`N_type'" == "N_all_manager" {
		local title "Avg Num of Managers"
		local save_name "managers_avg"
	}
	if "`N_type'" == "N_all_comanager" {
		local title "Avg Num of Comanagers"
		local save_name "comanagers_avg"
	}
	if "`N_type'" == "N_book_per_billion" {
		local title "Avg Num of Bookrunners per Billion in Proceeds"
		local save_name "bookrunners_avg_per_billion"
	}
	if "`N_type'" == "N_manager_per_billion" {

		local title "Avg Num of Managers per Billion in Proceeds"
		local save_name "managers_avg_per_billion"
	}
	if "`N_type'" == "N_comanager_per_billion" {
		local title "Avg Num of Comanagers per Billion in Proceeds"
		local save_name "comanagers_avg_per_billion"
	}
	if "`N_type'" == "proceeds" {
		local title "Avg Proceeds (billions)"
		local save_name "proceeds_avg"
	}

	twoway line `N_type' year if category == "Equity" , ///
	ytitle("`title'") title("`title' over time for Equity Issuances", size(medsmall)) ///
	graphregion(color(white))  xtitle("Quarter")
	graph export "$figures_output_path/`save_name'_over_time_equity.png", replace

	twoway line `N_type' year if category == "Debt" , ///
	ytitle("`title'") title("`title' over time for Debt Issuances", size(medsmall)) ///
	graphregion(color(white))  xtitle("Quarter")
	graph export "$figures_output_path/`save_name'_over_time_debt.png", replace

}

twoway line N_book_per_billion year if category == "Equity"
twoway line N_book_per_billion year if category == "Debt"

twoway line proceeds year if category == "Equity"
twoway line proceeds year if category == "Debt"

*Do same for lead arrangers
use "$data_path/dealscan_facility_lender_level", clear
keep if lead_arranger_credit ==1
gen N_lead_arranger = 1
collapse (sum) N_lead_arranger, by(facilityid)
save "$data_path/stata_temp/N_lead_arranger_facilityid", replace

*Do same for all lenders
use "$data_path/dealscan_facility_lender_level", clear
gen N_lender = 1
collapse (sum) N_lender, by(facilityid)
save "$data_path/stata_temp/N_lender_facilityid", replace


*Now we have our equivalent of N_book
use "$data_path/stata_temp/dealscan_discounts_facilityid", clear
merge 1:1 facilityid using "$data_path/stata_temp/N_lead_arranger_facilityid", nogen
merge 1:1 facilityid using "$data_path/stata_temp/N_lender_facilityid", nogen

gen N_colender = N_lender - N_lead_arranger

gen year = year(facilitystartdate)

collapse (mean) N_lead_arranger N_lender N_colender facilityamt, by(year category)

replace facilityamt = facilityamt/1000000000

*Want avg bookrunner / dollar over time
gen N_lead_arranger_per_billion = N_lead_arranger/ facilityamt
gen N_lender_per_billion = N_lender/ facilityamt
gen N_colender_per_billion = N_colender/ facilityamt

drop if mi(N_lead_arranger)

keep if year >=2000

foreach N_type in N_lead_arranger N_lender N_colender N_lead_arranger_per_billion N_lender_per_billion N_colender_per_billion facilityamt {

	if "`N_type'" == "N_lead_arranger" {
		local title "Avg Num of Lead Arrangers"
		local save_name "lead_arrangers_avg"
	}
	if "`N_type'" == "N_lender" {
		local title "Avg Num of Lenders"
		local save_name "lenders_avg"
	}
	if "`N_type'" == "N_colender" {
		local title "Avg Num of Colenders"
		local save_name "colenders_avg"
	}
	if "`N_type'" == "N_lead_arranger_per_billion" {
		local title "Avg Num of Lead Arrangers per Billion in Facility"
		local save_name "lead_arrangers_avg_per_billion"
	}
	if "`N_type'" == "N_lender_per_billion" {

		local title "Avg Num of Lenders per Billion in Facility"
		local save_name "lenders_avg_per_billion"
	}
	if "`N_type'" == "N_colender_per_billion" {
		local title "Avg Num of Colenders per Billion in Facility"
		local save_name "colenders_avg_per_billion"
	}
	if "`N_type'" == "facilityamt" {
		local title "Avg Facility Amt (billions)"
		local save_name "facilityamt_avg"
	}

	twoway line `N_type' year  if category == "Revolver" , ///
	ytitle("`title'") title("`title' Over Time for Revolvers", size(medsmall)) ///
	graphregion(color(white))  xtitle("Quarter")
	graph export "$figures_output_path/`save_name'_over_time_rev.png", replace

	twoway line `N_type' year  if category == "Inst. Term" , ///
	ytitle("`title'") title("`title' Over Time for Institutional Term Loans", size(medsmall)) ///
	graphregion(color(white))  xtitle("Quarter")
	graph export "$figures_output_path/`save_name'_over_time_inst_term.png", replace

}
*Do some analysis for N_book
*All daily dataset
use "$data_path/stata_temp/sdc_all_clean_temp", clear

*Create N_book variable for number of bookrunners
gen N_book = .
label var N_book "Num Book"

forvalues i = 26(-1)1 {
	
	if `i' == 26 {
		replace N_book = `i' if !mi(bookrunner_`i')
	}
	else  {
		replace N_book = `i' if !mi(bookrunner_`i') & mi(N_book)
	}

}

drop if bookrunner_1 == "NA" | bookrunner_1 == "TBD"

*Do the same for comanagers
split all_managers, gen(manager_) parse(",")
gen N_all_manager = .
label var N_all_manager "Num Managers"

forvalues i = 46(-1)1 {
	
	if `i' == 26 {
		replace N_all_manager = `i' if !mi(manager_`i')
	}
	else  {
		replace N_all_manager = `i' if !mi(manager_`i') & mi(N_all_manager)
	}

}

*Comanagers are everyone that is a manager but not bookrunner
gen N_all_comanager = N_all_manager - N_book
label var N_all_comanager "Num CoManagers"

*Make some graphs of n_book over time.
*Want raw N_book average over time (daily?)
gen category = ""
replace category = "Equity" if equity ==1
replace category = "Debt" if debt ==1
replace category = "Conv" if conv ==1

gen month = month(date_daily)
gen year = year(date_daily)

gen date_monthly = ym(year,month)
format date_monthly %tm

save "$data_path/stata_temp/sdc_all_with_N_book", replace

use "$data_path/stata_temp/sdc_all_with_N_book", clear

collapse (mean) N_book N_all_manager N_all_comanager proceeds , by(year category)

twoway line N_book year if category == "Equity"
twoway line N_book year if category == "Debt"

replace proceeds = proceeds/1000000000

*Want avg bookrunner / dollar over time
gen N_book_per_billion = N_book/ proceeds
gen N_manager_per_billion = N_all_comanager/ proceeds
gen N_comanager_per_billion = N_all_comanager/ proceeds

foreach N_type in N_book N_all_manager N_all_comanager N_book_per_billion N_manager_per_billion  N_comanager_per_billion proceeds {

	if "`N_type'" == "N_book" {
		local title "Avg Num of Bookrunners"
		local save_name "bookrunners_avg"
	}
	if "`N_type'" == "N_all_manager" {
		local title "Avg Num of Managers"
		local save_name "managers_avg"
	}
	if "`N_type'" == "N_all_comanager" {
		local title "Avg Num of Comanagers"
		local save_name "comanagers_avg"
	}
	if "`N_type'" == "N_book_per_billion" {
		local title "Avg Num of Bookrunners per Billion in Proceeds"
		local save_name "bookrunners_avg_per_billion"
	}
	if "`N_type'" == "N_manager_per_billion" {

		local title "Avg Num of Managers per Billion in Proceeds"
		local save_name "managers_avg_per_billion"
	}
	if "`N_type'" == "N_comanager_per_billion" {
		local title "Avg Num of Comanagers per Billion in Proceeds"
		local save_name "comanagers_avg_per_billion"
	}
	if "`N_type'" == "proceeds" {
		local title "Avg Proceeds (billions)"
		local save_name "proceeds_avg"
	}

	twoway line `N_type' year if category == "Equity" , ///
	ytitle("`title'") title("`title' over time for Equity Issuances", size(medsmall)) ///
	graphregion(color(white))  xtitle("Quarter")
	graph export "$figures_output_path/`save_name'_over_time_equity.png", replace

	twoway line `N_type' year if category == "Debt" , ///
	ytitle("`title'") title("`title' over time for Debt Issuances", size(medsmall)) ///
	graphregion(color(white))  xtitle("Quarter")
	graph export "$figures_output_path/`save_name'_over_time_debt.png", replace

}

twoway line N_book_per_billion year if category == "Equity"
twoway line N_book_per_billion year if category == "Debt"

twoway line proceeds year if category == "Equity"
twoway line proceeds year if category == "Debt"

*Do same for lead arrangers
use "$data_path/dealscan_facility_lender_level", clear
keep if lead_arranger_credit ==1
gen N_lead_arranger = 1
collapse (sum) N_lead_arranger, by(facilityid)
save "$data_path/stata_temp/N_lead_arranger_facilityid", replace

*Do same for all lenders
use "$data_path/dealscan_facility_lender_level", clear
gen N_lender = 1
collapse (sum) N_lender, by(facilityid)
save "$data_path/stata_temp/N_lender_facilityid", replace


*Now we have our equivalent of N_book
use "$data_path/stata_temp/dealscan_discounts_facilityid", clear
merge 1:1 facilityid using "$data_path/stata_temp/N_lead_arranger_facilityid", nogen
merge 1:1 facilityid using "$data_path/stata_temp/N_lender_facilityid", nogen

gen N_colender = N_lender - N_lead_arranger

gen year = year(facilitystartdate)

collapse (mean) N_lead_arranger N_lender N_colender facilityamt, by(year category)

replace facilityamt = facilityamt/1000000000

*Want avg bookrunner / dollar over time
gen N_lead_arranger_per_billion = N_lead_arranger/ facilityamt
gen N_lender_per_billion = N_lender/ facilityamt
gen N_colender_per_billion = N_colender/ facilityamt

drop if mi(N_lead_arranger)

keep if year >=2000

foreach N_type in N_lead_arranger N_lender N_colender N_lead_arranger_per_billion N_lender_per_billion N_colender_per_billion facilityamt {

	if "`N_type'" == "N_lead_arranger" {
		local title "Avg Num of Lead Arrangers"
		local save_name "lead_arrangers_avg"
	}
	if "`N_type'" == "N_lender" {
		local title "Avg Num of Lenders"
		local save_name "lenders_avg"
	}
	if "`N_type'" == "N_colender" {
		local title "Avg Num of Colenders"
		local save_name "colenders_avg"
	}
	if "`N_type'" == "N_lead_arranger_per_billion" {
		local title "Avg Num of Lead Arrangers per Billion in Facility"
		local save_name "lead_arrangers_avg_per_billion"
	}
	if "`N_type'" == "N_lender_per_billion" {

		local title "Avg Num of Lenders per Billion in Facility"
		local save_name "lenders_avg_per_billion"
	}
	if "`N_type'" == "N_colender_per_billion" {
		local title "Avg Num of Colenders per Billion in Facility"
		local save_name "colenders_avg_per_billion"
	}
	if "`N_type'" == "facilityamt" {
		local title "Avg Facility Amt (billions)"
		local save_name "facilityamt_avg"
	}

	twoway line `N_type' year  if category == "Revolver" , ///
	ytitle("`title'") title("`title' Over Time for Revolvers", size(medsmall)) ///
	graphregion(color(white))  xtitle("Year")
	graph export "$figures_output_path/`save_name'_over_time_rev.png", replace

	twoway line `N_type' year  if category == "Inst. Term" , ///
	ytitle("`title'") title("`title' Over Time for Institutional Term Loans", size(medsmall)) ///
	graphregion(color(white))  xtitle("Year")
	graph export "$figures_output_path/`save_name'_over_time_inst_term.png", replace

}

twoway line N_lead_arranger year if category == "Revolver"
twoway line N_lead_arranger year if category == "Inst. Term"
twoway line N_lead_arranger year if category == "Bank Term"
twoway line N_lead_arranger year if category == "Other"

*Make Top 5/ Top 10 concentration measures.
*Going to approximate the amount of bookrunner league table credit by doing total issuance / N_book (everyone gets the same)
use "$data_path/stata_temp/sdc_all_with_N_book", clear
gen league_table_credit = proceeds/N_book
keep league_table_credit sdc_deal_id date_quarterly date_daily category
isid sdc_deal_id
save "$data_path/stata_temp/league_table_credit", replace

*Do for Equity
use "$data_path/sdc_deal_bookrunner", clear
merge m:1 sdc_deal_id using "$data_path/stata_temp/league_table_credit", keep(3) nogen
keep if category =="Equity"
gen closing_year = year(date_daily)
rename league_table_credit amt
rename lender book
collapse (sum) amt, by(book closing_year)
gsort closing_year -amt
by closing_year : gen rank = _n
gen amt_5 = amt if rank<=5
gen amt_10 = amt if rank<=10
collapse (sum) amt*, by(closing_year)
gen frac_5 = amt_5/amt
gen frac_10 = amt_10/amt

twoway (line frac_5 closing_year) (line frac_10 closing_year), ytitle("Industry Share",axis(1))  ///
 title("Top Firms Industry Share - Bookrunners for Equity Issuance",size(medsmall)) ///
graphregion(color(white))  xtitle("Deal Closing Year") ///
legend(order(1 "Top 5 Share" 2 "Top 10 Share"))
graph export "$figures_output_path/bookrunner_top_shares_equity.png", replace

*Do for Debt
use "$data_path/sdc_deal_bookrunner", clear
merge m:1 sdc_deal_id using "$data_path/stata_temp/league_table_credit", keep(3) nogen
keep if category =="Debt"
gen closing_year = year(date_daily)
rename league_table_credit amt
rename lender book
collapse (sum) amt, by(book closing_year)
gsort closing_year -amt
by closing_year : gen rank = _n
gen amt_5 = amt if rank<=5
gen amt_10 = amt if rank<=10
collapse (sum) amt*, by(closing_year)
gen frac_5 = amt_5/amt
gen frac_10 = amt_10/amt

twoway (line frac_5 closing_year) (line frac_10 closing_year), ytitle("Industry Share",axis(1))  ///
 title("Top Firms Industry Share - Bookrunners for Debt Issuance",size(medsmall)) ///
graphregion(color(white))  xtitle("Deal Closing Year") ///
legend(order(1 "Top 5 Share" 2 "Top 10 Share"))
graph export "$figures_output_path/bookrunner_top_shares_debt.png", replace

*Do the same for Institutional Term
use "$data_path/dealscan_facility_lender_level", clear
keep if lead_arranger_credit ==1
merge m:1  facilityid using "$data_path/stata_temp/N_lead_arranger_facilityid", nogen
merge m:1  facilityid using "$data_path/stata_temp/N_lender_facilityid", nogen

keep if institutional_term_loan ==1
*Assume all lead arrangers get the same league table credit
gen amt = facilityamt/N_lead_arranger
gen closing_year = year(facilitystartdate)
rename lender book
collapse (sum) amt, by(book closing_year)
gsort closing_year -amt
by closing_year : gen rank = _n
gen amt_5 = amt if rank<=5
gen amt_10 = amt if rank<=10
collapse (sum) amt*, by(closing_year)
gen frac_5 = amt_5/amt
gen frac_10 = amt_10/amt

twoway (line frac_5 closing_year) (line frac_10 closing_year), ytitle("Industry Share",axis(1))  ///
 title("Top Firms Industry Share - Lead Arrangers for Institutional Term Loans",size(medsmall)) ///
graphregion(color(white))  xtitle("Deal Closing Year") ///
legend(order(1 "Top 5 Share" 2 "Top 10 Share"))
graph export "$figures_output_path/bookrunner_top_shares_inst_term.png", replace

*New figures:
*Want to look at fees (let's focus on IPOs) over time/ debt by size category (make bins)
use "$data_path/stata_temp/sdc_all_with_N_book", clear
replace category = "Equity (IPO)" if ipo ==1
replace category = "Equity (Secondary)" if category =="Equity"
replace proceeds = proceeds/1000000
label var proceeds "Proceeds (Mil)"
gen proceeds_cat = ""
replace proceeds_cat = "Proceeds (Mil) = [0,100)" if proceeds<100
replace proceeds_cat= "Proceeds (Mil) = [100,250)" if proceeds >=100 & proceeds<250
replace proceeds_cat ="Proceeds (Mil) = [250,500)" if proceeds >=250 & proceeds<500
replace proceeds_cat ="Proceeds (Mil) = [500,1000)" if proceeds >=500 & proceeds<1000
replace proceeds_cat= "Proceeds (Mil) = [1000,inf)" if proceeds >=1000 & !mi(proceeds)

winsor2 gross_spread_perc, cuts (0 99) replace
save "$data_path/stata_temp/sdc_all_with_N_book_proceeds_cat", replace

local date_var year

collapse (mean) N_book N_all_manager N_all_comanager gross_spread_perc, by(category proceeds_cat `date_var')

*Now let's make figures which plot the average gross_spread_perc across category
local N_type "N_book"

foreach category in "Equity (Secondary)" "Debt" "Equity (IPO)" "Conv" {

	if "`category'" == "Equity (Secondary)" {
		local cat_name "equity_sec"
	}
	if "`category'" == "Debt" {
		local cat_name "debt"
	}
	if "`category'" == "Equity (IPO)" {
		local cat_name "equity_ipo"
	}
	if "`category'" == "Conv" {
		local cat_name "conv"
	}
	
	local proceeds_u100 (line gross_spread_perc `date_var' if proceeds_cat == "Proceeds (Mil) = [0,100)" & category == "`category'", color(black) yaxis(1))
	local proceeds_100_250 (line gross_spread_perc `date_var' if proceeds_cat == "Proceeds (Mil) = [100,250)" & category == "`category'", color(blue) yaxis(1))
	local proceeds_250_500 (line gross_spread_perc `date_var' if proceeds_cat == "Proceeds (Mil) = [250,500)" & category == "`category'", color(red) yaxis(1))
	local proceeds_500_1b (line gross_spread_perc `date_var' if proceeds_cat == "Proceeds (Mil) = [500,1000)" & category == "`category'", color(green) yaxis(1))
	local proceeds_1b_plus (line gross_spread_perc `date_var' if proceeds_cat == "Proceeds (Mil) = [1000,inf)" & category == "`category'", color(orange) yaxis(1))

	twoway `proceeds_u100' `proceeds_100_250' `proceeds_250_500' `proceeds_500_1b' `proceeds_1b_plus'  ///
	, ytitle("Gross Spread (percent)",axis(1))  ///
	 title("Average Gross Spread over Time and Across Deal Sizes - `category'",size(medsmall)) ///
	graphregion(color(white))  xtitle("Year") ///
	legend(order(1 "[0,100)" 2 "[100,250)" 3 "[250,500)" 4 "[500,1000)" 5 "[1000,inf)")) 
	graph export "$figures_output_path/proceeds_by_cat_`cat_name'.png", replace

}

use "$data_path/stata_temp/sdc_all_with_N_book_proceeds_cat", clear
gen N_book_cat = "1" if N_book ==1
replace N_book_cat = "2-3" if N_book ==2 | N_book==3
replace N_book_cat = "4-5" if N_book ==4 | N_book==5
replace N_book_cat = "6+" if N_book >=6 & !mi(N_book)


collapse (mean) gross_spread_perc, by(N_book_cat category proceeds_cat year)

local proceeds_group 100_250
local proceeds_cond "Proceeds (Mil) = [100,250)"
local proceeds_group geq_1B
local proceeds_cond "Proceeds (Mil) = [1000,inf)"

local proceeds_group 500_1b
local proceeds_cond "Proceeds (Mil) = [500,1000)"

*Look at how pricing looks for different number of bookrunners
foreach category in "Equity (Secondary)" "Debt" "Equity (IPO)" "Conv" {

	if "`category'" == "Equity (Secondary)" {
		local cat_name "equity_sec"
	}
	if "`category'" == "Debt" {
		local cat_name "debt"
	}
	if "`category'" == "Equity (IPO)" {
		local cat_name "equity_ipo"
	}
	if "`category'" == "Conv" {
		local cat_name "conv"
	}
	
	local N_book_1 (line gross_spread_perc year if N_book_cat == "1"  & proceeds_cat == "`proceeds_cond'" & category == "`category'", color(black) yaxis(1))
	local N_book_23 (line gross_spread_perc year if N_book_cat == "2-3"  & proceeds_cat == "`proceeds_cond'" & category == "`category'", color(blue) yaxis(1))
	local N_book_45 (line gross_spread_perc year if N_book_cat == "4-5"  & proceeds_cat == "`proceeds_cond'" & category == "`category'", color(red) yaxis(1))
	local N_book_6plus (line gross_spread_perc year if N_book_cat == "6+"  & proceeds_cat == "`proceeds_cond'" & category == "`category'", color(green) yaxis(1))
	
	twoway `N_book_1' `N_book_23' `N_book_45' `N_book_6plus' ///
	, ytitle("Gross Spread (percent)",axis(1))  ///
	 title("Avg Gross Spread over Time and Across N of Bookrunners - `category' - `proceeds_cond'",size(small)) ///
	graphregion(color(white))  xtitle("Year") ///
	legend(order(1 "1 Book" 2 "2-3 Book" 3 "4-5 Book" 4 "6+ Books")) 
	graph export "$figures_output_path/spread_perc_by_n_book_`proceeds_group'_`cat_name'.png", replace

}
