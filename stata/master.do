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

*Make Compustat x dealscan relationships

*Make relationship dataset
do "$code_path/prep_relationship_datasets.do"
do "$code_path/create_sdc_issuance_relationships.do"
do "$code_path/create_ds_lending_relationships.do"

do "$code_path/analysis_relationships_for_slides.do"

*Relationship Analysis
do "$code_path/analysis_sdc_issuance_relationship.do"
do "$code_path/analysis_ds_lending_relationship.do"
