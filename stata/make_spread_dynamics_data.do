*********
use "$data_path/dealscan_compustat_loan_level", clear
keep if !mi(borrowercompanyid) 

*In case there is a missing and a discount calculated, keep the not missing obs
bys borrowercompanyid category facilitystartdate first_loan prev_lender switcher_loan (discount_1_simple): keep if _n == 1

*Create another version of loan_number by category 
gen first_loan_only_one = 1 if no_prev_lender==1
bys borrowercompanyid (facilitystartdate): replace first_loan_only_one = . if facilitystartdate == facilitystartdate[_n-1]
bys borrowercompanyid (facilitystartdate): gen new_lender_group_num = sum(first_loan_only_one)

*Create a new identifier to start creating the loan numbers by category
egen borrower_lender_group_id = group(borrowercompanyid new_lender_group_num)
*now actually create it
bys borrower_lender_group_id facilitystartdate category : gen first_obs_in_package_cat = _n==1
bys borrower_lender_group_id category (facilitystartdate): gen loan_num_category = sum(first_obs_in_package_cat)

*Drop unneeded variables
drop first_loan_only_one new_lender_group_num first_obs_in_package_cat

*The variable borrower_lender_group_id basically gives each borrower x lender group a new identifier. Can use this
*To create the the loan number
bys borrower_lender_group_id facilitystartdate (category): gen first_obs_in_package = _n ==1
bys borrower_lender_group_id (facilitystartdate): gen loan_number = sum(first_obs_in_package)

drop first_obs_in_package

*Want to do a similar one except not by borrower_lender_group, instead just by borrower.
bys borrowercompanyid facilitystartdate (category): gen first_obs_in_package = _n ==1
bys borrowercompanyid (facilitystartdate): gen loan_number_borrower = sum(first_obs_in_package)

drop first_obs_in_package
order borrowercompanyid borrower_lender_group_id facilitystartdate category loan_number_borrower loan_number loan_num_category 

*Now want to create variables to be used for the "t-1" analysis, where I look at loan numbers BEFORE a switch
*First generate a variable that says you are the nth lender group for a borrower
preserve

	keep borrowercompanyid borrower_lender_group_id facilitystartdate
	*Keep only the first loan from the borrower_lender_group_id x borrowercompanyid
	bys borrowercompanyid borrower_lender_group_id (facilitystartdate): keep if _n ==1
	*Now number the borrower_lender_group_ids
	bys borrowercompanyid (borrower_lender_group_id facilitystartdate): gen syndicate_number = _n
	keep borrowercompanyid borrower_lender_group_id syndicate_number
	tempfile synd_num
	save `synd_num', replace

restore

merge m:1 borrowercompanyid borrower_lender_group_id using `synd_num', assert(3) nogen

*We will only look at syndicate 2's and call their syndicate 1 loans the t-n loans
egen total_loans_borrower_syndicate = max(loan_number), by(borrower_lender_group_id)
*Create a variable for the total number of loan syndicates for a borrower
egen max_syndicate = max(syndicate_number), by(borrowercompanyid)
gen loan_number_syndicate_2 = loan_number if syndicate_number ==2
*Make the loans go from t-1,t-2,...
replace loan_number_syndicate_2 = loan_number - total_loans_borrower_syndicate -1 if syndicate_number ==1 & max_syndicate >1
order borrowercompanyid borrower_lender_group_id facilitystartdate category loan_number_borrower loan_number loan_num_category syndicate_number loan_number_syndicate_2 max_syndicate

drop total_loans_borrower_syndicate
*To do. Look if dynamics look different for loan syndicate 1 vs loan syndicates >1
*To do. Look at the t-1 analysis for loan syndicate 2s

*Spread out dummies for whether discounts of each type exist within borrowercompanyid and date_daily
gen t_discount_obs_rev = !mi(discount_1_simple) & category == "Revolver"
gen t_discount_obs_term = !mi(discount_1_simple) & category == "Bank Term"
*Make similar dummies for whether they are firms with discounts, but now do it by firm x lender group and across time observations
egen discount_obs_rev_bco_group = max(t_discount_obs_rev), by(borrower_lender_group_id)
egen discount_obs_term_bco_group = max(t_discount_obs_term), by(borrower_lender_group_id)
egen discount_obs_any_bco_group = rowmax(discount_obs_rev_bco_group  discount_obs_term_bco_group)

drop t_*

*Make dummies for a simple graph of the average discount by observation num
forval i = 1/6 {
	gen n_`i' = loan_number == `i'
	label var n_`i' "Loan Num `i'"
	gen cat_n_`i' = loan_num_category == `i'
	label var cat_n_`i' "Loan Num `i'"
	gen borrower_n_`i' = loan_number_borrower == `i'
	label var borrower_n_`i' "Loan Num `i'"
	
	*Also do this for 2nd syndicate
	gen synd_2_n_`i' = loan_number_syndicate_2==`i'
	replace synd_2_n_`i' = . if max_syndicate==1
	label var synd_2_n_`i' "Loan Num `i'"
}

*Do the negative loan numbers for loans in the first syndicate
forval i = 6(-1)1 {
	*Also do this for 2nd syndicate
	gen synd_2_neg_n_`i' = loan_number_syndicate_2==-`i'
	replace synd_2_neg_n_`i' = . if max_syndicate==1
	label var synd_2_neg_n_`i' "Loan Num -`i'"
}


*Generate variables that represent the share of the total loan package held in the revolver or the bank term loan
egen t_total_rev = total(facilityamt) if category == "Revolver", by(borrowercompanyid facilitystartdate)
egen t_total_b_term = total(facilityamt) if category == "Bank Term" , by(borrowercompanyid facilitystartdate)
egen t_total_i_term = total(facilityamt) if category == "Inst. Term" , by(borrowercompanyid facilitystartdate)

foreach loan_type in total_rev total_b_term total_i_term {
	egen `loan_type' = max(t_`loan_type'), by(borrowercompanyid facilitystartdate)
	drop t_`loan_type'
}

egen total_package_amount = total(facilityamt), by(borrowercompanyid facilitystartdate)

foreach total_var in total_rev total_b_term total_i_term total_package_amount {
	gen log_`total_var' = log(`total_var')
}
label var log_total_rev "Log of Total Revolver Amount"
label var log_total_i_term "Log of Total Inst. Term Loan Amount"
label var log_total_b_term "Log of Total Bank Term Loan Amount"
label var log_total_package_amount "Log of Total Package Amount"


foreach cat in rev b_term {
	gen prop_`cat'_total = total_`cat'/total_package_amount 
	gen prop_`cat'_inst = total_`cat'/total_i_term
	winsor2 prop_`cat'_inst, cuts(0 95) replace
	
}
label var prop_rev_total "Revolver Amt / Package Amt"
label var prop_rev_inst "Revolver Amt / Inst. Term Amt"
label var prop_b_term_total "Bank Term Amt / Package Amt"
label var prop_b_term_inst "Bank Term Amt / Inst. Term Amt"


save "$data_path/dealscan_compustat_loan_level_with_loan_num", replace
