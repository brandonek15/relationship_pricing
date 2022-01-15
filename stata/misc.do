*Random stuff to explore data
use "$data_path/sdc_equity_clean", clear

bys cusip_6 date_quarterly (date_daily): gen N = _N

local collapse_vars sec_type
local max_vars ipo debt equity convertible
local last_vars issuer business_desc currency bookrunners all_managers
local sum_vars management_fee_dol underwriting_fee_dol selling_conc_dol ///
	reallowance_dol gross_spread_dol proceeds_local num_units
local mean_vars gross_spread_per_unit gross_spread_perc management_fee_perc underwriting_fee_perc ///
	selling_conc_perc reallowance_perc 
local weight_var proceeds_local

collapse (rawsum) `sum_vars' (max) `max_vars' (last) `last_vars' ///
	(mean) `mean_vars' [aweight=`weight_var'], by(cusip_6 date_quarterly)

foreach var in `sum_vars' `mean_vars' {
	replace `var' = . if `var' ==0
}

rename proceeds_local proceeds
*Most important variables: The gross spread_percent, gross_spread_dollar, the proceeds, the cusip_6 and the date_quarterly
*From here I have whether there is a deal (make an indicator for whether it gets merged on?
*And then I also have data on the "price" and the size
isid cusip_6 date_quarterly


*Todo, figure out how to deal with bookrunners? some sort of egen to combine information? Need to standardize names


use "$data_path/compustat_clean", clear
bys cusip_6 date_quarterly: gen N = _N

use "$data_path/dealscan_quarterly", clear

*

/* If I want to merge a different way
joinby borrowercompanyid date_quarterly using "$data_path/dealscan_facility_level", ///
unmatched(master) _merge(dealscan_merge_cat)
*Now I have a dataset that may have multiple observations for the same cusip_6 date_quarterly if there are multiple
*Facilities. It is a company x quarter x facility dataset
save "$data_path/merged_data_comp_quart_fac", replace

use "$data_path/merged_data_comp_quart", clear
sort cusip_6 date_quarterly
br merge_equity conm issuer_equity date_quarterly cusip_6 cusip cik public_equity private_equity withdrawn_equity
br conm issuer_equity cik date_quarterly merge_equity  cusip_6 borrowercompanyid  merge_dealscan
br merge_equity conm issuer_equity date_quarterly cusip_6 cusip cik public private withdrawn if merge_equity == 2
*/

*Start standardizing bookrunners
use "$data_path/sdc_equity_clean", clear
br issuer date_daily bookrunners all_managers bookrunner_*
replace bookrunner_1 = subinstr(bookrunner_1,",","",.)
