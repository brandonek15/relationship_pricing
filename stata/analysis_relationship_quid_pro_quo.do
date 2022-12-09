*This graph plots how much the spreads in revolvers and inst. term loans change within the same lender group
*The idea is that if they change less for revolvers, there is essentially a quid pro quo that they will keep
*Prices similar
use "$data_path/dealscan_compustat_loan_level_with_loan_num", clear
keep if !mi(borrowercompanyid) 
*Do only `disc_type' loans
keep if discount_obs_rev==1
drop if spread <0
*br borrowercompanyid facilitystartdate category spread discount_1_simple

*Need to collapse to make the panel (don't want to artificially call two of the same loans at the same time different loans
collapse (mean) spread (max) discount_1_simple date_quarterly merge_compustat no_prev_lender first_loan switcher_loan ///
discount_obs*, by(borrowercompanyid borrower_lender_group_id category facilitystartdate)

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
gen D1_spread = D1.spread
label var L1_spread  "L1 Spread"
label var spread "Spread"
label var D1_spread "D1_Spread'

winsor2 D1_spread, cuts(5 95) replace

*Make a Kdensity with the distributions of changes in interest rates from one loan to the next (only discounted loans)

local kden_rev (kdensity D1_spread if category =="Revolver", bwidth(2) col(black) lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))
local kden_i_term (kdensity D1_spread if category =="Inst. Term", bwidth(2) col(blue) lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))

twoway `kden_rev' `kden_i_term'  ///
, ytitle("Density",axis(1))  ///
 title("Kernel Density of Changes in Loan Spreads within Firm x Lending Group",size(medsmall)) ///
graphregion(color(white))  xtitle("Changes in Spreads") ///
legend(order(1 "Revolving Spreads" 2 "Inst. Term Spreads")) ///
 note("Sample includes only loan packages where a revolving discount can be computed" "Epanechnikov kernel with bandwith 2" ///
 "Differenced Winsorized at 5% and 95%")
gr export "$figures_output_path/spread_changes_by_category_rev_discount.png", replace 

*Make one where I am looking at the difference in the spread changes?. Do the spreads change together?
*Need to reshape the dataset
*Generate a new id_var
egen firm_lender_group = group(borrowercompanyid new_lender_group)
keep firm_lender_group loan_number category *spread*
keep if category == "Revolver" | category == "Inst. Term"
replace category = "rev" if category== "Revolver" 
replace category = "i_term" if category == "Inst. Term"
reshape wide *spread*, i(firm_lender_group loan_number) j(category) string
*Now calculate the difference between how much i_term has changed and how much rev has changed
gen diff_in_change = D1_spreadi_term - D1_spreadrev

local kden_diff_in_change (kdensity diff_in_change, bwidth(2) col(black) lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))

twoway `kden_diff_in_change' ///
, ytitle("Density",axis(1))  ///
 title("Kernel Density of (Change I-Term minus Change Revolver) Firm x Lending Group",size(medsmall)) ///
graphregion(color(white))  xtitle("Difference in Changes of Spreads") ///
 note("Sample includes only loan packages where a revolving discount can be computed" "Epanechnikov kernel with bandwith 2" ///
 "Differenced Winsorized at 5% and 95%")
gr export "$figures_output_path/differences_in_spread_changes_rev_discount.png", replace 
