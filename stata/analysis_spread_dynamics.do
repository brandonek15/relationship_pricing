*This program will try to understand the spread dynamics of the spreads 
*that are calculated into discounts

*First we will explore plot a simple example of a firm that has many interactions and
*how their discount changes over time

*Then we will plot the same graphs as the "discount over time" one but decomposed
*MEaning have 2 graphs, each with three series "rev spread" "inst stpread" "discount"
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
egen discount_obs_rev = max(t_discount_obs_rev), by(borrowercompanyid facilitystartdate)
egen discount_obs_term = max(t_discount_obs_term), by(borrowercompanyid facilitystartdate)
egen discount_obs_any = rowmax(discount_obs_rev discount_obs_term)
*Make similar dummies for whether they are firms with discounts, but now do it by firm x lender group and across time observations
egen discount_obs_rev_bco_group = max(t_discount_obs_rev), by(borrower_lender_group_id)
egen discount_obs_term_bco_group = max(t_discount_obs_term), by(borrower_lender_group_id)
egen discount_obs_any_bco_group = rowmax(discount_obs_rev_bco_group  discount_obs_term_bco_group)

drop t_*

*Make a simple graph of the average discount by observation num
forval i = 1/6 {
	gen n_`i' = loan_number == `i'
	label var n_`i' "Loan Num `i'"
	gen cat_n_`i' = loan_num_category == `i'
	label var cat_n_`i' "Loan Num `i'"
	
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

foreach cat in rev b_term {
	gen prop_`cat'_total = total_`cat'/total_package_amount 
	gen prop_`cat'_inst = total_`cat'/total_i_term
	winsor2 prop_`cat'_inst, cuts(0 95) replace
	
}


save "$data_path/dealscan_compustat_loan_level_with_loan_num", replace

*Make graphs for revolvers and bank term loans
foreach disc_type in rev b_term {
	if "`disc_type'" == "rev" {
		local category "Revolver"
		local sample "Revolving"
		local keep "keep if discount_obs_rev==1"
	}
	if "`disc_type'" == "b_term" {
		local category "Bank Term"
		local sample "Bank Term"
		local keep "keep if discount_obs_term==1"
	}

	*Keep only discount observations
	use "$data_path/dealscan_compustat_loan_level_with_loan_num", clear
	`keep'

	foreach discount_type in discount_1_simple discount_1_controls {

		if "`discount_type'" == "discount_1_simple" {
			local suffix_add
			local title_add "Simple"
			local spread_var spread
			local spread_label "Spread"
		}
		if "`discount_type'" == "discount_1_controls" {
			local suffix_add "_controls"
			local title_add "Controls"
			local spread_var spread_resid
			local spread_label "Residualized Spread"
		}

		foreach fe_type in none borrower {

			if "`fe_type'" == "none" {
				local fe_settings "nocons"
				local fe_cond 
				local fe_add "No FE" 
				local drop_var
				local fe_suffix
				local fe_coeff_plot_opt 
			}
			if "`fe_type'" == "borrower" {
				local fe_settings "absorb(borrower_lender_group_id)"
				local fe_cond "& loan_num_category <=6"
				local fe_add "Borrower x Lender Group FE"
				local drop_var "drop n_1"
				local fe_suffix "_borrowerfe"
				local fe_coeff_plot_opt "drop(_cons)"
			}
		
			*This is the simple version that doesn't breakdown by type of firm
			*Do the original version with only one series
			preserve
			`drop_var'
			
			estimates clear

			reg `discount_type' n_* if category == "`category'" `fe_cond', `fe_settings'
			estimates store all

			coefplot (all, label(`sample' Discounts) pstyle(p2) `fe_coeff_plot_opt') ///
			, vertical ytitle("`sample' Discount") title("Discount Coefficient on Loan Number - `title_add' - `fe_add'", size(small)) ///
				graphregion(color(white))  xtitle("`sample' Discount Number") xlabel(, angle(45)) ///
				 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample") levels(90)
				gr export "$figures_output_path/discounts`suffix_add'_across_loan_number_coeff`fe_suffix'_all_`disc_type'.png", replace 
			
			*This is the one from the paper
			estimates clear

			reg `discount_type' n_* if category == "`category'" & merge_compustat==1 `fe_cond', `fe_settings'
			estimates store comp
			reg `discount_type' n_* if category == "`category'" & merge_compustat==0 `fe_cond', `fe_settings'
			estimates store non_comp


			coefplot (comp, label(Compustat Firm Discounts) pstyle(p3) `fe_coeff_plot_opt') ///
			 (non_comp, label(Non-Compustat Firm Discounts) pstyle(p4) `fe_coeff_plot_opt') ///
			, vertical ytitle("`sample' Discount") title("Discount Coefficient on Loan Number - Comp and Non-Comp Firms - `title_add' - `fe_add'", size(small)) ///
				graphregion(color(white))  xtitle("`sample' Discount Number") xlabel(, angle(45)) ///
				 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample") levels(90)
				gr export "$figures_output_path/discounts`suffix_add'_across_loan_number_coeff`fe_suffix'_comp_non_comp_`disc_type'.png", replace 

			*These are the decompositions
			foreach decomp_type in all  comp no_comp {
				
				if "`decomp_type'" == "all" {
					local cond ""
					local subsample_title "All"
				}
				if "`decomp_type'" == "comp" {
					local cond "& merge_compustat ==1"
					local subsample_title "Compustat"
				}

				if "`decomp_type'" == "no_comp" {
					local cond "& merge_compustat ==0"
					local subsample_title "Non- Compustat"
				}
				*Add labels for controls bc its not really the spread no more
				estimates clear

				reg `spread_var' n_* if category == "`category'" `cond' `fe_cond', `fe_settings'
				estimates store comp_spread_`disc_type'

				reg `spread_var' n_* if category == "Inst. Term" `cond' `fe_cond', `fe_settings'
				estimates store comp_spread_i_term

				coefplot (comp_spread_`disc_type', label(`disc_type' Spreads) pstyle(p5) `fe_coeff_plot_opt') ///
				(comp_spread_i_term, label(Inst. Spreads) pstyle(p6) `fe_coeff_plot_opt') ///
				, vertical ytitle("`spread_label'") title("Coefficients on Loan Number - Decomposition - `subsample_title' - `title_add' - `fe_add'", size(small)) ///
					graphregion(color(white))  xtitle("Loan Number") xlabel(, angle(45)) ///
					 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample" ///
					 "Sample includes loans from loan packages with both institutional term loan and `category'") levels(90)
					gr export "$figures_output_path/decomposition`suffix_add'_across_loan_number_coeff`fe_suffix'_`decomp_type'_with_spread_`disc_type'.png", replace 
				
			}
				
			*Do a version where I have three series, non-comp, comp w/ ratings, comp w/out ratings
			estimates clear

			reg `discount_type' n_* if category == "`category'" & merge_compustat==1 & merge_ratings==1 `fe_cond', `fe_settings'
			estimates store comp_rat
			reg `discount_type' n_* if category == "`category'" & merge_compustat==1 & merge_ratings==0 `fe_cond', `fe_settings'
			estimates store comp_no_rat
			reg `discount_type' n_* if category == "`category'" & merge_compustat==0 `fe_cond', `fe_settings'
			estimates store non_comp


			coefplot (comp_rat, label(Compustat With Ratings) pstyle(p3) `fe_coeff_plot_opt') ///
			 (comp_no_rat, label(Compustat Without Ratings) pstyle(p5) `fe_coeff_plot_opt') ///
			 (non_comp, label(Non-Compustat Firm Discounts) pstyle(p4) `fe_coeff_plot_opt') ///
			, vertical ytitle("`sample' Discount") title("Discount Coeff on Loan Number - Comp and Non-Comp Firms, Ratings - `title_add' - `fe_add'", size(small)) ///
				graphregion(color(white))  xtitle("`sample' Discount Number") xlabel(, angle(45)) ///
				 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample") levels(90)
				gr export "$figures_output_path/discounts`suffix_add'_across_loan_number_coeff`fe_suffix'_comp_non_comp_ratings_`disc_type'.png", replace 
			
			*Decompose the compustat with and withoout ratings
			foreach decomp_type in  comp_rat comp_no_rat {
				
				if "`decomp_type'" == "comp_rat" {
					local cond "& merge_compustat ==1 & merge_ratings ==1"
					local subsample_title "Compustat w/ Ratings"
				}

				if "`decomp_type'" == "comp_no_rat" {
					local cond "& merge_compustat ==1 & merge_ratings ==0"
					local subsample_title "Compustat w/o Ratings"
				}

				estimates clear

				reg `spread_var' n_* if category == "`category'" `cond' `fe_cond', `fe_settings'
				estimates store comp_spread_`disc_type'

				reg `spread_var' n_* if category == "Inst. Term" `cond' `fe_cond', `fe_settings'
				estimates store comp_spread_i_term

				coefplot (comp_spread_`disc_type', label(`disc_type' Spreads) pstyle(p5) `fe_coeff_plot_opt') ///
				(comp_spread_i_term, label(Inst. Spreads) pstyle(p6) `fe_coeff_plot_opt') ///
				, vertical ytitle("`spread_label'") title("Coefficients on Loan Number - Decomposition - `subsample_title' - `title_add' - `fe_add'", size(small)) ///
					graphregion(color(white))  xtitle("Loan Number") xlabel(, angle(45)) ///
					 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample" ///
					 "Sample includes loans from loan packages with both institutional term loan and `category'") levels(90)
					gr export "$figures_output_path/decomposition`suffix_add'_across_loan_number_coeff`fe_suffix'_`decomp_type'_with_spread_`disc_type'.png", replace 
			
			}
			
			*Make one that is investment grade vs junk.
			estimates clear

			reg `discount_type' n_* if category == "`category'" & investment_grade==1 `fe_cond', `fe_settings'
			estimates store ig
			reg `discount_type' n_* if category == "`category'" & investment_grade==0 `fe_cond', `fe_settings'
			estimates store junk

			coefplot (ig, label(Investment Grade) pstyle(p3) `fe_coeff_plot_opt') ///
			 (junk, label(Junk Grade) pstyle(p5) `fe_coeff_plot_opt') ///
			, vertical ytitle("`sample' Discount") title("Discount Coeff on Loan Number - Compustat Rated - Investment Grade vs Junk `title_add' - `fe_add'", size(small)) ///
				graphregion(color(white))  xtitle("`sample' Discount Number") xlabel(, angle(45)) ///
				 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample") levels(90)
				gr export "$figures_output_path/discounts`suffix_add'_across_loan_number_coeff`fe_suffix'_ratings_ig_junk_`disc_type'.png", replace 

			*Decompose the compustat investment grade vs junk
			foreach decomp_type in  comp_rat_ig comp_rat_junk {
				
				if "`decomp_type'" == "comp_rat_ig" {
					local cond "& investment_grade ==1"
					local subsample_title "Compustat w/ Ratings - Investment Grade"
				}

				if "`decomp_type'" == "comp_rat_junk" {
					local cond "& investment_grade ==0"
					local subsample_title "Compustat w/ Ratings - Junk Grade"
				}

				estimates clear

				reg `spread_var' n_* if category == "`category'" `cond' `fe_cond', `fe_settings'
				estimates store comp_spread_`disc_type'

				reg `spread_var' n_* if category == "Inst. Term" `cond' `fe_cond', `fe_settings'
				estimates store comp_spread_i_term

				coefplot (comp_spread_`disc_type', label(`disc_type' Spreads) pstyle(p5) `fe_coeff_plot_opt') ///
				(comp_spread_i_term, label(Inst. Spreads) pstyle(p6) `fe_coeff_plot_opt') ///
				, vertical ytitle("`spread_label'") title("Coefficients on Loan Number - Decomposition - `subsample_title' - `title_add' - `fe_add'", size(small)) ///
					graphregion(color(white))  xtitle("Loan Number") xlabel(, angle(45)) ///
					 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample" ///
					 "Sample includes loans from loan packages with both institutional term loan and `category'") levels(90)
					gr export "$figures_output_path/decomposition`suffix_add'_across_loan_number_coeff`fe_suffix'_`decomp_type'_with_spread_`disc_type'.png", replace 
			
			}
			
			*Make one that is first syndicate vs later syndicate.
			estimates clear

			reg `discount_type' n_* if category == "`category'" & syndicate_number==1 `fe_cond', `fe_settings'
			estimates store synd_1
			reg `discount_type' n_* if category == "`category'" & syndicate_number>1 `fe_cond', `fe_settings'
			estimates store synd_ge1

			coefplot (synd_1, label(First Syndicate) pstyle(p3) `fe_coeff_plot_opt') ///
			 (synd_ge1, label(Syndicate 2+) pstyle(p5) `fe_coeff_plot_opt') ///
			, vertical ytitle("`sample' Discount") title("Discount Coeff on Loan Number - First Syndicate vs Syndicates 2+ `title_add' - `fe_add'", size(small)) ///
				graphregion(color(white))  xtitle("`sample' Discount Number") xlabel(, angle(45)) ///
				 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample") levels(90)
				gr export "$figures_output_path/discounts`suffix_add'_across_loan_number_coeff`fe_suffix'_synd_1_vs_other_`disc_type'.png", replace 

			*Decompose the first syndicate vs later syndicate
			foreach decomp_type in  synd_1 synd_2_plus {
				
				if "`decomp_type'" == "synd_1" {
					local cond "& syndicate_number==1 "
					local subsample_title "First Syndicate"
				}

				if "`decomp_type'" == "synd_2_plus" {
					local cond "& syndicate_number>1"
					local subsample_title "Syndicates 2+"
				}

				estimates clear

				reg `spread_var' n_* if category == "`category'" `cond' `fe_cond', `fe_settings'
				estimates store spread_`disc_type'

				reg `spread_var' n_* if category == "Inst. Term" `cond' `fe_cond', `fe_settings'
				estimates store spread_i_term

				coefplot (spread_`disc_type', label(`disc_type' Spreads) pstyle(p5) `fe_coeff_plot_opt') ///
				(spread_i_term, label(Inst. Spreads) pstyle(p6) `fe_coeff_plot_opt') ///
				, vertical ytitle("`spread_label'") title("Coefficients on Loan Number - Decomposition - `subsample_title' - `title_add' - `fe_add'", size(small)) ///
					graphregion(color(white))  xtitle("Loan Number") xlabel(, angle(45)) ///
					 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample" ///
					 "Sample includes loans from loan packages with both institutional term loan and `category'") levels(90)
					gr export "$figures_output_path/decomposition`suffix_add'_across_loan_number_coeff`fe_suffix'_`decomp_type'_with_spread_`disc_type'.png", replace 
			
			*t-1 analysis. Looking at the 2nd syndicate as the loan 1 vs loan 2, and then looking at the 
			*1st syndicate as loan -1, loan -2, etc.
			
			estimates clear

			reg `discount_type' synd_2_neg_n_* synd_2_n_* if category == "`category'" `fe_cond', `fe_settings'
			estimates store all

			coefplot (all, label(`sample' Discounts) pstyle(p2) `fe_coeff_plot_opt') ///
			, vertical ytitle("`sample' Discount") title("Discount Coefficient on Loan Number - 2nd Syndicate vs 1st - `title_add' - `fe_add'", size(small)) ///
				graphregion(color(white))  xtitle("`sample' Discount Number") xlabel(, angle(45)) ///
				 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample" ///
				  "Loan -1 is the loan package right before switching syndicates, Loan -2 is the one before loan -1, etc.") levels(90)
				gr export "$figures_output_path/discounts`suffix_add'_across_loan_number_coeff`fe_suffix'_all_2nd_synd_`disc_type'.png", replace 

			*Do the decomposition
			estimates clear
			local decomp_type all
			local cond ""
			local subsample_title "All"

			reg `spread_var' synd_2_neg_n_* synd_2_n_* if category == "`category'" `cond' `fe_cond', `fe_settings'
			estimates store spread_`disc_type'

			reg `spread_var' synd_2_neg_n_* synd_2_n_* if category == "Inst. Term" `cond' `fe_cond', `fe_settings'
			estimates store spread_i_term

			coefplot (spread_`disc_type', label(`disc_type' Spreads) pstyle(p5) `fe_coeff_plot_opt') ///
			(spread_i_term, label(Inst. Spreads) pstyle(p6) `fe_coeff_plot_opt') ///
			, vertical ytitle("`spread_label'") title("Coefficients on Loan Number - Decomposition - 2nd Syndicate `subsample_title' - `title_add' - `fe_add'", size(small)) ///
				graphregion(color(white))  xtitle("Loan Number") xlabel(, angle(45)) ///
				 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample" ///
				 "Sample includes loans from loan packages with both institutional term loan and `category'" ///
				 "Loan -1 is the loan package right before switching syndicates, Loan -2 is the one before loan -1, etc.") levels(90)
				gr export "$figures_output_path/decomposition`suffix_add'_across_loan_number_coeff`fe_suffix'_`decomp_type'_2nd_synd_with_spread_`disc_type'.png", replace 

			
			}	
		restore
		}
	}

	*Do versions where I do the facility amt
	foreach decomp_type in all  comp no_comp {
		
		if "`decomp_type'" == "all" {
			local cond ""
			local subsample_title "All"
		}
		if "`decomp_type'" == "comp" {
			local cond "& merge_compustat ==1"
			local subsample_title "Compustat"
		}

		if "`decomp_type'" == "no_comp" {
			local cond "& merge_compustat ==0"
			local subsample_title "Non- Compustat"
		}
		estimates clear

		reg log_facilityamt n_* if category == "`category'" `cond', nocons
		estimates store `disc_type'_facilityamt

		reg log_facilityamt n_* if category == "Inst. Term" `cond', nocons
		estimates store i_term_facilityamt

		coefplot (`disc_type'_facilityamt, label(`category' Log Facility Amt) pstyle(p3))  ///
		(i_term_facilityamt, label(Inst. Log Facility Amt) pstyle(p5)) ///
		, vertical ytitle("Log Facility Amt") title("Coefficients on Log Facility Amt - `subsample_title'",size(medsmall)) ///
			graphregion(color(white))  xtitle("Loan Number") xlabel(, angle(45)) ///
			 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample" ///
			 "Sample includes loans from loan packages with both institutional term loan and `category'") levels(90)
			gr export "$figures_output_path/loan_amounts_across_loan_number_coeff_`decomp_type'_`disc_type'.png", replace 

		*Do the same thing but look at the proportion of `category' in the total amount and the proportion relative to inst.

		estimates clear

		reg prop_`disc_type'_total n_* if category == "`category'" `cond', nocons
		estimates store `disc_type'_total

		reg prop_`disc_type'_inst n_* if category == "`category'" `cond', nocons
		estimates store `disc_type'_inst

		coefplot (`disc_type'_total, label(`category' Amount / Total Deal Amount) pstyle(p3))  ///
		(`disc_type'_inst, label(`category' Amount / Inst. Amount) pstyle(p5)) ///
		, vertical ytitle("Proportion") title("Coefficients on Proportion - `subsample_title'",size(medsmall)) ///
			graphregion(color(white))  xtitle("Loan Number") xlabel(, angle(45)) ///
			 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample" ///
			 "Sample includes loans from loan packages with both institutional term loan and `category'") levels(90)
			gr export "$figures_output_path/prop_`disc_type'_across_loan_number_coeff_`decomp_type'_`disc_type'.png", replace 

	}
}


