*Trying to see what can explain discounts
use "$data_path/dealscan_compustat_loan_level", clear
keep if category == "Revolver" | category == "Bank Term"
keep if !mi(discount_1_simple) & merge_compustat ==1

local firm_chars L1_market_to_book L1_ppe_assets L1_log_assets L1_leverage ///
L1_roa L1_sales_growth L1_ebitda_int_exp L1_sga_assets ///
L1_working_cap_assets L1_capex_assets L1_firm_age

winsor2 `firm_chars', cuts(.5 99.5) replace

local loan_vars log_facilityamt maturity asset_based

winsor2 `loan_vars', cuts(1 99) replace

*Deal with missing vars so we don't lose so much data
foreach var in `firm_chars' {
	gen `var'_mi = mi(`var')
	replace `var' = -99 if `var'_mi ==1
	local firm_char_add `firm_char_add' `var'_mi
}

local firm_chars `firm_chars' `firm_char_add'


*Want to know which firm characteristics, loan characteristics correlate to discounts
*Split up by type of discount - all, term and revolver (different tables) 
*Split up by discount measure (different tables)
*Split up firm chars, loan chars, both
*Have tables for different FEs (none, time)

foreach lhs in discount_1_simple discount_1_controls discount_2_simple discount_2_controls {

	foreach discount_type in rev term all  {

		if "`discount_type'" == "rev" {
			local cond `"if category =="Revolver""'
			local sample_add "Rev"
		}
		if "`discount_type'" == "term" {
			local cond `"if category =="Bank Term""'
			local sample_add "Term"
		}
		if "`discount_type'" == "all" {
			local cond `"if 1==1"'
			local sample_add "All"
		}
		
		estimates clear
		local i =1
		
		foreach chars in firm_chars loan_chars both_chars {
		
			if "`chars'" == "firm_chars" {
				local rhs `firm_chars'
			}
			if "`chars'" == "loan_chars" {
				local rhs `loan_vars'
			}
			if "`chars'" == "both_chars" {
				local rhs `firm_chars' `loan_vars'
			}
		
			foreach fe_type in  none  time time_sic_2 {
			
				if "`fe_type'" == "none" {
					local fe "constant"
					local fe_add "None"
				}
				if "`fe_type'" == "time" {
					local fe "date_quarterly"
					local fe_add "Time"
				}
				if "`fe_type'" == "time_sic_2" {
					local fe "date_quarterly sic_2"
					local fe_add "Time,SIC2"
				}
				
				reghdfe `lhs' `rhs' `cond', a(`fe') vce(cl borrowercompanyid)
				estadd local fe = "`fe_add'"
				estadd local sample = "`sample_add'"
				estimates store est`i'
				local ++i
			}
			
		}

		esttab est* using "$regression_output_path/discount_chars_`lhs'_`discount_type'.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons *_mi) star(* 0.1 ** 0.05 *** 0.01) ///
		title("Discounts and Characteristics") scalars("fe Fixed Effects" "sample Sample") ///
		addnotes("SEs clustered at firm level" "Sample are all compustat firms with dealscan discounts from 2000Q1-2020Q4")	

	}

}


*Try to explain discounts using differences in non-price loan characteristics
use "$data_path/dealscan_compustat_loan_level", clear

foreach discount_type in all rev term   {
	
	estimates clear
	local i =1
	
	foreach lhs in discount_1_simple discount_1_controls discount_2_simple discount_2_controls {
		if "`discount_type'" == "rev" {
			local cond `"if category =="Revolver""'
			local sample_add "Rev"
		}
		if "`discount_type'" == "term" {
			local cond `"if category =="Bank Term""'
			local sample_add "Term"
		}
		if "`discount_type'" == "all" {
			local cond `"if 1==1"'
			local sample_add "All"
		}
		
		local rhs diff_*
		
			foreach fe_type in  none  time {
			
				if "`fe_type'" == "none" {
					local fe "constant"
					local fe_add "None"
				}
				if "`fe_type'" == "time" {
					local fe "date_quarterly"
					local fe_add "Time"
				}
				if "`fe_type'" == "time_sic_2" {
					local fe "date_quarterly sic_2"
					local fe_add "Time,SIC2"
				}
				
				reghdfe `lhs' `rhs' `cond', a(`fe') vce(cl borrowercompanyid)
				estadd local fe = "`fe_add'"
				estadd local sample = "`sample_add'"
				estimates store est`i'
				local ++i
			}
			
		}
	
	esttab est* using "$regression_output_path/discount_loan_chars_diff_`discount_type'.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
	title("Discounts and Differences in non-price characteristics") scalars("fe Fixed Effects" "sample Sample") ///
	addnotes("SEs clustered at firm level" "Sample are all compustat firms with dealscan discounts from 2000Q1-2020Q4")	

}
