
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
		*Only keep observations where a discount is computed
		keep if !mi(discount_1_simple)
		*Keep only one term and one rev loan observation per loan package
		bys borrowercompanyid date_quarterly rev_loan: keep if _n ==1
		
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
		(line discount* date_quarterly if category == "Revolver", ///
			legend(order(1 "Recession" 2 "1 (Simple)" 3 "1 (Controls)" 4 "2 (Simple)"  5 "2 (Controls)"))) ///
			, title("Discounts Over Time - `title_add'")  ytitle("`measure' Discount (bps) `measure_desc'") 	
			
		gr export "$figures_output_path/time_series_discount_`measure_type'_`sample_type'.png", replace 
		
		*Make a graph of the simplest discount and the corresponding spreads over time
		local recession (bar USRECM date_quarterly, color(gs14) lcolor(none))
		local discount (line discount_1_simple date_quarterly if category == "Revolver", col(black) yaxis(1))
		local term_spr (line spread date_quarterly if category == "Bank Term", yaxis(2))
		local inst_term_spr (line spread date_quarterly if category == "Inst. Term", yaxis(2))
		local rev_spr (line spread date_quarterly if category == "Revolver", yaxis(2))
		local bbb_spr (line bbb_spread date_quarterly if category == "Revolver",yaxis(2))
		
		twoway `recession' `discount' `inst_term_spr' `rev_spr' `bbb_spr', ///
			legend(order(1 "Recession" 2 "Discount 1" 3 "Inst. Term Sprd" 4  "Rev Sprd" 5 "BBB Sprd")) ///
			title("Discount Decomposition Over Time - `title_add'")  ytitle("`measure' Discount (bps) `measure_desc'", axis(1)) ///	
			ytitle("`measure' Spread (bps) `measure_desc' - Term and Rev", axis(2))
		gr export "$figures_output_path/time_series_discount_decomposition_`measure_type'_`sample_type'.png", replace 
	
		*To do - make similar graph with term spread
	}
}

*Todo - Look at distribution of term spreads
*Graph distribution of discounts
*Make three graphs, where we look at the distribution of each of the four discounts
use "$data_path/dealscan_compustat_loan_level", clear

keep if rev_loan ==1
winsor2 discount_*, replace cut(1 99)
drop rev_loan
local start start(-100)
local width width(10)
local note "Winsorized at 1 and 99"

foreach lhs of varlist discount_* {
	local title_add "`lhs'"
	local cond_add "& `lhs'>=-100 & `lhs'<=500"

		local disc_comp (histogram `lhs' if merge_comp==1 `cond_add', density `width' `start' col(blue%30))
		local disc_no_comp (histogram `lhs' if merge_comp==0 `cond_add', density `width' `start' col(green%30))

		twoway `disc_comp '  `disc_no_comp '  ///
		, ytitle("Density") title("Distribution of Discounts - `title_add'", size(small)) ///
		 note("`note'") ///
		graphregion(color(white))  xtitle("Discounts") ///
		legend(order(1 "Compustat Firms" 2 "Non-Compustat Firms")) 

		graph export "$figures_output_path/dist_`lhs'.png", replace
}

*See fraction 0 over time
use "$data_path/dealscan_compustat_loan_level", clear
keep if rev_loan ==1
keep if !mi(discount_1_simple)
gen zero_discount = abs(discount_1_simple)<10e-6
replace discount_1_simple = . if zero_discount
collapse (mean) zero_discount discount_1_simple, by(date_quarterly)
twoway line zero_discount date_quarterly, ///
ytitle("Fraction of Loans with Zero Discount 1 (simple)") title("Fraction of Loans with Zero Discount", size(medsmall)) ///
		 note("`note'") ///
		graphregion(color(white))  xtitle("Quarter") 
		graph export "$figures_output_path/discount_frac_zero.png", replace
		
twoway line discount_1_simple date_quarterly
