*Relationship pricing master file
*Finish Clean SDC later - need to standardize

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
do "$code_path/clean_compustat.do"
do "$code_path/clean_fred.do"
do "$code_path/clean_dealscan.do"
do "$code_path/clean_sdc.do"

*Merge data together
do "$code_path/merge_data.do"
do "$code_path/prep_merged_data.do"
do "$code_path/join_sdc_dealscan.do"
do "$code_path/prep_data_for_dynamics.do"
do "$code_path/join_same_dataset.do"
do "$code_path/figures_stickiness.do"

