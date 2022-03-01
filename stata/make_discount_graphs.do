
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

		keep if rev_loan ==1
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

		winsor2 rev_*, replace cut(1 99)

		collapse (`measure') rev_* `measure_add', by(date_quarterly)


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
		drop rev_loan
		
		tw  (bar USRECM date_quarterly, color(gs14) lcolor(none)) ///
		(line rev* date_quarterly, ///
			legend(order(1 "Recession" 2 "1 (Simple)" 3 "1 (Controls)" 4 "2 (Simple)"  5 "2 (Controls)"))) ///
			, title("Discounts Over Time - `title_add'")  ytitle("`measure' Discount (bps) `measure_desc'") 	
			
		gr export "$figures_output_path/time_series_discount_`measure_type'_`sample_type'.png", replace 

	}
}

*Graph distribution of discounts
*Make three graphs, where we look at the distribution of each of the four discounts
use "$data_path/dealscan_compustat_loan_level", clear

keep if rev_loan ==1
winsor2 rev_*, replace cut(1 99)
drop rev_loan
local start start(-100)
local width width(10)
local note "Winsorized at 1 and 99"

foreach lhs of varlist rev_* {
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
