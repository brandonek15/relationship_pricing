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
*Todo look into why I am not merging more of these? Cusip6 seems not to be working super well
merge 1:1 cusip_6 date_quarterly using "$data_path/sdc_equity_clean_quarterly"
rename _merge merge_equity

merge 1:1 cusip_6 date_quarterly using "$data_path/sdc_conv_clean_quarterly"
rename _merge merge_conv

merge 1:1 cusip_6 date_quarterly using "$data_path/sdc_debt_clean_quarterly"
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

*Todo - find out a good way to link identities of lenders/ boorunners/managers
*Todo - put identifies of lenders/shares into dealscan quarterly (using facilityid)
*Need to think of a good way to look over time. We have our firm identifier (cusip_6) and all the info we would need
*
