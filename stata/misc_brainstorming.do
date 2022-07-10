*Do some analysis for N_book
*All daily dataset
use "$data_path/sdc_all_clean", clear

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

*Make some graphs of n_book over time.
*Want raw N_book average over time (daily?)
*Want avg bookrunner / dollar over time
gen N_book_per_billion = N_book/ (proceeds/1000000000)
gen category = ""
replace category = "Equity" if equity ==1
replace category = "Debt" if debt ==1
replace category = "Conv" if conv ==1

gen month = month(date_daily)
gen year = year(date_daily)

gen date_monthly = ym(year,month)
format date_monthly %tm

gen date_quarterly = qofd(date_daily)
format date_quarterly %tq
save "$data_path/stata_temp/sdc_all_with_N_book", replace


collapse (mean) N_book proceeds (median) N_book_per_billion , by(date_quarterly category)

twoway line N_book date_quarterly if category == "Equity"
twoway line N_book date_quarterly if category == "Debt"

twoway line N_book date_quarterly if category == "Equity" , ///
ytitle("Avg Num of Bookrunners") title("Bookrunners over time for Equity Issuances", size(medsmall)) ///
graphregion(color(white))  xtitle("Quarter")
graph export "$figures_output_path/bookrunners_avg_over_time_equity.png", replace

twoway line N_book date_quarterly if category == "Debt" , ///
ytitle("Avg Num of Bookrunners") title("Bookrunners over time for Debt Issuances", size(medsmall)) ///
graphregion(color(white))  xtitle("Quarter")
graph export "$figures_output_path/bookrunners_avg_over_time_debt.png", replace

twoway line N_book_per_billion date_quarterly if category == "Equity"
twoway line N_book_per_billion date_quarterly if category == "Debt"

twoway line proceeds date_quarterly if category == "Equity"
twoway line proceeds date_quarterly if category == "Debt"

*Do same for lead arrangers
use "$data_path/dealscan_facility_lender_level", clear
keep if lead_arranger_credit ==1
gen N_lead_arranger = 1
collapse (sum) N_lead_arranger, by(facilityid)
save "$data_path/stata_temp/N_lender_facilityid", replace

*Now we have our equivalent of N_book
use "$data_path/stata_temp/dealscan_discounts_facilityid", clear
merge 1:1 facilityid using "$data_path/stata_temp/N_lender_facilityid", nogen
drop if mi(N_lead_arranger)

collapse (mean) N_lead_arranger facilityamt, by(date_quarterly category)

twoway line N_lead_arranger date_quarterly  if category == "Revolver" , ///
ytitle("Avg Num of Lead Arrangers") title("Lead Arrangers Over Time for Revolvers", size(medsmall)) ///
graphregion(color(white))  xtitle("Quarter")
graph export "$figures_output_path/lead_arrangers_avg_over_time_rev.png", replace

twoway line N_lead_arranger date_quarterly  if category == "Inst. Term" , ///
ytitle("Avg Num of Lead Arrangers") title("Lead Arrangers Over Time for Institutional Term Loans", size(medsmall)) ///
graphregion(color(white))  xtitle("Quarter")
graph export "$figures_output_path/lead_arrangers_avg_over_time_inst_term.png", replace

twoway line N_lead_arranger date_quarterly if category == "Revolver"
twoway line N_lead_arranger date_quarterly if category == "Inst. Term"
twoway line N_lead_arranger date_quarterly if category == "Bank Term"
twoway line N_lead_arranger date_quarterly if category == "Other"

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
merge m:1 facilityid using "$data_path/stata_temp/N_lender_facilityid", nogen
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
