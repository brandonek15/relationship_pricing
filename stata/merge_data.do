*This program will load in the compustat data, merge on the dealscan data,
*And make a dataset set up for doing summary stats at origination
*And for the regression analysis.
use "$data_path/compustat_clean", clear

*Todo look into why I am not merging more of these?
merge 1:1 cusip_6 date_quarterly using "$data_path/sdc_equity_clean_quarterly"
rename _merge merge_equity

merge 1:1 cusip_6 date_quarterly using "$data_path/sdc_conv_clean_quarterly"
rename _merge merge_conv

*Merge on SDC data

*Sometimes two compustat firms have the same borrowercompanyid
*When this happens, keep the one with the higher assets and if they are still tied, the one with the larger cik
bys borrowercompanyid date_quarterly (atq cik): keep if _n == _N
isid borrowercompanyid date_quarterly


*Now we add dealscan data to the panel
merge 1:m borrowercompanyid date_quarterly using ///
 "$data_path/dealscan_facility_level", keep(1 3)
gen matched_dealscan = (_merge ==3)
drop _merge

*Now I have dealscan observations with compustat data (and thus cusips)
*Think about how I want to merge here? Will be merging based on variable cusip_6
*I imagine having a quarterly panel of all compustat firms. I will have
*Can only merge m:1 on either dealscan or 
