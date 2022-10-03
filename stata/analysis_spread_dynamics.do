*This program will try to understand the spread dynamics of the spreads 
*that are calculated into discounts

*First we will explore plot a simple example of a firm that has many interactions and
*how their discount changes over time

*Then we will plot the same graphs as the "discount over time" one but decomposed
*MEaning have 2 graphs, each with three series "rev spread" "inst stpread" "discount"

*Think about how to adjust this
*Then label
*********
use "$data_path/dealscan_compustat_loan_level", clear
keep if !mi(borrowercompanyid) 
keep borrowercompanyid category facilitystartdate discount_1_simple spread ///
first_loan prev_lender switcher_loan date_quarterly merge_compustat no_prev_lender

*Spread out dummies for whether discounts of each type exist within borrowercompanyid and date_daily
gen t_discount_obs_rev = !mi(discount_1_simple) & category == "Revolver"
gen t_discount_obs_term = !mi(discount_1_simple) & category == "Bank Term"
egen discount_obs_rev = max(t_discount_obs_rev), by(borrowercompanyid facilitystartdate)
egen discount_obs_term = max(t_discount_obs_term), by(borrowercompanyid facilitystartdate)
drop t_*
sort borrowercompanyid facilitystartdate category discount_1_simple discount_obs*


*I want the loan number to be 1 if it is labeled as a "no_prev_lender" and then the number number goes up
*until it hits no_prev_lending relationship again.
gen loan_number = 1 if no_prev_lender==1
bys borrowercompanyid (facilitystartdate): replace loan_num = loan_num[_n-1] + 1 if mi(loan_num)
*If I have multiple loans at the same point in time, set them equal to the same loan num
bys borrowercompanyid (facilitystartdate): replace loan_num = loan_num[_n-1] if facilitystartdate == facilitystartdate[_n-1]
*br borrowercompanyid facilitystartdate category discount_1_simple discount_obs* spread loan_number no_prev_lender
*Make a simple graph of the average discount by observation num
forval i = 1/6 {
	gen n_`i' = loan_number == `i'
	label var n_`i' "Loan Num `i'"
}


preserve
*Only do one discount type at a time
*Keep only discount observations
keep if discount_obs_rev ==1

estimates clear

reg discount_1_simple n_* if category == "Revolver" & merge_compustat==1, nocons
estimates store comp_disc

reg spread n_* if category == "Revolver" & merge_compustat==1, nocons
estimates store comp_spread_rev

reg spread n_* if category == "Inst. Term" & merge_compustat==1, nocons
estimates store comp_spread_i_term

coefplot (comp_disc, label(Compustat Firm Discounts) pstyle(p3)) (comp_spread_rev, label(Compustat Rev Spreads) pstyle(p4)) ///
(comp_spread_i_term, label(Compustat Inst. Spreads) pstyle(p5)) ///
, vertical ytitle("Discount/Spread") title("Coefficients on Loan Number - Decomposition - Compustat Firms") ///
	graphregion(color(white))  xtitle("Loan Number") xlabel(, angle(45)) ///
	 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample" ///
	 "Sample includes loans from loan packages with both institutional term loan and revolver") levels(90)
	gr export "$figures_output_path/discounts_across_loan_number_coeff_comp_with_spread_rev.png", replace 

estimates clear

reg discount_1_simple n_* if category == "Revolver" & merge_compustat==0, nocons
estimates store no_comp_disc

reg spread n_* if category == "Revolver" & merge_compustat==0, nocons
estimates store no_comp_spread_rev

reg spread n_* if category == "Inst. Term" & merge_compustat==0, nocons
estimates store no_comp_spread_i_term

