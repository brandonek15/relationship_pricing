*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

use "$data_path/sdc_deals_with_past_relationships_20", clear

foreach vars_set in baseline baseline_time ds_lender_type ds_chars sdc_chars {

	if "`vars_set'" == "baseline" {
		local rhs rel_* 
		local drop_add 
	}
	if "`vars_set'" == "baseline_time" {
		local rhs rel_* i_days_after_match_*
		local drop_add 
	}
	if "`vars_set'" == "ds_lender_type" {
		local rhs rel_* i_agent_credit_* i_lead_arranger_* i_bankallocation_* mi_bankallocation_*
		local drop_add "mi_*"
	}
	if "`vars_set'" == "ds_chars" {
		local rhs rel_* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* i_rev_discount_1_simple* mi_rev_discount_1_simple*
		local drop_add "mi_*"
	}
	if "`vars_set'" == "sdc_chars" {
		local rhs rel_* i_log_proceeds_* i_gross_spread_perc_* mi_gross_spread_perc_*
		local drop_add "mi_*"
	}

	estimates clear
	local i = 1

	
	foreach type in all equity debt {

		if "`type'" == "equity" {
			local cond "if `type' ==1" 
		}
		if "`type'" == "debt" {
			local cond "if `type' ==1" 
		}
		if "`type'" == "all" {
			local cond "" 
		}

		foreach fe_type in none  firm_lender lender_relationship {
		
			if "`fe_type'" == "none" {
				local absorb constant
				local fe_local "No"
			}

			if "`fe_type'" == "firm_lender" {
				local absorb cusip_6_lender
				local fe_local "FxL"
			}

			if "`fe_type'" == "lender_relationship" {
				local absorb lender_relationship
				local fe_local "LxR"
			}

			reghdfe hire `rhs' `cond', absorb(`absorb') vce(robust)
			estadd local fe = "`fe_local'"
			estadd local sample = "`type'"
			estimates store est`i'
			local ++i

		
		}
	
	}
	
	esttab est* using "$regression_output_path/regressions_sdc_inten_`vars_set'.tex", ///
	replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
	title("Likelihood of SDC hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
	addnotes("Robust SEs" "Observation is SDC deal x lender" "Hire indicator either 0 or 100 for readability")

	
}

*Extensive margin - pricing of sdc deal (only using hire ==1)
label var gross_spread_perc_base "Fee"
label var log_proceeds_base "Lg-Amt"
foreach lhs in gross_spread_perc_base log_proceeds_base {

	if "`lhs'" == "gross_spread_perc_base" {
		local rhs_add log_proceeds_base
	}
	if "`lhs'" == "log_proceeds_base" {
		local rhs_add gross_spread_perc_base
	}


	foreach vars_set in baseline baseline_time ds_lender_type ds_chars sdc_chars {

		if "`vars_set'" == "baseline" {
			local rhs rel_* 
			local drop_add 
		}
		if "`vars_set'" == "baseline_time" {
			local rhs rel_* i_days_after_match_*
			local drop_add 
		}
		if "`vars_set'" == "ds_lender_type" {
			local rhs rel_* i_agent_credit_* i_lead_arranger_* i_bankallocation_* mi_bankallocation_*
			local drop_add "mi_*"
		}
		if "`vars_set'" == "ds_chars" {
			local rhs rel_* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* i_rev_discount_1_simple* mi_rev_discount_1_simple*
			local drop_add "mi_*"
		}
		if "`vars_set'" == "sdc_chars" {
			local rhs rel_* i_log_proceeds_* i_gross_spread_perc_* mi_gross_spread_perc_*
			local drop_add "mi_*"
		}

		estimates clear
		local i = 1

		
		foreach type in all equity debt {

			if "`type'" == "equity" {
				local cond "if `type' ==1" 
			}
			if "`type'" == "debt" {
				local cond "if `type' ==1" 
			}
			if "`type'" == "all" {
				local cond "if 1==1" 
			}

			foreach fe_type in none  firm_lender lender_relationship {
			
				if "`fe_type'" == "none" {
					local absorb constant
					local fe_local "No"
				}

				if "`fe_type'" == "firm_lender" {
					local absorb cusip_6_lender
					local fe_local "FxL"
				}

				if "`fe_type'" == "lender_relationship" {
					local absorb lender_relationship
					local fe_local "LxR"
				}

				reghdfe `lhs' `rhs' `rhs_add' `cond' & hire !=0, absorb(`absorb') vce(robust)
				estadd local fe = "`fe_local'"
				estadd local sample = "`type'"
				estimates store est`i'
				local ++i

			
			}
		
		}
		
		esttab est* using "$regression_output_path/regressions_sdc_exten_`lhs'_`vars_set'.tex", ///
		replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
		title("Pricing of SDC issuances after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
		addnotes("Robust SEs" "Observation is SDC deal x lender when lender is hired" "Underwriting fee is in percentage points" ///
		"Lg-Amt is Log Proceeds from issuance")
		
	}
}