***************************Do a similar analysis but by loan number within category
*****Now we will try to understand how the dynamics look like for ONLY revolvers/ institional term loans
****It appears what happens is that a firm often gets tons of loans before they get an institutional term loan
use "$data_path/dealscan_compustat_loan_level_with_loan_num", clear
sort borrower_lender_group_id facilitystartdate
order borrower_lender_group_id category facilitystartdate loan_number loan_num_category spread discount_1_simple

*First look at the first time I see a revolver, bank loan, and institutional term loan.
gen loan_num_of_first_loan = loan_number if loan_num_category ==1
*Only keep one of these per firm x lender category
bys borrower_lender_group_id category (facilitystartdate): replace loan_num_of_first_loan = . if facilitystartdate == facilitystartdate[_n-1]

*br borrower_lender_group_id category facilitystartdate loan_number loan_num_category loan_num_of_first_loan 

sum loan_num_of_first_loan if category == "Revolver"
sum loan_num_of_first_loan if category == "Bank Term"
sum loan_num_of_first_loan if category == "Inst. Term"

local cond "& discount_obs_rev_bco_group ==1"
sum loan_num_of_first_loan if category == "Revolver" `cond'
sum loan_num_of_first_loan if category == "Bank Term" `cond'
sum loan_num_of_first_loan if category == "Inst. Term" `cond'
*On average

local cond "& loan_num_of_first_loan <=15"

local rev (kdensity loan_num_of_first_loan if category == "Revolver" & discount_obs_rev_bco_group ==1 `cond', bwidth(.25) col(blue) lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))
local i_term (kdensity loan_num_of_first_loan if category == "Inst. Term" & discount_obs_rev_bco_group ==1 `cond', bwidth(.25) col(black) lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))

twoway `rev' `i_term'   ///
, ytitle("Density",axis(1))  ///
 title("Kernel Density of Loan number of First Loan of Type t",size(medsmall)) ///
graphregion(color(white))  xtitle("Loan Number") ///
legend(order(1 "Revolver" 2 "Inst. Term")) 

*Now do a simple plot of average spreads over time

local sample_cond "& discount_obs_rev_bco_group ==1"
local spread_var spread
foreach decomp_type in all  comp no_comp {
	
	if "`decomp_type'" == "all" {
		local cond ""
		local subsample_title "All"
	}
	if "`decomp_type'" == "comp" {
		local cond "& merge_compustat ==1"
		local subsample_title "Compustat"
	}

	if "`decomp_type'" == "no_comp" {
		local cond "& merge_compustat ==0"
		local subsample_title "Non- Compustat"
	}

	foreach fe_type in none borrower {

		if "`fe_type'" == "none" {
			local fe_settings "nocons"
			local fe_cond 
			local fe_add "No FE" 
			local drop_var
			local fe_suffix
			local fe_coeff_plot_opt 
		}
		if "`fe_type'" == "borrower" {
			local fe_settings "absorb(borrower_lender_group_id)"
			local fe_cond "& loan_num_category <=6"
			local fe_add "Borrower x Lender Group FE"
			local drop_var "drop cat_n_1"
			local fe_suffix "_borrowerfe"
			local fe_coeff_plot_opt "drop(_cons)"
		}
		*Want to drop the baseline category for the FE regression
		preserve
		`drop_var'
		estimates clear

		reg `spread_var' cat_n_* if category == "Revolver" `cond' `sample_cond' `fe_cond', `fe_settings' 
		estimates store spread_rev

		reg `spread_var' cat_n_* if category == "Inst. Term" `cond' `sample_cond' `fe_cond', `fe_settings'
		estimates store spread_i_term

		coefplot (spread_rev, label(Rev Spreads) pstyle(p5) `fe_coeff_plot_opt') ///
		(spread_i_term, label(Inst. Spreads) pstyle(p6) `fe_coeff_plot_opt') ///
		, vertical ytitle("`spread_label'") title("Coef on Loan Number (Category) - Decomposition - `fe_add' - `subsample_title'", size(small)) ///
			graphregion(color(white))  xtitle("Loan Number") xlabel(, angle(45)) ///
			 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample" ///
			 "Sample includes loans from loan packages with both institutional term loan and revolver") levels(90)
			gr export "$figures_output_path/decomposition_across_loan_number_category_coeff`fe_suffix'_`decomp_type'_with_spread_rev.png", replace 
			
		restore
	}
}


********* Analysis that makes the dataset a panel to try to understand spread dynamics.
*Create a "Panel" which will be borrowercompany x category and loan observation
use "$data_path/dealscan_compustat_loan_level_with_loan_num", clear
keep if !mi(borrowercompanyid) 
*keep borrowercompanyid category facilitystartdate date_quarterly discount_1_simple spread facilityamt ///
*first_loan prev_lender switcher_loan date_quarterly merge_compustat no_prev_lender first_loan switcher_loan 

*Need to collapse to make the panel (don't want to artificially call two of the same loans at the same time different loans
collapse (mean) spread (max) discount_1_simple date_quarterly merge_compustat no_prev_lender first_loan switcher_loan ///
discount_obs*, by(borrowercompanyid borrower_lender_group_id category facilitystartdate)

*Merge on BBB and lagged BBB spread so I can have "rates are declining or increasing" measures
preserve
	freduse BAMLC0A4CBBB , clear
	rename BAMLC0A4CBBB bbb_spread
	replace bbb_spread = bbb_spread*100
	gen date_quarterly = qofd(daten)
	collapse (max) bbb_spread , by(date_quarterly)
	tsset date_quarterly
	gen L1_bbb_spread = L.bbb_spread
	gen D1_bbb_spread = bbb_spread - L1_bbb_spread
	keep date_quarterly *bbb_spread
	tempfile rec
	save `rec', replace
restore

joinby date_quarterly using `rec', unmatched(master)

*Small issue where there are multiple "firsts" because its possible multiple loans of the same type are in 
*the same quarter but have different facility start dates
bys borrowercompanyid category date_quarterly (facilitystartdate): keep if _n ==1

gen first_loan_only_one = 1 if no_prev_lender==1
bys borrowercompanyid (facilitystartdate): replace first_loan_only_one = . if facilitystartdate == facilitystartdate[_n-1]
bys borrowercompanyid (facilitystartdate): gen new_lender_group_num = sum(first_loan_only_one)

*Create a new identifier to start creating hte loan numbers by category
egen id_var = group(borrowercompanyid new_lender_group category)
*now actually create it
bys id_var (facilitystartdate): gen loan_num_category = _n
*If I have multiple loans at the same point in time, set them equal to the same loan num
bys id_var (facilitystartdate): replace loan_num_category = loan_num_category[_n-1] if facilitystartdate == facilitystartdate[_n-1]

rename loan_num_category loan_number

sort id_var loan_number
order id_var loan_number facilitystartdate category

*Xtset it
xtset id_var loan_number
*Fix issue with negative spred
replace spread = . if spread<0
gen L1_spread = L1.spread
label var L1_spread  "L1 Spread"
label var spread "Spread"
*These regressions will be mechanical
*Want to regress difference in spreads onto differences in bond spreads
*Kind of like deposit beta regressions

/*
*These interactions will lead to mechanical results
*See if the persistance is symmetric
gen spread_diff = spread - L1_spread
gen spread_diff_pos = (spread_diff>0) & !mi(spread_diff)
gen spread_diff_neg = (spread_diff<0) & !mi(spread_diff)

*Create interactions
gen L1_spread_diff_pos = L1_spread* spread_diff_pos
gen L1_spread_diff_neg = L1_spread* spread_diff_neg
label var L1_spread_diff_pos "L1 Spread * D1 Spread Positive"
label var L1_spread_diff_neg "L1 Spread * D1 Spread Negative"
*/

*Make sure these interactions work and then make the table

order borrowercompanyid category facilitystartdate loan_number id_var spread

*Now we have a panel where basically we have the identifier is firm x loan type x lender group
gen constant =1
*Basic regressions
reg spread L1.spread
foreach rhs_type in simple /* interaction */ {
	if "`rhs_type'" == "simple" {
		local suffix
		local rhs L1_spread
	}
	if "`rhs_type'" == "interaction" {
		local suffix "_symmetric"
		local rhs L1_spread L1_spread_diff_pos L1_spread_diff_neg
	}
	estimates clear
	local i =1
	foreach sample in all /* discount_obs */ discount_obs_firm {
		foreach category in "rev" "b_term" "i_term" {
		if "`category'" == "rev" {
			local cond `"if category =="Revolver""'
		}
		if "`category'" == "b_term" {
			local cond `"if category =="Bank Term""'
		}
		if "`category'" == "i_term" {
			local cond `"if category =="Inst. Term""'
		}

			if "`sample'" == "all" {
				local sample_cond
				local sample_add "All"
			}
			if "`sample'" == "discount_obs" {
				local sample_cond "& discount_obs_any==1"
				local sample_add "Disc Obs"
			}
			if "`sample'" == "discount_obs_firm" {
				local sample_cond "& discount_obs_any_bco_group==1"
				local sample_add "Disc Firms"
			}
			
			reghdfe spread `rhs' `cond' `sample_cond' , a(constant) vce(cl borrowercompanyid)
			estadd local cat = "`category'"
			estadd local sample = "`sample_add'"
			estimates store est`i'
			local ++i
			
		}
		
	}

	esttab est* using "$regression_output_path/spread_autocorrelation_by_loan_type`suffix'.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
	title("Spread Autocorrelation") scalars("cat Loan Cat.""sample Sample") ///
	addnotes("SEs clustered at firm level" "Identifier is firm by loan type by lender group" ///
	"Discount obs are those for which a discount can be computed" "Discount firms are those that have had any discount at any points")
}

***********Do the same panel regression except this time keep only discount observations (or else it could be due to sample)
foreach disc_type in rev b_term {
	if "`disc_type'" == "rev" {
		local categories "rev i_term"
		local sample "Rev Discount"
		local keep "keep if discount_obs_rev==1"
	}
	if "`disc_type'" == "b_term" {
		local categories "b_term i_term"
		local sample "Bank Term Discount"
		local keep "keep if discount_obs_term==1"
	}

	use "$data_path/dealscan_compustat_loan_level_with_loan_num", clear
	keep if !mi(borrowercompanyid) 
	*Do only `disc_type' loans
	`keep'
	drop if spread <0

	*Need to collapse to make the panel (don't want to artificially call two of the same loans at the same time different loans
	collapse (mean) spread (max) discount_1_simple date_quarterly merge_compustat no_prev_lender first_loan switcher_loan ///
	discount_obs*, by(borrowercompanyid borrower_lender_group_id category facilitystartdate)

	*Merge on BBB and lagged BBB spread so I can have "rates are declining or increasing" measures
	preserve
		freduse BAMLC0A4CBBB , clear
		rename BAMLC0A4CBBB bbb_spread
		replace bbb_spread = bbb_spread*100
		gen date_quarterly = qofd(daten)
		collapse (max) bbb_spread , by(date_quarterly)
		tsset date_quarterly
		gen L1_bbb_spread = L.bbb_spread
		gen D1_bbb_spread = bbb_spread - L1_bbb_spread
		keep date_quarterly *bbb_spread
		tempfile rec
		save `rec', replace
	restore

	joinby date_quarterly using `rec', unmatched(master)

	*Small issue where there are multiple "firsts" because its possible multiple loans of the same type are in 
	*the same quarter but have different facility start dates
	bys borrower_lender_group_id category date_quarterly (facilitystartdate): keep if _n ==1

	gen first_loan_only_one = 1 if no_prev_lender==1
	bys borrower_lender_group_id (facilitystartdate): replace first_loan_only_one = . if facilitystartdate == facilitystartdate[_n-1]
	bys borrower_lender_group_id (facilitystartdate): gen new_lender_group_num = sum(first_loan_only_one)

	*Create a new identifier to start creating hte loan numbers by category
	egen id_var = group(borrowercompanyid new_lender_group category)
	*now actually create it
	bys id_var (facilitystartdate): gen loan_num_category = _n
	*If I have multiple loans at the same point in time, set them equal to the same loan num
	bys id_var (facilitystartdate): replace loan_num_category = loan_num_category[_n-1] if facilitystartdate == facilitystartdate[_n-1]

	rename loan_num_category loan_number

	sort id_var loan_number
	order id_var loan_number facilitystartdate category

	*Xtset it
	xtset id_var loan_number
	gen L1_spread = L1.spread
	label var L1_spread  "L1 Spread"
	label var spread "Spread"

	*Now we have a panel where basically we have the identifier is firm x loan type x lender group
	gen constant =1
	*Basic regressions
	reg spread L1.spread
	foreach rhs_type in simple {
		if "`rhs_type'" == "simple" {
			local suffix
			local rhs L1_spread
		}

		estimates clear
		local i =1
		foreach sample in discount_obs {
			foreach category in `categories' {
			di "`categories'"
			if "`category'" == "rev" {
				local cond `"if category =="Revolver""'
			}
			if "`category'" == "b_term" {
				local cond `"if category =="Bank Term""'
			}
			if "`category'" == "i_term" {
				local cond `"if category =="Inst. Term""'
			}

				if "`sample'" == "discount_obs" {
					local sample_cond ""
					local sample_add "`sample'"
				}
				
				reghdfe spread `rhs' `cond' `sample_cond' , a(constant) vce(cl borrowercompanyid)
				estadd local cat = "`category'"
				estadd local sample = "`sample_add'"
				estimates store est`i'
				local ++i
				
			}
			
		}
		*You may notice there is a small difference in sample size, and this occurs because sometimes
		*There are no lead arrangers on an institutional loan so we drop it from the sample, after
		*discount has been calculated
		esttab est* using "$regression_output_path/spread_autocorrelation_by_loan_type`suffix'_`disc_type'_disc_obs_only.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
		title("Spread Autocorrelation") scalars("cat Loan Cat.""sample Sample") ///
		addnotes("SEs clustered at firm level" "Identifier is firm by loan type by lender group" ///
		"Discount obs are those for which a discount can be computed")
	}
}
