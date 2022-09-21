*This program will make a lender (bookrunner) x loan dataset load in the compustat data, with the sdc data
use "$data_path/sdc_deal_bookrunner_level", clear

*For now keep both that can be matched to compustat and those that cannot, which are those that can match to compustat.
merge m:1 cusip_6 date_quarterly using "$data_path/compustat_clean_cusip6_date_quarterly", keep(1 3)
gen merge_compustat = _merge ==3
drop _merge
*Want to make the merge_ratings = 0 if missing
replace merge_ratings = 0 if mi(merge_ratings)
*Want to create my three categories of observations - merge ratings, merge compustat but no ratings, and no compustat
gen merge_compustat_no_ratings = (merge_compustat==1 & merge_ratings==0)
gen no_merge_compustat = (merge_compustat==0)
label var merge_ratings "Comp Firm w/ Ratings"
label var merge_compustat_no_ratings "Comp Firm w/out Ratings"
label var no_merge_compustat "Non Comp Firm"
sort cusip_6 date_quarterly 
gen constant = 1

*Make ratings_obs_type interactions
foreach ratings_obs_type in no_merge_compustat merge_compustat_no_ratings merge_ratings {
	gen nprev_`ratings_obs_type' = no_prev_lender*`ratings_obs_type'
	gen prev_`ratings_obs_type' = prev_lender*`ratings_obs_type'
	gen first_`ratings_obs_type' = first_loan*`ratings_obs_type'
	gen switc_`ratings_obs_type' = switcher_loan*`ratings_obs_type'
	
	local label: variable label `ratings_obs_type'
	label var nprev_`ratings_obs_type' "No Prev Lend Rel. x `label'"
	label var prev_`ratings_obs_type' "Prev Lend Rel. x `label'"
	label var first_`ratings_obs_type' "First Loan x `label'"
	label var switc_`ratings_obs_type' "Switching Lend x `label'"

	
}

*Save a deal x lender file
save "$data_path/sdc_deal_compustat_bookrunner_level", replace
drop lender 
duplicates drop
*Save a loan level file
save "$data_path/sdc_deal_compustat_level", replace
