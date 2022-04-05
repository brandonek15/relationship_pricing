/*
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
*/

* Time Series of Different Measures
foreach measure_type in mean median weighted_avg {

	if "`measure_type'" == "mean" {
		local measure "mean"
		local measure_add
		local measure_desc
	}
	if "`measure_type'" == "median" {
		local measure "median"
		local measure_add
		local measure_desc
	}
	if "`measure_type'" == "weighted_avg" {
		local measure "mean"
		local measure_add [aweight=facilityamt]
		local measure_desc "- Wtd"
	}

	foreach sample_type in all comp_merge no_comp_merge {
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
		
		if "`sample_type'" == "all" {
			local title_add "All Firms"
		}
		if "`sample_type'" == "comp_merge" {
			keep if merge_comp ==1
			local title_add "Compustat Firms"
		}
		if "`sample_type'" == "no_comp_merge" {
			keep if merge_comp ==0
			local title_add "Non-Compustat Firms"
		}

		winsor2 discount_*, replace cut(1 99)

		collapse (`measure') discount_* spread `measure_add', by(date_quarterly category)


		preserve
			freduse USRECM BAMLC0A4CBBB BAMLC0A1CAAA, clear
			rename BAMLC0A4CBBB bbb_spread
			rename BAMLC0A1CAAA aaa_spread
			replace bbb_spread = bbb_spread*100
			replace aaa_spread = aaa_spread*100
			gen date_quarterly = qofd(daten)
			collapse (max) USRECM bbb_spread aaa_spread, by(date_quarterly)
			tsset date_quarterly
			gen L1_aaa_spread = L.aaa_spread
			gen L1_bbb_spread = L.bbb_spread
			gen L2_aaa_spread = L2.aaa_spread
			gen L2_bbb_spread = L2.bbb_spread
			gen L3_aaa_spread = L3.aaa_spread
			gen L3_bbb_spread = L3.bbb_spread
			gen L4_aaa_spread = L4.aaa_spread
			gen L4_bbb_spread = L4.bbb_spread
			keep date_quarterly USRECM *bbb_spread *aaa_spread
			tempfile rec
			save `rec', replace
		restore

		joinby date_quarterly using `rec', unmatched(master)
		egen y = rowmax(discount_*)
		qui su y
		replace USRECM = `r(max)'*USRECM*1.05

		tw  (bar USRECM date_quarterly, color(gs14) lcolor(none)) ///
		(line discount_1_simple discount_1_controls discount_2_simple discount_2_controls date_quarterly if category == "Revolver") , ///
			legend(order(1 "Recession" 2 "1 (Simple)" 3 "1 (Controls)" 4 "2 (Simple)"  5 "2 (Controls)")) ///
			title("Revolver Discounts Over Time - `title_add'")  ytitle("`measure' Discount (bps) `measure_desc'") 	
			
		gr export "$figures_output_path/time_series_discount_`measure_type'_`sample_type'_rev.png", replace 

		*Make the same graph for term loans
		tw  (bar USRECM date_quarterly, color(gs14) lcolor(none)) ///
		(line discount_1_simple discount_1_controls discount_2_simple discount_2_controls date_quarterly if category == "Bank Term") , ///
			legend(order(1 "Recession" 2 "1 (Simple)" 3 "1 (Controls)" 4 "2 (Simple)"  5 "2 (Controls)")) ///
			title("Term Discounts Over Time - `title_add'")  ytitle("`measure' Discount (bps) `measure_desc'") 	
			
		gr export "$figures_output_path/time_series_discount_`measure_type'_`sample_type'_term.png", replace 

		
		*Make a graph of the simplest discount and the corresponding spreads over time
		local recession (bar USRECM date_quarterly, color(gs14) lcolor(none))
		local rev_discount (line discount_1_simple date_quarterly if category == "Revolver", col(black) yaxis(1))
		local term_discount (line discount_1_simple date_quarterly if category == "Bank Term", col(black) yaxis(1))
		local term_spr (line spread date_quarterly if category == "Bank Term", yaxis(2))
		local inst_term_spr (line spread date_quarterly if category == "Inst. Term", yaxis(2))
		local rev_spr (line spread date_quarterly if category == "Revolver", yaxis(2))
		local bbb_spr (line bbb_spread date_quarterly if category == "Revolver",yaxis(2))
		
		twoway `recession' `rev_discount' `inst_term_spr' `rev_spr' `bbb_spr', ///
			legend(order(1 "Recession" 2 "Rev Discount 1" 3 "Inst. Term Sprd" 4  "Rev Sprd" 5 "BBB Sprd")) ///
			title("Revolver Discount Decomposition Over Time - `title_add'")  ytitle("`measure' Discount (bps) `measure_desc'", axis(1)) ///	
			ytitle("`measure' Spread (bps) `measure_desc' - Term and Rev, BBB Spread", axis(2))
		gr export "$figures_output_path/time_series_discount_decomposition_`measure_type'_`sample_type'_rev.png", replace 

		*To do - make similar graph with term spread
		twoway `recession' `term_discount' `inst_term_spr' `rev_spr' `bbb_spr', ///
			legend(order(1 "Recession" 2 "Term Discount 1" 3 "Inst. Term Sprd" 4  "Term Sprd" 5 "BBB Sprd")) ///
			title("Term Discount Decomposition Over Time - `title_add'")  ytitle("`measure' Discount (bps) `measure_desc'", axis(1)) ///	
			ytitle("`measure' Spread (bps) `measure_desc' - Term and Rev, BBB Spread", axis(2))
		gr export "$figures_output_path/time_series_discount_decomposition_`measure_type'_`sample_type'_term.png", replace 

		*Similar graph but with only discounts and bbb spread
		local recession (bar USRECM date_quarterly, color(gs14) lcolor(none))
		local rev_discount (line discount_1_simple date_quarterly if category == "Revolver", col(black) yaxis(1))
		local term_discount (line discount_1_simple date_quarterly if category == "Bank Term", col(blue) yaxis(1))
		local bbb_spr (line bbb_spread date_quarterly if category == "Revolver",yaxis(2))
		
		twoway `recession' `rev_discount' `term_discount ' `bbb_spr', ///
			legend(order(1 "Recession" 2 "Rev Discount 1" 3 "Term Discount 1" 4  "BBB Sprd")) ///
			title("Revolver Discount Decomposition Over Time - `title_add'")  ytitle("`measure' Discount (bps) `measure_desc'", axis(1)) ///	
			ytitle("BBB Spread (bps)", axis(2))
		gr export "$figures_output_path/time_series_discount_`measure_type'_`sample_type'_both.png", replace 

	
	}
}

*Todo - Look at distribution of term spreads
*Graph distribution of discounts
*Make three graphs, where we look at the distribution of each of the four discounts
use "$data_path/dealscan_compustat_loan_level", clear

keep if category == "Revolver" | category == "Bank Term"
winsor2 discount_*, replace cut(1 99)
drop rev_loan
local start start(-100)
local width width(10)
local note "Winsorized at 1 and 99"

foreach lhs of varlist discount_* {
	local title_add "`lhs'"
	local cond_add "& `lhs'>=-100 & `lhs'<=500"

		local disc_comp_rev (histogram `lhs' if merge_comp==1 `cond_add' & category == "Revolver", density `width' `start' col(blue%30))
		local disc_no_comp_rev (histogram `lhs' if merge_comp==0 `cond_add' & category == "Revolver", density `width' `start' col(green%30))
		local disc_comp_term (histogram `lhs' if merge_comp==1 `cond_add' & category == "Bank Term", density `width' `start' col(red%30))
		local disc_no_comp_term (histogram `lhs' if merge_comp==0 `cond_add' & category == "Bank Term", density `width' `start' col(black%30))

		twoway `disc_comp_rev'  `disc_no_comp_rev' `disc_comp_term'  `disc_no_comp_term'  ///
		, ytitle("Density") title("Distribution of Discounts - `title_add'", size(small)) ///
		 note("`note'") ///
		graphregion(color(white))  xtitle("Discounts") ///
		legend(order(1 "Rev Discount - Compustat Firms" 2 "Rev Discount - Non-Compustat Firms" ///
		 3 "Term Discount - Compustat Firms" 4 "Term Discount - Non-Compustat Firms") rows(2)) 

		graph export "$figures_output_path/dist_`lhs'.png", replace
}

*See fraction 0 over time
use "$data_path/dealscan_compustat_loan_level", clear
keep if category == "Revolver" | category == "Bank Term"
keep if !mi(discount_1_simple)
gen zero_discount = abs(discount_1_simple)<10e-6
replace discount_1_simple = . if zero_discount
collapse (mean) zero_discount discount_1_simple, by(date_quarterly category)
twoway (line zero_discount date_quarterly if category == "Revolver") (line zero_discount date_quarterly if category == "Bank Term"), ///
ytitle("Fraction of Loans with Zero Discount 1 (simple)") title("Fraction of Loans with Zero Discount", size(medsmall)) ///
		 note("`note'") ///
		graphregion(color(white))  xtitle("Quarter") ///
		legend(order(1 "Revolving Discount" 2 "Term Discount"))
		graph export "$figures_output_path/discount_frac_zero.png", replace
		
*Check to see if the first discount given to each firm is bigger than later ones?
use "$data_path/dealscan_compustat_loan_level", clear
keep if (category =="Revolver" | category == "Bank Term")  & !mi(cusip_6) & !mi(discount_1_simple)
bys cusip_6 category (facilitystartdate): gen n = _n
bys cusip_6 category (facilitystartdate): gen N = _N
sum discount_1_simple if n ==1
sum discount_1_simple if n >1

sum discount_1_simple if n ==1 & N>1
sum discount_1_simple if n >1 & N>1

gen count = 1
reghdfe discount_1_simple n, absorb(count)
reghdfe discount_1_simple n, absorb(cusip_6)
reghdfe discount_1_simple n, absorb(cusip_6 date_quarterly)
reghdfe discount_2_simple n, absorb(cusip_6 date_quarterly)


*Make a simple graph of the average discount by observation num
collapse (sum) count (mean) discount*, by(n category)

local discount_n_rev (line discount_1_simple n if category == "Revolver", col(black) lpattern(solid) yaxis(1))
local discount_n_term (line discount_1_simple n if category == "Bank Term", col(blue) lpattern(solid) yaxis(1))
local count_n_rev (line count n if category == "Revolver", col(gray) lpattern(solid) yaxis(2))
local count_n_term (line count n if category == "Bank Term", col(ltblue) lpattern(solid) yaxis(2))

twoway `discount_n_rev' `count_n_rev' `discount_n_term' `count_n_term' , ///
	legend(order(1 "Rev Discount" 2 "Term Discount" 3 "Rev Number of Obs" 4 "Term Number of Obs") size(medium) rows(2)) ///
	title("Avg Discount and Loan Number in Sample")  ytitle("Discount", axis(1)) ///	
	ytitle("Number of Observations", axis(2)) xtitle("Loan Number")
gr export "$figures_output_path/discounts_across_loan_number.png", replace 
