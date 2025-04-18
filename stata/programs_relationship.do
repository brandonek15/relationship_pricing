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

	*First we will get the set of "lenders" in both SDC and dealscan (in dealscan only keep lead arrangers)
	use "$data_path/lender_facilityid_cusip6", clear
	merge m:1 facilityid lender using "$data_path/dealscan_facility_lender_level", ///
	keepusing(lead_arranger_credit) keep(1 3) nogen
	keep if lead_arranger_credit ==1
	drop lead_arranger_credit
	
	append using "$data_path/sdc_deal_bookrunner", gen(type)
	bys lender: gen N = _N 
	assert type == 0 if mi(sdc_deal_id)
	assert type == 1 if mi(facilityid)
	gen sdc_deal = (type==0)
	gen ds_deal = (type==1)
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

	foreach subset_type in $sdc_types $ds_types {
		*If they are derived from SDC, then need to note these
		local sdc_subset: list local(subset_type) in global(sdc_types)
		local ds_subset: list local(subset_type) in global(ds_types)

		local ds_subset: list local(subset_type) in global(ds_types)
		if `sdc_subset' ==1 {
			local subset_deal_data "$data_path/sdc_all_clean"
			local subset_id sdc_deal_id
			local merge_vars `sdc_vars'
		}
		else if `ds_subset' ==1 {
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
		if `ds_subset' ==1 {
			*We will also merge on lender information
			merge m:1 `subset_id' lender using "$data_path/dealscan_facility_lender_level", ///
			keepusing(`ds_lender_vars') keep(1 3) nogen
			local rename_add `ds_lender_vars'
		}
		else {
			local rename_add 
		}
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
	args sdc_vars ds_vars ds_lender_vars
	
	local relationships
	foreach subset_type in $sdc_types $ds_types {
		local relationships `relationships' rel_`subset_type'
	}
	
	*Create past relationship dummy and FEs
	egen past_relationship = rowmax(`relationships')
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
	label var rel_b_term_loan "Rel. Bank Term Loan"
	label var rel_other_loan "Rel. Other Loan"
	label var rel_i_term_loan "Rel. Inst. Term Loan"
	
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
	foreach ds_type in $ds_types {

		foreach ds_inter_var in `ds_vars' `ds_lender_vars' days_after_match {
			
			*Don't want to create interactions for loantype packageid
			if "`ds_inter_var'" != "loantype" & "`ds_inter_var'" != "packageid" & "`ds_inter_var'" != "lenderrole" {

				*Default to initial variable label so they don't get labeled somthing weird
				local label : variable label `ds_inter_var'_`ds_type'

				if "`ds_inter_var'" == "discount_1_simple" {
					local label "Disc"
				}
				if "`ds_inter_var'" == "discount_1_controls" {
					local label "D-1-C"
				}
				if "`ds_inter_var'" == "d_1_simple_pos" {
					local label "Disc Pos"
				}
				if "`ds_inter_var'" == "d_1_controls_pos" {
					local label "D-1-C Pos"
				}
				if "`ds_inter_var'" == "d_1_simple_le_0" {
					local label "Disc (-inf,0)"
				}
				if "`ds_inter_var'" == "d_1_simple_0" {
					local label "Disc [0]"
				}
				if "`ds_inter_var'" == "d_1_simple_0_25" {
					local label "Disc (0-25]"
				}
				if "`ds_inter_var'" == "d_1_simple_25_50" {
					local label "Disc (25,50]"
				}
				if "`ds_inter_var'" == "d_1_simple_50_100" {
					local label "Disc (50,100]"
				}
				if "`ds_inter_var'" == "d_1_simple_100_200" {
					local label "Disc (100,200]"
				}
				if "`ds_inter_var'" == "d_1_simple_ge_200" {
					local label "Disc (200,inf)"
				}
				if "`ds_inter_var'" == "d_1_controls_le_0" {
					local label "D-1-C (-inf,0)"
				}
				if "`ds_inter_var'" == "d_1_controls_0" {
					local label "D-1-C [0]"
				}
				if "`ds_inter_var'" == "d_1_controls_0_25" {
					local label "D-1-C (0-25]"
				}
				if "`ds_inter_var'" == "d_1_controls_25_50" {
					local label "D-1-C (25,50]"
				}
				if "`ds_inter_var'" == "d_1_controls_50_100" {
					local label "D-1-C (50,100]"
				}
				if "`ds_inter_var'" == "d_1_controls_100_200" {
					local label "D-1-C (100,200]"
				}
				if "`ds_inter_var'" == "d_1_controls_ge_200" {
					local label "D-1-C (200,inf)"
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
				if "`ds_inter_var'" == "prev_lender" {
					local label "Prev Lending Relationship"
				}
				if "`ds_inter_var'" == "prev_lender" {
					local label "Prev Relationship"
				}
				if "`ds_inter_var'" == "no_prev_lender" {
					local label "No Prev Relationship"
				}
				if "`ds_inter_var'" == "first_loan" {
					local label "First Interaction"
				}				
				if "`ds_inter_var'" == "switcher_loan" {
					local label "Switching Interaction"
				}
				
				local type_name = substr("`ds_type'",1,length("`ds_type'")-5)
			
				*Do I want to do it here insteaed
			
				gen i_`ds_inter_var'_`type_name' = 0
				replace i_`ds_inter_var'_`type_name' = `ds_inter_var'_`ds_type'*rel_`ds_type' if !mi(`ds_inter_var'_`ds_type')
				gen mi_`ds_inter_var'_`type_name' = mi(`ds_inter_var'_`ds_type')
				
				local rel_label : variable label rel_`ds_type'
				label var i_`ds_inter_var'_`type_name' "`rel_label' X `label'"
			
			}
		}


	}

	foreach sdc_type in $sdc_types {

		foreach sdc_inter_var in `sdc_vars' days_after_match {

			if "`sdc_inter_var'" == "log_proceeds" {
				local label "Lg-Amt"
			}
			if "`sdc_inter_var'" == "gross_spread_perc" {
				local label "Sprd"
			}
			if "`sdc_inter_var'" == "days_after_match" {
				local label "Days Between Rel."
			}
			if "`sdc_inter_var'" == "prev_lender" {
				local label "Prev Relationship"
			}
			if "`sdc_inter_var'" == "no_prev_lender" {
				local label "No Prev Relationship"
			}
			if "`sdc_inter_var'" == "first_loan" {
				local label "First Interaction"
			}				
			if "`sdc_inter_var'" == "switcher_loan" {
				local label "Switching Interaction"
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
