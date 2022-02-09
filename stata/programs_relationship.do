*This defines the skeleton making program
cap program drop make_skeleton
program define make_skeleton
	args type num_lenders

	if "`type'" == "sdc" {
		local dataset "$data_path/sdc_all_clean"
		local id sdc_deal_id
	}
	if "`type'" == "ds" {
		local dataset "$data_path/stata_temp/dealscan_discounts_facilityid"
		local id facilityid
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

*
cap program drop fill_out_skeleton
program define fill_out_skeleton
	args type base_vars sdc_vars ds_vars ds_lender_vars

	if "`type'" == "sdc" {
		local base_dataset "$data_path/sdc_deal_bookrunner"
		local base_dataset_info "$data_path/sdc_all_clean"
		local id sdc_deal_id
	}
	else if "`type'" == "ds" {
		local base_dataset "$data_path/lender_facilityid_cusip6"
		local base_dataset_info "$data_path/stata_temp/dealscan_discounts_facilityid"
		local id facilityid
	}


	*Now merge on who was truly a lender on the deal
	merge 1:1 `id' lender using "`base_dataset'", keep(1 3)
	gen hire = (_merge ==3)
	labe var hire "Hire"
	drop cusip_6 _merge

	*Get basic deal characteristics I always want
	merge m:1 `id' using "`base_dataset_info'", keepusing(date_daily cusip_6) assert(3) nogen

	*Now get the deal characteristics you want from the current sdc_deal 
	merge m:1 `id' using "`base_dataset_info'", keepusing(`base_vars') assert(3) nogen
	foreach var of local base_vars {
		rename `var' `var'_base
	}

	*I am making 6 types of matches. For each type of match, first I merge on the most recent match for each
	*deal id x lender. Then I get the relevant variables by using the id

	foreach subset_type in equity debt conv rev_loan term_loan other_loan {
		if "`subset_type'" == "equity" | "`subset_type'" == "debt" | "`subset_type'" == "conv" {
			local subset_deal_data "$data_path/sdc_all_clean"
			local subset_id sdc_deal_id
			local merge_vars `sdc_vars'
		}
		else if "`subset_type'" == "rev_loan" | "`subset_type'" == "term_loan" | "`subset_type'" == "other_loan" {
			local subset_deal_data "$data_path/stata_temp/dealscan_discounts_facilityid"
			local subset_id facilityid
			local merge_vars `ds_vars'
		}
		*Get the most recent matches
		merge 1:1 `id' lender using "$data_path/stata_temp/matches_`type'_`subset_type'", keep(1 3) nogen
		*Now rename the base `id' for mergin reasons
		rename `id' `id'_base
		*Now merge on the information from that past relationship (but first need to rename `subset_id'_`subset_type' to `subset_id'
		rename `subset_id'_`subset_type' `subset_id'
		*In order for merge to work, need to make it not be missing
		replace `subset_id' = -1 if mi(`subset_id')
		merge m:1 `subset_id' using `subset_deal_data', keepusing(`merge_vars') keep(1 3)
		*Generate an indicator for relationship_`subset_type'
		gen rel_`subset_type' = (_merge==3)
		drop _merge

		*If I am dealing with ds data, want to merge on data about lender
		if "`subset_type'" == "rev_loan" | "`subset_type'" == "term_loan" | "`subset_type'" == "other_loan" {
			*We will also merge on lender information
			merge m:1 `subset_id' lender using "$data_path/dealscan_facility_lender_level", ///
			keepusing(`ds_lender_vars') keep(1 3) nogen
			local rename_add `ds_lender_vars'
		}
		else {
			local rename_add 
		}
		di "got here"
		*Make them missing again
		replace `subset_id' = . if `subset_id'==-1
		*Rename all of the variables with the suffix _`subset_type'
		foreach var in `merge_vars' `subset_id' `rename_add' {
			rename `var' `var'_`subset_type'
		}
		*Need to rename `id'_base back to its original form
		rename `id'_base `id' 
	}


end
