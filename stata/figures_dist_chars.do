*Do figures of firm characteristcs.
use  "$data_path/dealscan_compustat_loan_level", clear
*These can only be done for observations merged to compustat
keep if merge_compustat==1
*Want to do these sets of summary stats
*Firm characteristics of compustat firms matched to dealscan - split by whether discount is calculated or not - 
*define firm as discount firm if at any point they had a discount
local firm_chars L1_market_to_book L1_ppe_assets L1_log_assets L1_leverage ///
L1_roa L1_sales_growth L1_ebitda_int_exp L1_sga_assets ///
L1_working_cap_assets L1_capex_assets L1_firm_age

*Drop duplicate observations
keep borrowercompanyid date_quarterly discount_obs discount_1_simple  `firm_chars' 
duplicates drop

winsor2 `firm_chars', cuts(.5 99.5) replace

foreach var in `firm_chars' {
	local var_lab: variable label `var'

		if "`var'" == "L1_log_assets" {
			local cond "& L1_log_assets>=4"
			local width "width(0.5)"
			local note "Truncated at 4"
			local start "start(4)"
		}
		else if "`var'" == "L1_leverage" {
		local cond "& L1_leverage>=0"
		local width "width(0.1)"
		local note "Truncated at 0"
		local start "start(0)"
		}
		else if "`var'" == "L1_market_to_book" {
		local cond "& L1_market_to_book<=5"
		local width "width(0.25)"
		local note "Truncated at 5"
		local start "start(0.5)"
		}
		else if "`var'" == "L1_sales_growth" {
		local cond "& L1_sales_growth>=-50 & L1_sales_growth<=100"
		local width "width(7.5)"
		local note "Truncated at -50"
		local start "start(-50)"
		}
		else if "`var'" == "L1_log_sales" {
		local cond "& L1_log_sales>=1"
		local width "width(.5)"
		local note "Truncated at 1"
		local start "start(1)"
		}
		else if "`var'" == "L1_quick_ratio" {
		local cond "& L1_quick_ratio<=5"
		local width "width(.25)"
		local note "Truncated at 5"
		local start "start(0)"
		}
		else if "`var'" == "L1_ebitda_int_exp" {
		local cond "& L1_ebitda_int_exp>=-10 & L1_ebitda_int_exp <=30"
		local width "width(1)"
		local note "Truncated at -10 and 30"
		local start "start(-10)"
		}
		else if "`var'" == "L1_cash_assets" {
		local cond "& L1_cash_assets<=.4"
		local width "width(.025)"
		local note "Truncated at .4"
		local start "start(0)"
		}
		else if "`var'" == "L1_acq_assets" {
		local cond "& L1_acq_assets<=.04"
		local width "width(.0025)"
		local note "Truncated at .04"
		local start "start(0)"
		}
		else if "`var'" == "L1_shrhlder_payout_assets" {
		local cond "& L1_shrhlder_payout_assets<=.04"
		local width "width(.0025)"
		local note "Truncated at .04"
		local start "start(0)"
		}
		else if "`var'" == "L1_working_cap_assets" {
		local cond "& L1_working_cap_assets>=-.2 & L1_working_cap_assets<=.5"
		local width "width(.05)"
		local note "Truncated at -0.2 and 0.5"
		local start "start(-.2)"
		}
		else if "`var'" == "L1_capex_assets" {
		local cond "& L1_capex_assets<=.075 & L1_capex_assets>=0"
		local width "width(.0025)"
		local note "Truncated at0.75"
		local start "start(0)"
		}
		else if "`var'" == "L1_ppe_assets" {
		local cond ""
		local width "width(.025)"
		local note ""
		local start "start(0)"
		}
		else if "`var'" == "L1_roa" {
		local cond "& L1_roa>=-.05 & L1_roa <=.05"
		local width "width(.005)"
		local note "Truncated at -.05 and .05"
		local start "start(-0.05)"
		}
		else if "`var'" == "L1_ebitda_assets" {
		local cond "& L1_ebitda_assets>=-.025 & L1_ebitda_assets <=.075"
		local width "width(.005)"
		local note "Truncated at -.025 and .075"
		local start "start(-0.025)"
		}
		else if "`var'" == "L1_sga_assets" {
		local cond "& L1_sga_assets<=.15"
		local width "width(.005)"
		local note "Truncated at .15"
		local start "start(0)"
		}
		else if "`var'" == "L1_firm_age" {
		local cond "& L1_firm_age>=0"
		local width "width(1)"
		local note "Truncated at 0"
		local start "start(0)"
		}
		else {
		local cond 
		local width 
		local note 
		local start 
		}

		local discount (histogram `var' if discount_obs ==1 `cond' , density  `width' `start'col(blue%30))
		local no_discount (histogram `var' if discount_obs ==0 `cond' , density  `width' `start'col(red%30))
		
		twoway `discount'  `no_discount'  ///
		, ytitle("Density") title("Distribution of `var_lab' Across Discount Type ", size(medsmall)) ///
		 note("Winsorized at 0.5% and 99.5%" "`note'") ///
		graphregion(color(white))  xtitle("`var_lab'") ///
		legend(order(1 "Discount Obs" 2 "Non-Discount Obs")) 
		
		graph export "$figures_output_path/dist_`var'_types.png", replace
		
		*Look at firm characteristics of zero or less than zero discount firms compared to positive discount firms
		local discount_leq_0 (histogram `var' if discount_obs ==1 & discount_1_simple<=10e-6 `cond' , density  `width' `start'col(blue%30))
		local discount_ge_0 (histogram `var' if discount_obs ==1 & discount_1_simple>10e-6 `cond', density  `width' `start'col(red%30))
		
		twoway `discount_leq_0'  `discount_ge_0'  ///
		, ytitle("Density") title("Distribution of `var_lab' Across Discount Size", size(medsmall)) ///
		 note("Winsorized at 0.5% and 99.5%" "`note'") ///
		graphregion(color(white))  xtitle("`var_lab'") ///
		legend(order(1 "Discount (-inf,0]" 2 "Discount (0,inf)")) 
		
		graph export "$figures_output_path/dist_`var'_discount_size.png", replace
}

*Do figures of loan characteristcs.
use  "$data_path/dealscan_compustat_loan_level", clear

local loan_vars log_facilityamt maturity spread salesatclose 

winsor2 `loan_vars', cuts(1 99) replace

winsor2 salesatclose, cuts(1 95) replace


foreach var in `loan_vars' {
	local var_lab: variable label `var'

		if "`var'" == "log_facilityamt" {
		local cond ""
		local width "width(0.5)"
		local note ""
		local start "start(9)"
		}
		else if "`var'" == "maturity" {
		local cond ""
		local width "width(2.5)"
		local note ""
		local start "start(0)"
		}
		else if "`var'" == "spread" {
		local cond "& spread<=1000"
		local width "width(25)"
		local note "Truncated at 1000"
		local start "start(0)"
		}
		else if "`var'" == "salesatclose" {
		local cond ""
		local width "width(1000)"
		local note "Winsorized at 1 and 95"
		local start "start(0)"
		}
		else {
		local cond 
		local width 
		local note 
		local start 
		}

		local discount_comp  (histogram `var' if discount_obs ==1 & merge_compustat ==1 `cond' , density  `width' `start' col(blue%30))
		local no_discount_comp (histogram `var' if discount_obs ==0 & merge_compustat ==1 `cond' , density  `width' `start' col(red%30))
		local discount_no_comp (histogram `var' if discount_obs ==1 & merge_compustat ==0 `cond' , density  `width' `start' col(black%30))
		local no_discount_no_comp   (histogram `var' if discount_obs ==0 & merge_compustat ==0 `cond' , density  `width' `start' col(green%30))
		
		
		twoway `discount_comp'  `no_discount_comp' `discount_no_comp'  `no_discount_no_comp'  ///
		, ytitle("Density") title("Distribution of `var_lab' Across Discount Type ", size(medsmall)) ///
		 note("Winsorized at 1% and 99%" "`note'") ///
		graphregion(color(white))  xtitle("`var_lab'") ///
		legend(order(1 "Compustat Discount Obs" 2 "Compustat Non-Discount Obs" ///
		 3 "Non-Compustat Discount Obs" 4 "Non-Compustat Non-Discount Obs") rows(2)) 
		
		graph export "$figures_output_path/dist_`var'_types.png", replace
		
		*Make a graph where I split up by category
		
		local revolver  (histogram `var' if category == "Revolver" `cond' , density  `width' `start' col(blue%30))
		local bank_term (histogram `var' if category == "Bank Term" `cond' , density  `width' `start' col(red%30))
		local inst_term (histogram `var' if category == "Inst. Term" `cond' , density  `width' `start' col(black%30))
		local other   (histogram `var' if category == "Other" `cond' , density  `width' `start' col(green%30))
				
		twoway `revolver'  `bank_term' `inst_term'  `other'  ///
		, ytitle("Density") title("Distribution of `var_lab' Across Loan Type ", size(medsmall)) ///
		 note("Winsorized at 1% and 99%" "`note'") ///
		graphregion(color(white))  xtitle("`var_lab'") ///
		legend(order(1 "Revolver" 2 "Bank Term" ///
		 3 "Institutional Term" 4 "Other") rows(2)) 
		
		graph export "$figures_output_path/dist_`var'_loan_types.png", replace
		

}

*Split up the dealscan loans into how many packages have each combination
use "$data_path/dealscan_compustat_loan_level", clear
gen rev_loan_cat = (category == "Revolver")
gen bank_term_loan_cat = (category == "Bank Term")
gen inst_term_loan_cat = (category == "Inst. Term")
collapse (max) *_cat, by(borrowercompanyid date_quarterly merge_compustat)
isid borrowercompanyid date_quarterly
gen package_type = ""
replace package_type = "Only Revolver" if rev_loan_cat ==1 & bank_term_loan_cat ==0 & inst_term_loan_cat ==0
replace package_type = "Only Bank Term" if rev_loan_cat ==0 & bank_term_loan_cat ==1 & inst_term_loan_cat ==0
replace package_type = "Only Inst. Term" if rev_loan_cat ==0 & bank_term_loan_cat ==0 & inst_term_loan_cat ==1
replace package_type = "Rev + Bank Term" if rev_loan_cat ==1 & bank_term_loan_cat ==1 & inst_term_loan_cat ==0
replace package_type = "Rev + Inst. Term" if rev_loan_cat ==1 & bank_term_loan_cat ==0 & inst_term_loan_cat ==1
replace package_type = "Bank Term + Inst. Term" if rev_loan_cat ==0 & bank_term_loan_cat ==1 & inst_term_loan_cat ==1
replace package_type = "Rev + Bank Term + Inst. Term" if rev_loan_cat ==1 & bank_term_loan_cat ==1 & inst_term_loan_cat ==1
drop if mi(package_type)
*Specify order
gen order = .
replace order = 1 if package_type == "Only Revolver"
replace order = 2 if package_type == "Only Bank Term"
replace order = 3 if package_type == "Only Inst. Term"
replace order = 4 if package_type == "Rev + Bank Term"
replace order = 5 if package_type == "Rev + Inst. Term"
replace order = 6 if package_type == "Bank Term + Inst. Term"
replace order = 7 if package_type == "Rev + Bank Term + Inst. Term"

qui sum rev_loan_cat
local num_obs = `r(N)'

graph pie, over(package_type) ///
allcategories sort(order) ///
	 graphregion(color(white)) title("Distribution of Loans Packages") ///
	  note("Number of Packages: `num_obs'" "Loans to the same firm in the same quarter considered to be in the same package") legend(rows(2))
	graph export "$figures_output_path/package_type_pie.png", replace
