*Loan Covenant master file

* set directory
if "`c(os)'" == "Unix" {
   global root = "/kellogg/proj/blz782/bank_relationship_pricing"
   global code_path = "$root/code/stata"
}
else if "`c(os)'" == "Windows" {
*No need for this yet
   global root = ""
}

*Load settings
do "$code_path/settings.do"

*Clean merged data
do "$code_path/clean_compustat.do"
do "$code_path/clean_dealscan.do"
