*This program will load in the compustat data, merge on the dealscan data,
*And make a dataset set up for doing summary stats at origination
*And for the regression analysis.
use "$data_path/compustat_clean", clear

*Merge on SDC data
*Todo look into why I am not merging more of these? Cusip6 seems not to be working super well
merge 1:1 cusip_6 date_quarterly using "$data_path/sdc_equity_clean_quarterly"
rename _merge merge_equity

merge 1:1 cusip_6 date_quarterly using "$data_path/sdc_conv_clean_quarterly"
rename _merge merge_conv

merge 1:1 cusip_6 date_quarterly using "$data_path/sdc_debt_clean_quarterly"
rename _merge merge_debt

joinby borrowercompanyid date_quarterly using "$data_path/dealscan_facility_level", ///
unmatched(master) _merge(dealscan_merge_cat)
*Now I have a dataset that may have multiple observations for the same cusip_6 date_quarterly if there are multiple
*Facilities. It is a company x quarter x facility dataset
save "$data_path/merged_data_comp_quart_fac", replace

*Todo - Go to the end of clean_dealscan and figure out a way make it quarterly with the metrics I want.
*Todo - find out a good way to link identities of lenders/ boorunners/managers
