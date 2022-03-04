*Get the facility level data
use "$data_path/dealscan_facility_level", clear

*I will make four categories of loans: revolvers (relationship loans), non-institutional term loans (relationship loans)
*institional term loans (market loans) and other loans (not considering them)

*I will use borrower x quarter x category fixed effects.
*This gives me an coefficient for for borrower x quarter x revolving, borrower x quarter x non-institutional term
* and borrower x quarter x institutional term loans (through the FE). 
*The difference between revolving and institutional and non-institutional and instittuional term loanwill give me the "discount
gen category = ""
replace category = "Revolver" if rev_loan ==1
replace category = "Inst. Term" if term_loan ==1 & institutional ==1
replace category = "Bank Term" if term_loan ==1 & institutional ==0
replace category = "Other" if other_loan==1
assert !mi(category)

egen borrowerid_rev_loan_quarter = group(borrowercompanyid date_quarterly category)
*Loop over different measures of the discount
foreach spread_type in standard alternate {
	if "`spread_type'" == "standard" {
		local spread_var spread
		local spread_suffix 1
	}
	if "`spread_type'" == "alternate" {
		local spread_var spread_2
		local spread_suffix 2
	}
	
	foreach discount_type in simple controls {
	
		if "`discount_type'" == "simple" {
			local controls 
		}
		if "`discount_type'" == "controls" {
			local controls log_facilityamt maturity
		}
		*Only want term and rev_loan obs in the regression
		reghdfe `spread_var' `controls' if term_loan ==1 | rev_loan ==1, absorb(borrowerid_rev_loan_quarter, savefe) keepsingletons
		rename __hdfe1__ fe_coeff
		*Need to spread the fe_coeff by
		gen fe_coeff_term_ins = fe_coeff if category == "Inst. Term"
		gen fe_coeff_term_bank = fe_coeff if category == "Bank Term"
		gen fe_coeff_rev = fe_coeff if category == "Revolver"
		egen fe_coeff_term_ins_sp = max(fe_coeff_term_ins), by(borrowercompanyid date_quarterly)
		egen fe_coeff_term_bank_sp = max(fe_coeff_term_bank), by(borrowercompanyid date_quarterly)
		egen fe_coeff_rev_sp = max(fe_coeff_rev), by(borrowercompanyid date_quarterly)
		gen discount_`spread_suffix'_`discount_type' = fe_coeff_term_ins_sp - fe_coeff_rev_sp if category == "Revolver"
		replace discount_`spread_suffix'_`discount_type' = fe_coeff_term_ins_sp - fe_coeff_term_bank_sp if category == "Bank Term"
		*Don't want this to be populated for other loans or institutional term loans
		replace discount_`spread_suffix'_`discount_type' = . if other_loan ==1 | category == "Inst. Term"

		drop fe_coeff*
	}
}
sort borrowercompanyid date_quarterly rev_loan facilityid
/*
br borrowercompanyid date_quarterly packageid facilityid rev_loan discount* ///
 allindrawn spread spread_2
*/
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
