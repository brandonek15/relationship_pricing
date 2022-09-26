*Auto Loans Master file
clear all
capture restore
set more off
set type double
set maxvar 32000

cap log close _all
cap set scheme david4

global data_path "$root/intermediate_data"
global input_data "$root/data/inputs"
global regression_output_path "$root/output/tables/regression_tables"
global figures_output_path "$root/output/figures/stata"
cap mkdir "$root/output/tables"
cap mkdir "$root/output/figures"
cap mkdir "$regression_output_path"
cap mkdir "$figures_output_path"
*Create a temporary data folder
cap mkdir "$data_path/stata_temp"
cap ssc install corrtex

*Set globals that will be used througout to reduce the amount of code
global comp_char_vars log_assets leverage market_to_book sales_growth ///
	 log_sales quick_ratio ebitda_int_exp  ///
	cash_assets acq_assets shrhlder_payout_assets ///
	 working_cap_assets capex_assets ppe_assets ///
	 roa ebitda_assets  sga_assets firm_age current_assets

global comp_outcome_vars cash_assets acq_assets shrhlder_payout_assets ///
	 working_cap_assets capex_assets ppe_assets ///
	 roa ebitda_assets  sga_assets
	 
global loan_level_controls log_facilityamt maturity cov cov_lite
	 
global lower_cut_wins 2.5
global upper_cut_wins 97.5

global run_big_data_code 1

global sdc_types equity debt conv
global ds_types rev_loan b_term_loan i_term_loan other_loan

global rel_states prev_lender no_prev_lender first_loan switcher_loan
