*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

use "$data_path/sdc_deals_with_past_relationships_20", clear

foreach vars_set in baseline baseline_time ds_lender_type ds_chars ds_chars_bins  sdc_chars {

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
		local rhs rel_* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* i_discount_1_simple* mi_discount_1_simple*
		local drop_add "mi_*"
	}
	if "`vars_set'" == "ds_chars_bins" {
		local rhs rel_* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* mi_discount_1_simple* ///
		i_d_1_simple_le_0* i_d_1_simple_0_25* i_d_1_simple_25_50* i_d_1_simple_50_100* i_d_1_simple_100_200* i_d_1_simple_ge_200*
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
			local cond "if `type'_base ==1" 
		}
		if "`type'" == "debt" {
			local cond "if `type'_base ==1" 
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

			reghdfe hire `rhs' `cond', absorb(`absorb') vce(cl cusip_6)
			estadd local fe = "`fe_local'"
			estadd local sample = "`type'"
			estimates store est`i'
			local ++i

		
		}
	
	}
	
	esttab est* using "$regression_output_path/regressions_sdc_inten_`vars_set'.tex", ///
	replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
	title("Likelihood of SDC hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
	addnotes("SEs clustered at firm level" "Observation is SDC deal x lender" "Hire indicator either 0 or 100 for readability")

	
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


	foreach vars_set in baseline baseline_time ds_lender_type ds_chars ds_chars_bins  sdc_chars {

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
			local rhs rel_* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* i_discount_1_simple* mi_discount_1_simple*
			local drop_add "mi_*"
		}
		if "`vars_set'" == "ds_chars_bins" {
			local rhs rel_* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* mi_discount_1_simple* ///
			i_d_1_simple_le_0* i_d_1_simple_0_25* i_d_1_simple_25_50* i_d_1_simple_50_100* i_d_1_simple_100_200* i_d_1_simple_ge_200*
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

				reghdfe `lhs' `rhs' `rhs_add' `cond' & hire !=0, absorb(`absorb') vce(cl cusip_6)
				estadd local fe = "`fe_local'"
				estadd local sample = "`type'"
				estimates store est`i'
				local ++i

			
			}
		
		}
		
		esttab est* using "$regression_output_path/regressions_sdc_exten_`lhs'_`vars_set'.tex", ///
		replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
		title("Pricing of SDC issuances after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
		addnotes("SEs clustered at firm level" "Observation is SDC deal x lender when lender is hired" "Underwriting fee is in percentage points" ///
		"Lg-Amt is Log Proceeds from issuance")
		
	}
}

*Want to add one where I am looking at interactions between previous relationship and the relationship states
use "$data_path/sdc_deals_with_past_relationships_20", clear

br sdc_deal_id lender hire cusip_6 date_daily prev_lender_base first_loan_base switcher_loan_base ///
	rel_* i_prev_lend* i_first_loan_* i_switcher_loan_* if date_daily >=td(01jan2006)
sort sdc_deal_id lender date_daily

	*Want to do a version of this but only when the base is switched (and only at loans???)
	if "`vars_set'" == "relationship_states" {
		local rhs rel_* i_first_loan_* i_switcher_loan_* 
		local drop_add "mi_*"
	}
	
*Adjusted from the "regressions_tables_paper_slides"
*Todo, test if it works
gen sdc_obs =1
local rhs rel_* i_first_loan_* i_switcher_loan_* 
local cond_add "& (switcher_loan_base==1 | first_loan_base==1)"
local drop_add 
local absorb constant
local fe_local "None"
foreach table in sdc {

	if "`table'" == "sdc" {
		local lhs all_sdc $sdc_types
		local notes_add "SDC deal x lender"
	}
	if "`table'" == "ds" {
		
		local lhs all_ds $ds_types
		local notes_add "Dealscan loan x lender"
	}
	
	estimates clear
	local i = 1

	foreach type in  `lhs'  {
		if "`type'" == "all_sdc" {
			local cond "if sdc_obs==1" 
			local scalar_label "All Securities"
		}
		
		if "`type'" == "equity" {
			local cond "if `type' ==1" 
			local scalar_label "Equity Issuance"
		}
		if "`type'" == "debt" {
			local cond "if `type' ==1" 
			local scalar_label "Debt Issuance"
		}
		if "`type'" == "conv" {
			local cond "if `type' ==1" 
			local scalar_label "Convertible Issuance"
		}
		if "`type'" == "all_ds" {
			local cond "if ds_obs==1" 
			local scalar_label "All Loans"
		}
		if "`type'" == "b_term_loan" {
			local cond "if `type' ==1" 
			local scalar_label "Bank Term Loans"
		}
		if "`type'" == "rev_loan" {
			local cond "if `type' ==1" 
			local scalar_label "Rev Loans"
		}
		if "`type'" == "i_term_loan" {
			local cond "if `type' ==1" 
			local scalar_label "Inst. Term Loans"
		}
		if "`type'" == "other_loan" {
			local cond "if `type' ==1" 
			local scalar_label "Other Loans"
		}
		
		reghdfe hire `rhs' `cond' `cond_add', absorb(`absorb') vce(cl cusip_6)
		estadd local fe = "`fe_local'"
		estadd local sample = "`scalar_label',Switchers"
		estimates store est`i'
		local ++i
	}

	esttab est* using "$regression_output_path/regressions_inten_rel_states_`table'_slides.tex", ///
	replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
	title("Likelihood of hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
	addnotes("Observation is `notes_add'" "Sample is 20 largest lenders x each deal/loan" ///
	"Hire indicator either 0 or 100 for readability" "SEs clustered at firm level" )
}
