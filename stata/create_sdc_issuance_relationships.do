*This program will create a dataset where each observation is a "lender" x sdc_deal_id
* and the set of lenders is the set of biggest lenders/bookrunners
*Then it will merge on the most recent information from an equity, debt, conv offering
*and term, revolving, and other loan from the same lender.

*Make a skeleton dataset

cap program drop make_skeleton
program define make_skeleton
	args type num_lenders

	if "`type'" == "sdc" {
		local dataset "$data_path/sdc_all_clean"
		local id sdc_deal_id
	}
	*First we will get the set of "lenders" in both SDC and dealscan
	use "$data_path/sdc_deal_bookrunner", clear
	append using "$data_path/lender_facilityid_cusip6", gen(type)
	bys lender: gen N = _N 
	assert type == 1 if mi(sdc_deal_id)
	assert type == 0 if mi(facilityid)
	gen sdc_deal = (type==1)
	gen ds_deal = (type==0)
	*Get a list of the "lenders" that are in both
	egen total_lender_obs_ds = total(sdc_deal), by(lender)
	egen total_lender_obs_sdc = total(ds_deal), by(lender)

	keep if total_lender_obs_ds >0 & total_lender_obs_sdc >0
	keep lender N
	duplicates drop
	gsort -N
	keep if _n<=`num_lenders'
	*store them as a local 
	levelsof lender, local(lenders)

	*Now make the skeleton dataset
	use "`dataset'", clear
	keep `id'
	local expand = `num_lenders'
	expand `expand'
	gen lender = ""
	bys `id': gen n = _n
	*Now manually generate the sdc_deal_id by
	local i = 1
	di `"`lenders'"'
	foreach lender of local lenders {
		replace	lender = "`lender'" if n == `i'
		local i = `i' + 1 
	}
	drop n
end

*First need to prepare basic datasets for the "past relationships." Will eventually do joinbys to do the matches.
*Make SDC ones first. ONly contain the cusip_6 lender and sdc_deal_id
use "$data_path/sdc_deal_bookrunner", clear
merge m:1 sdc_deal_id using "$data_path/sdc_all_clean", keepusing(equity debt conv) keep(3) nogen
foreach sdc_type in equity debt conv {
	preserve
		keep if `sdc_type' ==1
		drop equity debt conv
		save "$data_path/stata_temp/sdc_deal_bookrunner_`sdc_type'" , replace
	restore	
}
*Make the Dealscan datasets. Only contains the cusip_6 lender and facilityid
use "$data_path/lender_facilityid_cusip6", clear
merge m:1 facilityid using "$data_path/stata_temp/dealscan_discounts_facilityid", keepusing(rev_loan term_loan other_loan) keep(3) nogen
foreach ds_type in rev_loan term_loan other_loan {
	preserve
		keep if `ds_typetype' ==1
		drop rev_loan term_loan other_loan
		save "$data_path/stata_temp/lender_facilityid_cusip6_`ds_type'", replace
	restore	
}

*todo Make sure this works and potentially move it to another program
*Make the join datasets for matches - will get the most recent match for a cusip_6 lender pair
local base_type sdc
local burner_days 90 //This says that if I am getting matches from the same source, drop matches within X days bc they are likely the same transaction
if "`base_type'" == "sdc" {
	local base_dataset "$data_path/sdc_deal_bookrunner"
	local base_dataset_info "$data_path/sdc_all_clean"
	local id sdc_deal_id
}
use `base_dataset', clear
*Merge on the date of the sdc_deal_id
merge m:1 `id' using "`base_dataset_info'", keepusing(date_daily) keep(3) nogen
rename date_daily date_daily_base
rename `id' `id'_base
*I am making 6 types of matches,
foreach subset_type in /* equity debt conv */ rev_loan term_loan other_loan {
	*If they are derived from SDC, then need to note these
	if "`subset_type'" == "equity" | "`subset_type'" == "debt" | "`subset_type'" == "conv" {
		local subset_match_data "$data_path/stata_temp/sdc_deal_bookrunner_`subset_type'"
		local subset_deal_data "$data_path/sdc_all_clean"
		local subset_id sdc_deal_id
	}
	else if "`subset_type'" == "rev_loan" | "`subset_type'" == "term_loan" | "`subset_type'" == "other_loan" {
		local subset_match_data "$data_path/stata_temp/lender_facilityid_cusip6_`subset_type'"
		local subset_deal_data "$data_path/stata_temp/dealscan_discounts_facilityid"
		local subset_id facilityid
	}
	preserve
		*Get matches
		joinby lender cusip_6 using  `subset_match_data' , unmatched(none)
		*Get date for the matches
		merge m:1 `subset_id' using `subset_deal_data' , keepusing(date_daily) keep(3) nogen
		*Rename newly merged variables and the date
		rename date_daily date_daily_`subset_type'
		rename `subset_id' `subset_id'_`subset_type'
		*Rename the baseline identifier back to the original name bc it will be used for merges later
		rename `id'_base `id'

		*Now I want to only keep deals such that the baseline occurs after the match
		gen days_after_match = date_daily_base-date_daily_`subset_type'
		keep if days_after_match>0
		if ("`base_type'" == "sdc" & "`subset_id'" == "sdc_deal_id") | ("`base_type'" == "ds" & "`subset_id'" == "facilityid") {
			*We need a burner period to deal with transactions that are likely the same
			drop if days_after_match<=`burner_days'
		}
		*Keep only the most recent transaction for each (the one with the smallest days between)
		bys `id' lender (days_after_match): keep if _n ==1
		rename days_after_match days_after_match_`subset_type'
		isid `id' lender
		save "$data_path/stata_temp/matches_`base_type'_`subset_type'", replace 
	restore
}


*Merge on the date


*Get this to work for equity specifically and then generally

*Want be

*Make
use "$data_path/lender_facilityid_cusip6", clear









*As inputs it will take the following:
*Number of lenders per deal
local n_lenders 20
*Get the skeleton dataset (sdc_deal_id x lender)
make_skeleton "sdc" `n_lenders'

*Now merge on who was truly a lender on the deal
merge 1:1 sdc_deal_id lender using "$data_path/sdc_deal_bookrunner", keep(1 3)
gen hire = (_merge ==3)
drop cusip_6 _merge

*Get basic deal characteristics I always want
merge m:1 sdc_deal_id using "$data_path/sdc_all_clean", keepusing(issuer date_daily cusip_6) assert(3) nogen

*Now get the deal characteristics you want from the current sdc_deal
local sdc_char_current equity debt conv gross_spread_perc 
merge m:1 sdc_deal_id using "$data_path/sdc_all_clean", keepusing(`sdc_char_current') assert(3) nogen
foreach var of local sdc_char_current {
	rename `var' `var'_current
}

*Before I do all of the need the following datasets sdc_deal, sdc_equity sdc_conv, ds_term ds_rev ds_other
*These will contain just id and lenders

*Now I will merge on the "most recent" of each type of deal. Will keep just the deal_id.

*For each of these most recent relationships, want to get some information.

*First get the list of biggest "lenders"
use "$data_path/sdc_deal_bookrunner", clear
bys lender: gen N = _N 
tab lender if N >500

use "$data_path/lender_facilityid_cusip6", clear
bys lender: gen N = _N 
tab lender if N >500

/*
use "$data_path/sdc_all_clean", clear
isid sdc_deal_id
use "$data_path/stata_temp/dealscan_discounts_facilityid", clear
isid facilityid
use "$data_path/sdc_deal_bookrunner", clear
isid sdc_deal_id lender
use "$data_path/lender_facilityid_cusip6", clear
isid facilityid lender
*/
