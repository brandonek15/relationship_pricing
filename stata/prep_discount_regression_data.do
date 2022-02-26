*Get the facility level data
use "$data_path/dealscan_facility_level", clear

*I will use facilityid x revolving fixed effects.
*This gives me an coefficient for for facility id x  revolving and facilityid x term (through the FE). 
*The difference between the two will give me the "discount"
egen borrowerid_rev_loan_quarter = group(borrowercompanyid rev_loan date_quarterly)
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
		gen fe_coeff_term = fe_coeff if rev_loan==0
		gen fe_coeff_rev = fe_coeff if rev_loan ==1
		egen fe_coeff_term_sp = max(fe_coeff_term), by(borrowercompanyid date_quarterly)
		egen fe_coeff_rev_sp = max(fe_coeff_rev), by(borrowercompanyid date_quarterly)
		gen rev_discount_`spread_suffix'_`discount_type' = fe_coeff_term_sp - fe_coeff_rev_sp
		*Don't want this to be populated for other loans
		replace rev_discount_`spread_suffix'_`discount_type' = . if other_loan ==1
		*Want the "discount" to be the negative amount if it is a term loan because I want it then to "term-revolver"
		replace rev_discount_`spread_suffix'_`discount_type' = -rev_discount_`spread_suffix'_`discount_type' if term_loan ==1

		drop fe_coeff*
	}
}
sort borrowercompanyid date_quarterly rev_loan facilityid
/*
br borrowercompanyid date_quarterly packageid facilityid rev_loan rev_discount* ///
 allindrawn spread spread_2
*/
isid facilityid
*Merge on cusip_6
merge m:1 borrowercompanyid date_quarterly using "$data_path/stata_temp/compustat_with_bcid", keep(1 3) keepusing(cusip_6) nogen
save "$data_path/stata_temp/dealscan_discounts_facilityid", replace
*Now I only want to keep the borrowercompanyid and rev_discounts
keep if rev_loan ==1
keep borrowercompanyid rev_discount* date_quarterly
duplicates drop
isid borrowercompanyid date_quarterly
save "$data_path/stata_temp/dealscan_discounts", replace
