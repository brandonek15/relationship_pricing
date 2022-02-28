*This program will make a lender x loan datasetload in the compustat data, merge on the dealscan data,

*Start with lender x facility dataset
use "$data_path/lender_facilityid_cusip6", clear
*Merge on lender information
merge 1:1 facilityid lender using "$data_path/dealscan_facility_lender_level", keep(1 3) nogen
*merge on discount information
merge m:1 facilityid using "$data_path/stata_temp/dealscan_discounts_facilityid", keep(1 3) nogen
*merge on accounting information
merge m:1 borrowercompanyid date_quarterly using "$data_path/stata_temp/compustat_with_bcid", keep(1 3)

save "$data_path/dealscan_compustat_lender_loan_level", replace

drop lender agent_credit lead_arranger_credit bankallocation lenderrole
duplicates drop

save "$data_path/dealscan_compustat_loan_level", replace
