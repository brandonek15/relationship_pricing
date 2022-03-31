*This program will prepare the necessary datasets needed to merge on later in the do file that makes the final dataset for 
*understanding past relationships

*Load the programs.
do "$code_path/programs_relationship"

*INPUT
*Number of lenders per deal
local n_lenders 20

*Create the skeleton datasets and save them
foreach base_type in "sdc" "ds" {
	*Get the skeleton dataset (sdc_deal_id x lender)
	make_skeleton "`base_type'" `n_lenders'
	save "$data_path/stata_temp/skeleton_`base_type'_`n_lenders'" , replace
}

*First need to prepare datasets for joining on cusip_6 lender." Will eventually do joinbys to do the matches.
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
*Only want to keep lead arrangers in the dataset as a part of the relationship - don't have relationships with everyone
merge m:1 facilityid lender using "$data_path/dealscan_facility_lender_level", ///
keepusing(lead_arranger_credit) keep(1 3) nogen
keep if lead_arranger_credit ==1
drop lead_arranger_credit

foreach ds_type in rev_loan term_loan other_loan {
	preserve
		keep if `ds_type' ==1
		drop rev_loan term_loan other_loan
		save "$data_path/stata_temp/lender_facilityid_cusip6_`ds_type'", replace
	restore	
}

*Make the join datasets for matches - will get the most recent match for a cusip_6 lender pair
local burner_days 90 //This says that if I am getting matches from the same source, drop matches within X days bc they are likely the same transaction

foreach base_type in sdc ds {

	if "`base_type'" == "sdc" {
		local base_dataset "$data_path/stata_temp/skeleton_`base_type'_`n_lenders'"
		local base_dataset_info "$data_path/sdc_all_clean"
		local id sdc_deal_id
	}
	else if "`base_type'" == "ds" {
		local base_dataset "$data_path/stata_temp/skeleton_`base_type'_`n_lenders'"
		local base_dataset_info "$data_path/stata_temp/dealscan_discounts_facilityid"
		local id facilityid
	}

	use `base_dataset', clear
	*Merge on the date of the sdc_deal_id
	merge m:1 `id' using "`base_dataset_info'", keepusing(date_daily cusip_6) keep(3) nogen
	rename date_daily date_daily_base
	rename `id' `id'_base
	*I am making 6 types of matches,
	foreach subset_type in equity debt conv rev_loan term_loan other_loan {
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
			*Save it to be merged on later
			isid `id' lender
			keep `id' lender `subset_id'_`subset_type' date_daily_`subset_type' days_after_match_`subset_type'
			save "$data_path/stata_temp/matches_`base_type'_`subset_type'_`n_lenders'", replace 
		restore
	}

}
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
