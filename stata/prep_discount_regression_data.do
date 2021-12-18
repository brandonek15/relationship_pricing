*Get the facility level data
use "$data_path/dealscan_facility_level", clear
*Keep only observations that are a term loan and revolving line of credit
keep if term_loan ==1 | rev_loan ==1

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

		reghdfe `spread_var' `controls', absorb(borrowerid_rev_loan_quarter, savefe) keepsingletons
		rename __hdfe1__ fe_coeff
		*Need to spread the fe_coeff by
		gen fe_coeff_term = fe_coeff if rev_loan==0
		gen fe_coeff_rev = fe_coeff if rev_loan ==1
		egen fe_coeff_term_sp = max(fe_coeff_term), by(borrowercompanyid)
		egen fe_coeff_rev_sp = max(fe_coeff_rev), by(borrowercompanyid)
		gen rev_discount_`spread_suffix'_`discount_type' = fe_coeff_term_sp - fe_coeff_rev_sp
		drop fe_coeff*
	}
}
sort borrowercompanyid rev_loan facilityid
br borrowercompanyid facilityid rev_loan rev_discount*
*Now I only want to keep the borrowercompanyid and rev_discounts
keep borrowercompanyid rev_discount* date_quarterly
duplicates drop
isid borrowercompanyid date_quarterly
save "$data_path/stata_temp/dealscan_discounts", replace
