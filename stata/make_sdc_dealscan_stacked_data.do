*This program will stack the dealscan loan x lender dataset onto the sdc deal x bookrunner dataset and make many measures
use "$data_path/sdc_deal_compustat_bookrunner_level", clear
append using "$data_path/dealscan_compustat_lender_loan_level"

egen sdc_obs = rowmax($sdc_types)
egen ds_obs = rowmax($ds_types)


tostring sdc_deal_id, replace
tostring facilityid, replace

gen deal_id = "SDC-" + sdc_deal_id if sdc_obs ==1
replace deal_id = "DS-" + facilityid if ds_obs ==1

order deal_id cusip_6 borrowercompanyid date_daily date_quarterly lender $sdc_types $ds_types
sort cusip_6 date_daily borrowercompanyid

*Now I have a stacked dataset with all observations.
save "$data_path/sdc_ds_stacked_all", replace

*Now let's just keep observations that we have a cusip_6 for (compustat observations +sdc) "roughly public firms"
use "$data_path/sdc_ds_stacked_all", clear
drop if mi(cusip_6)
