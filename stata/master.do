*Relationship pricing master file

* set directory
if "`c(os)'" == "Unix" {
   global root = "/kellogg/proj/blz782/bank_relationship_pricing"
   global code_path = "$root/code/stata"
}
else if "`c(os)'" == "Windows" {
*No need for this yet
   global root = ""
}
else if "`c(os)'" == "MacOSX" {
   global root = "/Users/Benjamin/Documents/GitHub/relationship_pricing/"
   global code_path = "$root/stata/"	
}
*Load settings
do "$code_path/settings.do"

*Clean merged data
do "$code_path/clean_capiq.do"
do "$code_path/clean_compustat.do"
do "$code_path/clean_fred.do"
do "$code_path/clean_dealscan.do"
do "$code_path/clean_sdc.do"

*Merge Compustat with dealscan and sdc data
do "$code_path/make_ds_lender_data_with_comp.do"
do "$code_path/make_sdc_data_with_comp.do"
*Make a Dealscan + SDC stacked dataset
do "$code_path/make_sdc_dealscan_stacked_data.do"

*Analysis
do "$code_path/summary_stats.do"
do "$code_path/figures_dist_chars.do"
do "$code_path/make_discount_graphs.do"
do "$code_path/regressions_discount_firm_loan_char.do"
do "$code_path/regressions_graphs_discount_prev_lender.do"
do "$code_path/regressions_discount_autocorrelations.do"
do "$code_path/analysis_spread_dynamics.do"

*Make relationship dataset (testing invest-then-harvest)
do "$code_path/prep_relationship_datasets.do"
do "$code_path/create_sdc_issuance_relationships.do"
do "$code_path/create_ds_lending_relationships.do"

*Relationship Analysis
do "$code_path/analysis_sdc_issuance_relationship.do"
do "$code_path/analysis_ds_lending_relationship.do"

*Code to create tables for paper/slides
do "$code_path/figures_paper_slides.do"
do "$code_path/simple_tables_paper_slides.do"
do "$code_path/regression_tables_paper_slides.do"
