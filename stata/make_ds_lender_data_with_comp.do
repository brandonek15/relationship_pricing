*This program will make a lender x loan datasetload in the compustat data, merge on the dealscan data,

use "$data_path/dealscan_facility_lender_level", clear
keep if lead_arranger_credit ==1

*For now keep both that can be matched to compustat and those that cannot, which are those that can match to compustat.
merge m:1 borrowercompanyid date_quarterly using "$data_path/stata_temp/compustat_with_bcid", keep(1 3)
gen merge_compustat = _merge ==3
drop _merge
sort borrowercompanyid date_quarterly cusip_6
*merge on discount information
merge m:1 facilityid using "$data_path/stata_temp/dealscan_discounts_facilityid", keep(1 3) nogen
*Create an indicator whether it is a discount obs or not
gen not_missing_discount_temp = !mi(discount_1_simple)
egen discount_obs = max(not_missing_discount_temp), by(borrowercompanyid date_quarterly)
drop not_missing_discount_temp
gen constant = 1
*Save a loan x lender file
save "$data_path/dealscan_compustat_lender_loan_level", replace
drop lender agent_credit lead_arranger_credit bankallocation lenderrole
duplicates drop
*Save a loan level file
save "$data_path/dealscan_compustat_loan_level", replace
