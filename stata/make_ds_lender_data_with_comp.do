*This program will make a lender x loan datasetload in the compustat data, merge on the dealscan data,

use "$data_path/dealscan_facility_lender_level", clear
keep if lead_arranger_credit ==1

*For now keep both that can be matched to compustat and those that cannot, which are those that can match to compustat.
merge m:1 borrowercompanyid date_quarterly using "$data_path/stata_temp/compustat_with_bcid", keep(1 3)
gen merge_compustat = _merge ==3
drop _merge
*Want to make the merge_ratings = 0 if missing
replace merge_ratings = 0 if mi(merge_ratings)
*Want to create my three categories of observations - merge ratings, merge compustat but no ratings, and no compustat
gen merge_compustat_no_ratings = (merge_compustat==1 & merge_ratings==0)
gen no_merge_compustat = (merge_compustat==0)
label var merge_ratings "Comp Firm w/ Ratings"
label var merge_compustat_no_ratings "Comp Firm w/out Ratings"
label var no_merge_compustat "Non Comp Firm"
sort borrowercompanyid date_quarterly cusip_6
*merge on discount information
merge m:1 facilityid using "$data_path/stata_temp/dealscan_discounts_facilityid", keep(1 3) nogen
*Create an indicator whether it is a discount obs or not
gen not_missing_discount_temp = !mi(discount_1_simple)
egen discount_obs = max(not_missing_discount_temp), by(borrowercompanyid date_quarterly)
drop not_missing_discount_temp
gen constant = 1
*Spread Cusip_6 by borrowercompanyid
*Implicitly assuming that the cusip_6 for the borrowercompanyid will be the same as it would be in the future
bys borrowercompanyid (date_quarterly): replace cusip_6 = cusip_6[_n+1] if mi(cusip_6)
*Make an indicator for an DS observation not matched to compustat but that we infer a cusip 
*because they will be in compustat in the future. Basically "private" firms that will end up becoming public
gen pre_compustat_with_cusip = (!mi(cusip_6) & mi(cusip))

*Make ratings_obs_type interactions
foreach ratings_obs_type in no_merge_compustat merge_compustat_no_ratings merge_ratings {
	gen nprev_`ratings_obs_type' = no_prev_lender*`ratings_obs_type'
	gen prev_`ratings_obs_type' = prev_lender*`ratings_obs_type'
	gen first_`ratings_obs_type' = first_loan*`ratings_obs_type'
	gen switc_`ratings_obs_type' = switcher_loan*`ratings_obs_type'
	
	local label: variable label `ratings_obs_type'
	label var nprev_`ratings_obs_type' "No Prev Lend Rel. x `label'"
	label var prev_`ratings_obs_type' "Prev Lend Rel. x `label'"
	label var first_`ratings_obs_type' "First Loan x `label'"
	label var switc_`ratings_obs_type' "Switching Lend x `label'"

	
}

*Save a loan x lender file
save "$data_path/dealscan_compustat_lender_loan_level", replace
drop lender agent_credit lead_arranger_credit bankallocation lenderrole
duplicates drop
*Save a loan level file
save "$data_path/dealscan_compustat_loan_level", replace