coefplot (no_comp_disc, label(Non-Compustat Firm Discounts) pstyle(p3)) (no_comp_spread_rev, label(Non-Compustat Rev Spreads) pstyle(p4)) ///
(no_comp_spread_i_term, label(Non-Compustat Inst. Spreads) pstyle(p5)) ///
, vertical ytitle("Discount/Spread") title("Coefficients on Loan Number - Decomposition - Non-Compustat Firms") ///
	graphregion(color(white))  xtitle("Loan Number") xlabel(, angle(45)) ///
	 note("Constant Omitted. Loan numbers greater than 6 omitted due to small sample" ///
	 "Sample includes loans from loan packages with both institutional term loan and revolver") levels(90)
	gr export "$figures_output_path/discounts_across_loan_number_coeff_no_comp_with_spread_rev.png", replace 

restore

preserve
*Only do one discount type at a time
*Keep only term discount observations
keep if discount_obs_term ==1

restore

*********
*Create a "Panel" which will be borrowercompany x category and loan observation
use "$data_path/dealscan_compustat_loan_level", clear
keep if !mi(borrowercompanyid) 
keep borrowercompanyid category facilitystartdate date_quarterly discount_1_simple spread facilityamt ///
first_loan prev_lender switcher_loan date_quarterly merge_compustat no_prev_lender first_loan switcher_loan 

*Need to collapse to make the panel (don't want to artificially call two of the same loans at the same time different loans
collapse (mean) spread (max) discount_1_simple date_quarterly merge_compustat no_prev_lender first_loan switcher_loan ///
, by(borrowercompanyid category facilitystartdate)

*Small issue where there are multiple "firsts" because its possible multiple loans of the same type are in 
*the same quarter but have different facility start dates
bys borrowercompanyid category date_quarterly (facilitystartdate): keep if _n ==1


*I want the loan number to be 1 if it is labeled as a "no_prev_lender" and then the number number goes up
*until it hits no_prev_lending relationship again.
gen loan_number = 1 if no_prev_lender==1
*Calculate which first loan this is the firm, which essentially marks a new lender
bys borrowercompanyid category (facilitystartdate): gen cumu_first = sum(loan_number)
gen new_lender_group_num = cumu_first
drop cumu_first
*Add one as we move forward
bys borrowercompanyid category (facilitystartdate): replace loan_num = loan_num[_n-1] + 1 if mi(loan_num)

*Create an ID variable
egen id_var = group(borrowercompanyid new_lender_group category)


drop if mi(loan_number)

*Xtset it
xtset id_var loan_number

order borrowercompanyid category facilitystartdate loan_number id_var spread

*Lastly let's create a dummy so we can restrict our regressions to only firms that at some point receive some discount
*Spread out dummies for whether discounts of each type exist within borrowercompanyid and date_daily
gen t_discount_obs_rev = !mi(discount_1_simple) & category == "Revolver"
gen t_discount_obs_term = !mi(discount_1_simple) & category == "Bank Term"
egen discount_obs_rev = max(t_discount_obs_rev), by(borrowercompanyid)
egen discount_obs_term = max(t_discount_obs_term), by(borrowercompanyid)
egen discount_obs_any = rowmax(discount_obs_rev discount_obs_term)

*Now we have a panel where basically we have the identifier is firm x loan type x lender group
gen constant =1
label var spread "Spread"
*Basic regressions
reg spread L1.spread
estimates clear
local i =1
foreach sample in all discount_obs {
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
			local sample_add "Discount Firms"
		}
		
		reghdfe spread L1.spread `cond' `sample_cond' , a(constant) vce(cl borrowercompanyid)
		estadd local cat = "`category'"
		estadd local sample = "`sample_add'"
		estimates store est`i'
		local ++i
		
	}
	
}

esttab est* using "$regression_output_path/spread_autocorrelation_by_loan_type.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
title("Spread Autocorrelation") scalars("cat Loan Cat.""sample Sample") ///
addnotes("SEs clustered at firm level" "Identifier is firm by loan type by lender group" "Discount firms are those that have had any discount at any points")

*Then we will run the same regression of spread onto previous relationship, but only
*do within firm x type

*Then also explore how they look by looking at data directly
