use "$data_path/stata_temp/dealscan_discount_prev_lender", clear
foreach lhs in discount_1_simple discount_1_controls {
	foreach discount_type in rev term all  {

		if "`discount_type'" == "rev" {
			local cond `"if category =="Revolver""'
			local disc_add "Rev"
		}
		if "`discount_type'" == "term" {
			local cond `"if category =="Bank Term""'
			local disc_add "Term"
		}
		if "`discount_type'" == "all" {
			local cond `"if 1==1"'
			local disc_add "All"
		}
		foreach rec_type in yes no {
		
			if "`rec_type'" == "yes" {
				local rhs_add max_prev_lender_rec
				local suffix_add _rec
			}
			if "`rec_type'" == "no" {
				local rhs_add 
				local suffix_add 
			}
			estimates clear
			local i =1
			
			foreach sample_type in all comp_merge no_comp_merge {
				
				if "`sample_type'" == "all" {
					local title_add "All Firms"
					local sample_add "All Firms"
					local sample_cond 
				}
				if "`sample_type'" == "comp_merge" {
					local sample_cond "& merge_comp ==1"
					local sample_add "Comp Firms"
					local title_add "Compustat Firms"
				}
				if "`sample_type'" == "no_comp_merge" {
					local sample_cond "& merge_comp ==0"
					local title_add "Non-Compustat Firms"
					local sample_add "Non-Comp"
				}

				foreach fe_type in  time time_borrower {

					if "`fe_type'" == "time" {
						local fe "date_quarterly"
						local fe_add "Time"
					}
					if "`fe_type'" == "time_borrower" {
						local fe "date_quarterly borrowercompanyid"
						local fe_add "Time,Borr"
					}
					
					reghdfe `lhs' max_prev_lender `rhs_add' `cond' `sample_cond' &date_quarterly >=tq(2005q1), a(`fe') vce(cl borrowercompanyid)
					estadd local fe = "`fe_add'"
					estadd local disc = "`disc_add'"
					estadd local sample = "`sample_add'"
					estimates store est`i'
					local ++i
				}


			}
			esttab est* using "$regression_output_path/discount_prev_lend_`lhs'_`discount_type'`suffix_add'.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
			title("Discounts and Previous Lenders") scalars("fe Fixed Effects" "disc Discount" "sample Sample") ///
			addnotes("SEs clustered at firm level" "Sample are all dealscan discounts from 2005Q1-2020Q4" "Dropping 2001Q1-2004Q4 as burnout period")	
		}
	}
}

use "$data_path/stata_temp/dealscan_discount_prev_lender", clear
gen count = 1
foreach discount_type in rev term all  {

	if "`discount_type'" == "rev" {
		local cond `"keep if category =="Revolver""'
		local disc_add "Rev"
	}
	if "`discount_type'" == "term" {
		local cond `"keep if category =="Bank Term""'
		local disc_add "Term"
	}
	if "`discount_type'" == "all" {
		local cond `"keep if 1==1"'
		local disc_add "All"
	}
	foreach sample_type in all comp_merge no_comp_merge {
		
		if "`sample_type'" == "all" {
			local title_add "All Firms"
			local sample_add "All Firms"
			local sample_cond 
		}
		if "`sample_type'" == "comp_merge" {
			local sample_cond "keep if merge_comp ==1"
			local sample_add "Comp Firms"
			local title_add "Compustat Firms"
		}
		if "`sample_type'" == "no_comp_merge" {
			local sample_cond "keep if merge_comp ==0"
			local title_add "Non-Compustat Firms"
			local sample_add "Non-Comp"
		}

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

		preserve
		`sample_cond' 
		`cond'
		collapse (sum) count (mean) discount_1_simple, by(date_quarterly max_prev_lender)
		egen total_count = total(count), by(date_quarterly)
		gen frac_no_prev_lend = count/total_count if max_prev_lender ==0
		
		*Get recession data
		joinby date_quarterly using `rec', unmatched(master)
		egen y = rowmax(discount_*)
		qui su y
		replace USRECM = `r(max)'*USRECM*1.05

			local recession (bar USRECM date_quarterly, color(gs14) lcolor(none))
			local prev_lend (line discount_1_simple date_quarterly if max_prev_lender ==1, color(black) yaxis(1))
			local no_prev_lend (line discount_1_simple date_quarterly if max_prev_lender ==0, color(blue) yaxis(1))
			local frac_no_prev_lend (line frac_no_prev_lend date_quarterly if max_prev_lender ==0, color(green) yaxis(2))
			
			twoway `recession' `prev_lend' `no_prev_lend' `frac_no_prev_lend', ///
				legend(order(1 "Recession" 2 "Any Previous Lender" 3 "No Previous Lender" 4 "Fraction with Previous Lender")) ///
				title("Avg Discount for Loans with Prev Lenders vs No Prev Lenders - `title_add' - `disc_add' Disc",size(small))  ytitle("Avg Discount (bps)", axis(1)) ///	
				ytitle("Proportion with No Previous Lender", axis(2))
			gr export "$figures_output_path/time_series_discount_prev_lender_`sample_type'_`discount_type'.png", replace 
			
		restore

	}
}
