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
	args type base_vars sdc_vars ds_vars ds_lender_vars n_lenders

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
	label var hire "Hire"
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
		merge 1:1 `id' lender using "$data_path/stata_temp/matches_`type'_`subset_type'_`n_lenders'", keep(1 3) nogen
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

*This program does a bunch of things to the dataset to prepare it for analyses
cap program drop prepare_rel_dataset
program define prepare_rel_dataset
	*Create past relationship dummy and FEs
	egen past_relationship = rowmax(rel_equity rel_debt rel_conv rel_rev_loan rel_term_loan rel_other_loan)
	label var past_relationship "Rel."
	gen constant = 1
	egen cusip_6_lender = group(cusip_6 lender)
	egen lender_relationship = group(lender past_relationship)
	*Make hire 0 or 100 for readability
	replace hire = hire*100

	label var rel_equity "Rel. Equity"
	label var rel_debt "Rel. Debt"
	label var rel_conv "Rel. Convertible"
	label var rel_rev_loan "Rel. Revolver"
	label var rel_term_loan "Rel. Term Loan"
	label var rel_other_loan "Rel. Other Loan"
	
	*Make labels for lhs variables
	cap label var discount_1_simple_base "Disc"
	cap label var spread_base "Sprd"
	cap label var log_facilityamt_base "Lg-Amt"
	cap label var maturity_base "Matu"
	cap label var gross_spread_perc_base "Fee"
	cap label var log_proceeds_base "Lg-Amt"

	*Create some interaction variables. These are 0 if there is no previous relationship (or it is missing), and the value otherwise
	*Note in specifications, having the relationship dummy is all we need whenever the variable is never missing, but we also need to
	*add the missing dummy if it is missing when the relationships exists (e.g. discount_1_simple)
	foreach ds_type in rev_loan term_loan other_loan {

		foreach ds_inter_var in discount_1_simple spread maturity log_facilityamt ///
		agent_credit lead_arranger_credit bankallocation days_after_match {

			if "`ds_inter_var'" == "discount_1_simple" {
				local label "Disc"
			}
			if "`ds_inter_var'" == "spread" {
				local label "Sprd"
			}
			if "`ds_inter_var'" == "maturity" {
				local label "Maturity"
			}
			if "`ds_inter_var'" == "log_facilityamt" {
				local label "Lg-Amt"
			}
			if "`ds_inter_var'" == "agent_credit" {
				local label "Agent"
			}
			if "`ds_inter_var'" == "lead_arranger_credit" {
				local label "Lead Arranger"
			}
			if "`ds_inter_var'" == "bankallocation" {
				local label "Loan Share"
			}
			if "`ds_inter_var'" == "days_after_match" {
				local label "Days Between Rel."
			}
				
			if "`ds_type'" == "rev_loan" {
				local type_name "rev"
			}
			if "`ds_type'" == "term_loan" {
				local type_name "term"
			}
			if "`ds_type'" == "other_loan" {
				local type_name "other"
			}
		
			gen i_`ds_inter_var'_`type_name' = 0
			replace i_`ds_inter_var'_`type_name' = `ds_inter_var'_`ds_type'*rel_`ds_type' if !mi(`ds_inter_var'_`ds_type')
			gen mi_`ds_inter_var'_`type_name' = mi(`ds_inter_var'_`ds_type')
			
			local rel_label : variable label rel_`ds_type'
			label var i_`ds_inter_var'_`type_name' "`rel_label' X `label'"
			
			
		}


	}

	foreach sdc_type in debt equity conv {

		foreach sdc_inter_var in log_proceeds gross_spread_perc days_after_match {

			if "`sdc_inter_var'" == "log_proceeds" {
				local label "Lg-Amt"
			}
			if "`sdc_inter_var'" == "gross_spread_perc" {
				local label "Sprd"
			}
			if "`sdc_inter_var'" == "days_after_match" {
				local label "Days Between Rel."
			}
			

			local type_name `sdc_type'
			
			gen i_`sdc_inter_var'_`type_name' = 0
			replace i_`sdc_inter_var'_`type_name' = `sdc_inter_var'_`sdc_type'*rel_`sdc_type' if !mi(`sdc_inter_var'_`sdc_type')
			gen mi_`sdc_inter_var'_`type_name' = mi(`sdc_inter_var'_`sdc_type')
			
			local rel_label : variable label rel_`sdc_type'
			label var i_`sdc_inter_var'_`type_name' "`rel_label' X `label'"
			
		}

	}

end
