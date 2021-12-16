*This program will load in the compustat data, merge on the dealscan data,
*And make a dataset set up for doing summary stats at origination
*And for the regression analysis.
use "$data_path/compustat_clean", clear
isid gvkey date_quarterly
*Only keep observations that can match to dealscan and springing cov
drop if mi(borrowercompanyid)
drop if mi(cik)
*Sometimes two compustat firms have the same borrowercompanyid
*When this happens, keep the one with the higher assets and if they are still tied, the one with the larger cik
bys borrowercompanyid date_quarterly (atq cik): keep if _n == _N

*Now we add dealscan data to the panel
isid borrowercompanyid date_quarterly
merge 1:m borrowercompanyid date_quarterly using ///
 "$data_path/dealscan_facility_level", keep(1 3)
gen matched_dealscan = (_merge ==3)
drop _merge

*Now I have dealscan observations with compustat data (and thus cusips)
*Think about how I want to merge here? Will be merging based on variable cusip_6
*I imagine having a quarterly panel of all compustat firms. I will have
*Can only merge m:1 on either dealscan or 
