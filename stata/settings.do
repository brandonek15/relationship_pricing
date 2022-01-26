*Auto Loans Master file
clear all
capture restore
set more off
set type double
set maxvar 32000

cap log close _all
cap set scheme david4

global data_path "$root/intermediate_data"
global regression_output_path "$root/output/tables/regression_tables"
global figures_output_path "$root/output/figures/stata"
cap mkdir "$root/output/tables"
cap mkdir "$root/output/figures"
cap mkdir "$regression_output_path"
cap mkdir "$figures_output_path"
*Create a temporary data folder
cap mkdir "$data_path/stata_temp"

*Set globals that will be used througout to reduce the amount of code
global comp_char_vars log_assets leverage market_to_book sales_growth ///
	 log_sales quick_ratio ebitda_int_exp  ///
	cash_assets acq_assets shrhlder_payout_assets ///
	 working_cap_assets capex_assets ppe_assets ///
	 roa ebitda_assets  sga_assets

global comp_outcome_vars cash_assets acq_assets shrhlder_payout_assets ///
	 working_cap_assets capex_assets ppe_assets ///
	 roa ebitda_assets  sga_assets
	 
global lower_cut_wins 2.5
global upper_cut_wins 97.5
