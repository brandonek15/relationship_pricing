*This program will load in the compustat data, merge on the dealscan data,
*And make the merged dataset for all of the analyses.
*Todo: Update merges so they don't keep everything

*First, we need to only use the observations that bcid to merge onto dealscan. Then we will append
*The rest of compustat later
use "$data_path/stata_temp/compustat_with_bcid", clear
isid cusip_6 date_quarterly
isid borrowercompanyid date_quarterly
merge 1:1 borrowercompanyid date_quarterly using "$data_path/dealscan_quarterly", keep(1 3)
rename _merge merge_dealscan

*Append compustat without bcid
append using "$data_path/stata_temp/compustat_without_bcid"
isid cusip_6 date_quarterly

*Merge on SDC data
*Merge doesn't get everything but that is okay. Sometimes it is private, so won't be in compustat. Othertiems
*The company is not around anymore, othertimes it isn't merged bc the IPO would occur before there is compustat data.
merge 1:1 cusip_6 date_quarterly using "$data_path/sdc_equity_clean_quarterly", update
rename _merge merge_equity

merge 1:1 cusip_6 date_quarterly using "$data_path/sdc_conv_clean_quarterly", update
rename _merge merge_conv

merge 1:1 cusip_6 date_quarterly using "$data_path/sdc_debt_clean_quarterly", update
rename _merge merge_debt
isid cusip_6 date_quarterly

isid cusip_6 date_quarterly
save "$data_path/merged_data_comp_quart", replace
*Summary of what we are looking at
br cusip_6 date_quarterly merge_dealscan term_loan rev_loan other_loan rev_discount_1_simple ///
rev_discount_1_controls rev_discount_2_simple rev_discount_2_controls merge_equity  ///
gross_spread_dol_equity gross_spread_perc_equity proceeds_equity merge_conv ///
gross_spread_dol_conv gross_spread_perc_conv proceeds_conv merge_debt ///
gross_spread_dol_debt gross_spread_perc_debt proceeds_debt
