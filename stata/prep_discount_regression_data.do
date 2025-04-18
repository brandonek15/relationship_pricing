*Get the facility level data
use "$data_path/dealscan_facility_level", clear

*I will make four categories of loans: revolvers (relationship loans), non-institutional term loans (relationship loans)
*institional term loans (market loans) and other loans (not considering)

*The difference between revolving and institutional and non-institutional term and instittuional term loanwill give me the "discount
*Will temporarily be calling non secured, non senior, or asset backed into "Other"
gen category_temp = category
*Add loans that are non secured, non senior, or asset backed into "Other" so our measure is better
replace category = "Other" if secured == 0 | senior ==0 | asset_based ==1

assert !mi(category)
*Create a new "package" id to be used when residualizing
egen borrower_facilitystartdate = group(borrowercompanyid facilitystartdate)

sort borrowercompanyid date_quarterly category facilityid
gen diff_obs = 0

*For each variable that could vary within loan package (borrowercompanyid facilitystartdate), get the average by category
foreach var in spread spread_2 $loan_level_controls {
	egen m_`var' = mean(`var'), by(borrowercompanyid facilitystartdate category)
	gen m_`var'_inst_t = m_`var' if category == "Inst. Term"
	egen m_`var'_inst = max(m_`var'_inst_t), by(borrowercompanyid facilitystartdate)
	gen diff_`var' = m_`var'- m_`var'_inst if category == "Revolver" | category == "Bank Term"
	replace diff_obs = 1 if !mi(m_`var') & !mi(m_`var'_inst)
	drop m_`var'*
	local var_label: variable label `var'
	label var diff_`var' "D-`var_label'"
}

*Get residualized spreads, which will be used to calculate the discount with controls
*Will use the entire sample to inform the coefficients, but use borrower x start date FEs (package FEs)

estimates clear
local i =1

*Temporarily make them populated so I don't lose observations
replace maturity = -1 if maturity_mi ==1
local loan_level_controls cov_lite maturity maturity_mi log_facilityamt 

foreach spreads in spread spread_2 {
	reghdfe `spreads' `loan_level_controls' , absorb(borrower_facilitystartdate) residuals(`spreads'_resid) vce(cl borrowercompanyid)
	if "`spreads'" == "spread" {
		estadd local fe = "Borrower X Date"
		estimates store est`i'
		local ++i
	}
}

local loan_level_controls_no_param cov_lite maturity_* log_facilityamt_dec_*
foreach spreads in spread spread_2 {
	reghdfe `spreads' `loan_level_controls_no_param' , absorb(borrower_facilitystartdate) residuals(`spreads'_resid_np) vce(cl borrowercompanyid)
	if "`spreads'" == "spread" {
		estadd local fe = "Borrower X Date"
		estimates store est`i'
		local ++i
	}

}
*Make it missing again
replace maturity = . if maturity_mi ==1

*Make a table with the coefficients
esttab est* using "$regression_output_path/spreads_onto_controls_for_residalized_measure.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons *_mi) star(* 0.1 ** 0.05 *** 0.01) ///
title("Spreads and Loan Characteristics") scalars("fe Fixed Effects")  ///
addnotes("SEs clustered at firm level" "Sample are all loans" "Omitted categories are Maturity = [60,71) and Facility Amt Decile 1")	

*Make a version for just bank term and inst. term loans
replace maturity = -1 if maturity_mi ==1
replace init_amort = -1 if init_amort_mi ==1
replace num_quarters_first_payment = -1 if init_amort_mi ==1
local loan_level_controls cov_lite maturity maturity_mi log_facilityamt 
local extra_controls init_amort num_quarters_first_payment init_amort_mi

foreach spreads in spread spread_2 {
	reghdfe `spreads' `loan_level_controls' if category == "Inst. Term" | category == "Bank Term", absorb(borrower_facilitystartdate) residuals(`spreads'_resid_term) vce(cl borrowercompanyid)
	if "`spreads'" == "spread" {
		estadd local fe = "Borrower X Date"
		estimates store est`i'
		local ++i
	}
}

foreach spreads in spread spread_2 {
	reghdfe `spreads' `loan_level_controls' `extra_controls' if category == "Inst. Term" | category == "Bank Term" , absorb(borrower_facilitystartdate) residuals(`spreads'_resid_term_e) vce(cl borrowercompanyid)
	if "`spreads'" == "spread" {
		estadd local fe = "Borrower X Date"
		estimates store est`i'
		local ++i
	}
}


local loan_level_controls_no_param cov_lite maturity_* log_facilityamt_dec_*
foreach spreads in spread spread_2 {
	reghdfe `spreads' `loan_level_controls_no_param' `extra_controls' if category == "Inst. Term" | category == "Bank Term", absorb(borrower_facilitystartdate) residuals(`spreads'_resid_term_e_np) vce(cl borrowercompanyid)
	if "`spreads'" == "spread" {
		estadd local fe = "Borrower X Date"
		estimates store est`i'
		local ++i
	}

}
*Make it missing again
replace maturity = . if maturity_mi ==1
replace init_amort = . if maturity_mi ==1
replace num_quarters_first_payment = . if maturity_mi ==1

*Make a table with the coefficients for term loans only
esttab est* using "$regression_output_path/spreads_onto_controls_for_residalized_measure_term_only.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons *_mi) star(* 0.1 ** 0.05 *** 0.01) ///
title("Spreads and Loan Characteristics") scalars("fe Fixed Effects")  ///
addnotes("SEs clustered at firm level" "Sample are all loans" "Omitted categories are Maturity = [60,71) and Facility Amt Decile 1")	


foreach var in spread_resid spread_2_resid spread_resid_np spread_2_resid_np ///
	spread_resid_term spread_resid_term_e spread_resid_term_e_np	{
	egen m_`var' = mean(`var'), by(borrowercompanyid facilitystartdate category)
	gen m_`var'_inst_t = m_`var' if category == "Inst. Term"
	egen m_`var'_inst = max(m_`var'_inst_t), by(borrowercompanyid facilitystartdate)
	gen diff_`var' = m_`var'- m_`var'_inst if category == "Revolver" | category == "Bank Term"
	replace diff_obs = 1 if !mi(m_`var') & !mi(m_`var'_inst)
	drop m_`var'*
	local var_label: variable label `var'
	label var diff_`var' "D-`var_label'"
}


*Now rename the simple discounts
rename diff_spread discount_1_simple
rename diff_spread_2 discount_2_simple
rename diff_spread_resid discount_1_controls
rename diff_spread_2_resid discount_2_controls
rename diff_spread_resid_np discount_1_controls_np
rename diff_spread_2_resid_np discount_2_controls_np

*Want the direction of the discount to be in the right. Discount is inst_spread - bank_spread
*But want the differences to be the differences between the bank and the institutional - easier to interpret
replace discount_1_simple = discount_1_simple*-1
replace discount_2_simple = discount_2_simple*-1
replace discount_1_controls = discount_1_controls*-1
replace discount_2_controls = discount_2_controls*-1
replace discount_1_controls_np = discount_1_controls_np*-1
replace discount_2_controls_np = discount_2_controls_np*-1

*The term only spreads, we want to see how they look
foreach term_disc in diff_spread_resid_term diff_spread_resid_term_e diff_spread_resid_term_e_np {
	replace `term_disc' = `term_disc' * -1
	sum `term_disc', detail
	drop `term_disc'
}
*They are not important so we drop them

*Calculate the discount, residualized for loan level controls
foreach disc in discount_1 discount_2 {
	*Regress discount on loan characteristics
	reg `disc'_simple diff_* 
	predict `disc'_controls_diff, residual
	*Don't want to take out the constant so the level is interpretable
	replace `disc'_controls_diff =  `disc'_controls_diff + _b[_cons]
}

*label discount
label var discount_1_simple "Di-1-S"
label var discount_2_simple "Di-2-S"
label var discount_1_controls "Di-1-C"
label var discount_2_controls "Di-2-C"
label var discount_1_controls_np "Di-1-C-SP"
label var discount_2_controls_np "Di-2-C-SP"
label var discount_1_controls_diff "Di-1-C-Diff"
label var discount_2_controls_diff "Di-2-C-Diff"

*Create an indicator whether it is a discount obs or not (and subsets too) - these are at the package level
gen not_missing_discount_temp = !mi(discount_1_simple)
egen discount_obs = max(not_missing_discount_temp), by(borrowercompanyid facilitystartdate)
drop not_missing_discount_temp
gen not_missing_discount_temp = !mi(discount_1_simple) & category == "Revolver"
egen discount_obs_rev = max(not_missing_discount_temp), by(borrowercompanyid facilitystartdate)
drop not_missing_discount_temp
gen not_missing_discount_temp = !mi(discount_1_simple) & category == "Bank Term"
egen discount_obs_b_term = max(not_missing_discount_temp), by(borrowercompanyid facilitystartdate)
drop not_missing_discount_temp


*I only want one discount per package, so I will make a new variable that is the package discount
foreach disc in discount_1_simple discount_2_simple discount_1_controls discount_2_controls ///
	discount_1_controls_np discount_2_controls_np discount_1_controls_diff discount_2_controls_diff {
	
	gen `disc'_dup = `disc'
	local label: variable label `disc'
	label var `disc'_dup "`label' with duplicates"
	*Arbitrarily only keep the smallest facilityid discount so there aren't duplicates
	bys borrowercompanyid facilitystartdate category (facilityid): replace `disc' = . if _n>1
}


*Make buckets for discount
foreach spread_type in standard alternate {
	if "`spread_type'" == "standard" {
		local spread_suffix 1
	}
	if "`spread_type'" == "alternate" {
		local spread_suffix 2
	}
	
	foreach discount_type in simple controls controls_np controls_diff {
		
		gen d_`spread_suffix'_`discount_type'_le_0 = (discount_`spread_suffix'_`discount_type'<-10e-9) 
		gen d_`spread_suffix'_`discount_type'_0 = (discount_`spread_suffix'_`discount_type'>=-10e-9 & discount_`spread_suffix'_`discount_type' <=10e-9) 
		gen d_`spread_suffix'_`discount_type'_0_25 = (discount_`spread_suffix'_`discount_type'>=10e-9 & discount_`spread_suffix'_`discount_type' <=25+10e-9) 
		gen d_`spread_suffix'_`discount_type'_25_50 = (discount_`spread_suffix'_`discount_type'>=25+10e-9 & discount_`spread_suffix'_`discount_type' <=50+10e-9) 
		gen d_`spread_suffix'_`discount_type'_50_100 = (discount_`spread_suffix'_`discount_type'>=50+10e-9 & discount_`spread_suffix'_`discount_type' <=100+10e-9) 
		gen d_`spread_suffix'_`discount_type'_100_200 = (discount_`spread_suffix'_`discount_type'>=100+10e-9 & discount_`spread_suffix'_`discount_type' <=200+10e-9) 
		gen d_`spread_suffix'_`discount_type'_ge_200 = (discount_`spread_suffix'_`discount_type'>=200+10e-9)
		
		foreach var of varlist d_`spread_suffix'_`discount_type'_* {
			replace `var' = . if mi(discount_`spread_suffix'_`discount_type')
		}
		
		*Generate postive discount indicator
		gen d_`spread_suffix'_`discount_type'_pos = (discount_`spread_suffix'_`discount_type'>10e-9)
		replace d_`spread_suffix'_`discount_type'_pos = . if mi(discount_`spread_suffix'_`discount_type')
	}
}

label var d_1_simple_pos "Di-1-S Pos"
label var d_2_simple_pos "Di-2-S  Pos"
label var d_1_controls_pos "Di-1-C  Pos"
label var d_2_controls_pos "Di-2-C  Pos"
label var d_1_controls_diff_pos "Di-1-C  Pos"
label var d_2_controls_diff_pos "Di-2-C  Pos"

*Winsorize Discounts
winsor2 discount_*, replace cut(1 99)

drop category 
rename category_temp category

isid facilityid
*Merge on cusip_6
merge m:1 borrowercompanyid date_quarterly using "$data_path/stata_temp/compustat_with_bcid", keep(1 3) keepusing(cusip_6) nogen
save "$data_path/stata_temp/dealscan_discounts_facilityid", replace
*This dataset will contain all of the discoutn information but cannot be merged onto a quarterly panel - would require some adjustment.
foreach var in discount_1_simple discount_1_controls discount_2_simple discount_2_controls {
	gen temp_term_disc = `var' if category == "Bank Term" 
	egen temp_term_disc_sp = max(temp_term_disc), by(borrowercompanyid date_quarterly)
	gen temp_rev_disc = `var' if category == "Revolver" 
	egen temp_rev_disc_sp = max(temp_rev_disc), by(borrowercompanyid date_quarterly)
	*Drop the revolving discount and then recreate it so it is populated for all loans in the quarter x firm
	drop `var'
	*Create the term_discount, which will exist 
	gen term_`var' = temp_term_disc_sp
	gen rev_`var' = temp_rev_disc_sp
	drop temp*
	
}
keep borrowercompanyid rev_discount* term_discount_* date_quarterly
duplicates drop
isid borrowercompanyid date_quarterly 
save "$data_path/stata_temp/dealscan_discounts", replace
