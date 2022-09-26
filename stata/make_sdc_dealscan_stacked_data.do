*This program will stack the dealscan loan x lender dataset onto the sdc deal x bookrunner dataset and make many measures
use "$data_path/sdc_deal_compustat_bookrunner_level", clear
append using "$data_path/dealscan_compustat_lender_loan_level"

*Make sure that they are zero if missing
foreach var in  $sdc_types $ds_types {
	replace `var' = 0 if mi(`var')
}

egen sdc_obs = rowmax($sdc_types)
egen ds_obs = rowmax($ds_types)


tostring sdc_deal_id, replace
tostring facilityid, replace

gen deal_id = "SDC-" + sdc_deal_id if sdc_obs ==1
replace deal_id = "DS-" + facilityid if ds_obs ==1

*Make a single variable for the amount of money
gen amount_raised = proceeds
replace amount_raised = facilityamt if mi(amount_raised)

order deal_id cusip_6 borrowercompanyid date_daily date_quarterly lender $sdc_types $ds_types
sort cusip_6 date_daily borrowercompanyid

*Now I have a stacked dataset with all observations.
save "$data_path/sdc_ds_stacked_all", replace

*Now let's just keep observations that we have a cusip_6 for (compustat observations +sdc) "roughly public firms"
use "$data_path/sdc_ds_stacked_all", clear
drop if mi(cusip_6)

*Create measures of relationship strength (past ones)

*Create the duration measure of a relationship
drop min_date_daily
egen min_date_daily = min(date_daily), by(cusip_6)
format min_date_daily %td

gen duration = (date_daily - min_date_daily)/365.25
label var duration "Length of Relationship (years)"

*Create a "intensity" of relationship measure (number of loans/deals that happened)
*This variable will count the total number of interactions before that deal
gen num_interactions_prev = 0
label var num_interactions_prev "Number of total interactions with lender"
foreach var in  $sdc_types $ds_types {
	*This will count the total number of previous interactions of a previous type, inclusive of the current one
	bys cusip_6 lender (date_daily): gen num_`var'_prev = sum(`var') - `var'
	*Set each value from each day equal to the first value - this takes care of cases where I have multiple loans/deals in one day
	bys cusip_6 lender date_daily: replace num_`var'_prev = num_`var'_prev[1]
	replace num_interactions_prev = num_interactions_prev + num_`var'_prev + `var'
}
*Make a correction so that way the number will represent number of PREVIOUS interactions
replace num_interactions_prev = num_interactions_prev -1
*br lender deal_id cusip_6 date_daily num_* $sdc_types $ds_types

*Create a "scope" of relationship measure (number of types of loans/types of)
*Create indicators of types of previous relationships
gen scope_total = 0
label var scope_total "Number of total types of interactions with lender"
foreach var in  $sdc_types $ds_types {
	gen scope_`var' = (num_`var'_prev>0)
	*Does this work?
	replace scope_total = scope_total + scope_`var'
}
*br lender deal_id cusip_6 date_daily scope_* $sdc_types $ds_types num_*

*Create a "concentration" of relationship measure (how much of their lending is done by the bank)
*Follow measure from "Determinants of Contract Terms in Bank Revolving Credit Agreements"
gen concentration = log((dealamount/1000000)/(total_debt+(dealamount/1000000)))
label var concentration "Loan Concentration"
*Note many of these don't have debt and so loan concentration ends up being 1.

*************Create measures of future business*************************************

*Will create a variable that is the number of times that a firm used that lender in the next five years
local num_years 5
local num_observations_max 20

gen num_interactions_fut = 0
label var num_interactions_fut "Number of Future Interactions"
gen amount_total_fut = 0
label var amount_total_fut "Total Amount Raised in Future Interactions"
foreach var in  $sdc_types $ds_types {
	gen amount_`var'_fut = 0
	gen num_`var'_fut = 0
	forval i = 1/`num_observations_max' {
		*Add one if the future observation is of the specific type, the future observation is at a future date, and that date is within 5 years.
		bys cusip_6 lender (date_daily): replace num_`var'_fut = num_`var'_fut +1 ///
			if `var'[_n+`i'] ==1 & date_daily & date_daily[_n+`i']>date_daily ///
			& (date_daily[_n+`i']-date_daily)<`num_years'*365.25
		bys cusip_6 lender (date_daily): replace amount_`var'_fut = amount_`var'_fut +amount_raised ///
			if `var'[_n+`i'] ==1 & date_daily & date_daily[_n+`i']>date_daily ///
			& (date_daily[_n+`i']-date_daily)<`num_years'*365.25
		
	}
	*Create log amount
	gen log_amount_`var'_fut = log(amount_`var'_fut +1)
	*Created totals
	replace num_interactions_fut = num_interactions_fut + num_`var'_fut
	replace amount_total_fut = amount_total_fut + amount_`var'_fut
}

gen log_amount_total_fut = log(amount_total_fut+1)

*br lender deal_id cusip_6 date_daily num_*fut $sdc_types $ds_types 

*Create indicators for whether they have different types of future business (instead of counts)
gen scope_total_fut = 0
label var scope_total_fut "Number of total types of interactions with lender in future"
foreach var in  $sdc_types $ds_types {
	gen scope_`var'_fut = (num_`var'_fut>0)
	*Does this work?
	replace scope_total_fut = scope_total_fut + scope_`var'_fut
}

*br lender deal_id cusip_6 date_daily scope_*fut $sdc_types $ds_types 

*Create more broad measures
gen scope_loan_fut = 0
label var scope_loan_fut "Future Loan"
foreach var in $ds_types {
	replace scope_loan_fut = 1 if scope_`var'_fut==1
}

gen scope_underwriting_fut = 0
label var scope_underwriting_fut "Future Underwriting"
foreach var in $sdc_types {
	replace scope_underwriting_fut = 1 if scope_`var'_fut==1
}

gen scope_loan_underwriting_fut = (scope_loan_fut==1 & scope_underwriting_fut == 1)
label var scope_loan_underwriting_fut "Future Loan and Underwriting"

save "$data_path/sdc_ds_stacked_cleaned_with_rel_measures", replace
