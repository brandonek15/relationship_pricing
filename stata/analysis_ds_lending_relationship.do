*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

use "$data_path/ds_lending_with_past_relationships_20", clear

foreach vars_set in baseline baseline_time ds_lender_type ds_chars sdc_chars {

	if "`vars_set'" == "baseline" {
		local rhs rel_* 
		local drop_add 
	}
	if "`vars_set'" == "baseline_time" {
		local rhs rel_* i_days_after_match_*
		local drop_add 
	}
	*No need to include the missing variables because agent_credit and lead_arranger are never missing if relationsihp ==1
	if "`vars_set'" == "ds_lender_type" {
		local rhs rel_* i_agent_credit_* i_lead_arranger_* i_bankallocation_* mi_bankallocation_*
		local drop_add  "mi_*"
	}
	if "`vars_set'" == "ds_chars" {
		local rhs rel_* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* i_discount_1_simple* mi_discount_1_simple*
		local drop_add "mi_*"
	}
	if "`vars_set'" == "sdc_chars" {
		local rhs rel_* i_log_proceeds_* i_gross_spread_perc_* mi_gross_spread_perc_*
		local drop_add "mi_*"
	}

	estimates clear
	local i = 1

	
	foreach type in all term rev {

		if "`type'" == "term" {
			local cond "if `type'_loan ==1" 
		}
		if "`type'" == "rev" {
			local cond "if `type'_loan ==1" 
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

			reghdfe hire `rhs' `cond', absorb(`absorb') vce(robust)
			estadd local fe = "`fe_local'"
			estadd local sample = "`type'"
			estimates store est`i'
			local ++i

		
		}
	
	}
	
	esttab est* using "$regression_output_path/regressions_ds_inten_`vars_set'.tex", ///
	replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
	title("Likelihood of Dealscan hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
	addnotes("Robust SEs" "Observation is DS Loan x lender" "Hire indicator either 0 or 100 for readability")

	
}

*Extensive margin - pricing of dealscan loan (only using hire ==1)
label var discount_1_simple_base "Disc"
label var spread_base "Sprd"
label var log_facilityamt_base "Lg-Amt"
foreach lhs in log_facilityamt_base spread_base discount_1_simple_base {

	if "`lhs'" == "spread_base" {
		local rhs_add log_facilityamt_base
	}
	if "`lhs'" == "discount_1_simple_base" {
		local rhs_add log_facilityamt_base
	}
	if "`lhs'" == "log_facilityamt_base" {
		local rhs_add spread_base
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

		*No need to include the missing variables because agent_credit and lead_arranger are never missing if relationsihp ==1
		if "`vars_set'" == "ds_lender_type" {
			local rhs rel_* i_agent_credit_* i_lead_arranger_* i_bankallocation_* mi_bankallocation_*
			local drop_add "mi_*"
		}
		if "`vars_set'" == "ds_chars" {
			local rhs rel_* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* i_discount_1_simple* mi_discount_1_simple*
			local drop_add "mi_*"
		}
		if "`vars_set'" == "sdc_chars" {
			local rhs rel_* i_log_proceeds_* i_gross_spread_perc_* mi_gross_spread_perc_*
			local drop_add "mi_*"
		}

		estimates clear
		local i = 1

		
		foreach type in all term rev {

			if "`type'" == "term" {
				local cond "if `type'_loan_base ==1" 
			}
			if "`type'" == "rev" {
				local cond "if `type'_loan_base ==1" 
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
		
		esttab est* using "$regression_output_path/regressions_ds_exten_`lhs'_`vars_set'.tex", ///
		replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
		title("Pricing of Dealscan Loans after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
		addnotes("Robust SEs" "Observation is DS loan x lender when lender is hired" "Fees/Discount in percentage point" ///
		"Lg-Amt is Log Facility Amount")
		
	}
}
