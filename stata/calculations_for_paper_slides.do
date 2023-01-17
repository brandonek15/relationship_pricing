*This program helps calculate numbers that are used in the paper

*Number of dealscan loans
use  "$data_path/dealscan_compustat_loan_level", clear
sum constant
local num_loans `r(N)'
keep borrowercompanyid facilitystartdate constant
duplicates drop
sum constant
local num_packages `r(N)'

di "Number of packages is `num_packages'. Number of loans is `num_loans'"
*Calculate number of discounts
use  "$data_path/dealscan_compustat_loan_level", clear
sum constant if !mi(discount_1_simple) & category == "Revolver"
local num_rev `r(N)'
sum constant if !mi(discount_1_simple) & category == "Bank Term"
local num_term `r(N)'
di "Number of revolving discounts is `num_rev'. Number of bank term discounts is `num_term'"
*Calculate number of dealscan observations
sum constant if merge_compustat==1 
local num_comp `r(N)'
sum constant if !mi(discount_1_simple) & category == "Revolver" & merge_compustat==1 
local num_rev_comp `r(N)'
sum constant if !mi(discount_1_simple) & category == "Bank Term" & merge_compustat==1 
local num_term_comp `r(N)'
di "Number of observations with compustat data is `num_comp'"
di "Number of revolving compustat discounts is `num_rev_comp', term discounts `num_term_comp'"

*Correlation between simple and controls discount
use  "$data_path/dealscan_compustat_loan_level", clear
corr discount_1_simple discount_1_controls if category == "Revolver"
local corr = r(rho)
di "Correlation between simple revolving discount and revolving discount with controls is is : `corr'"

*Number of packages that we can calculate a discount.
use "$data_path/dealscan_compustat_loan_level", clear
keep if date_quarterly >=tq(1991q3) //First date that discounts can be calculated
*br if borrowercompanyid == 11649 & date_quarterly == tq(2007q3)
gen rev_loan_cat = (category == "Revolver")
gen bank_term_loan_cat = (category == "Bank Term")
gen inst_term_loan_cat = (category == "Inst. Term")
gen other_loan_cat = (category == "Other")
collapse (sum) facilityamt (max) *_cat, by(borrowercompanyid facilitystartdate merge_compustat)
isid borrowercompanyid facilitystartdate
gen package_type = ""
replace package_type = "Only Revolver" if rev_loan_cat ==1 & bank_term_loan_cat ==0 & inst_term_loan_cat ==0
replace package_type = "Only Bank Term" if rev_loan_cat ==0 & bank_term_loan_cat ==1 & inst_term_loan_cat ==0
replace package_type = "Only Inst. Term" if rev_loan_cat ==0 & bank_term_loan_cat ==0 & inst_term_loan_cat ==1
replace package_type = "Rev + Bank Term" if rev_loan_cat ==1 & bank_term_loan_cat ==1 & inst_term_loan_cat ==0
replace package_type = "Rev + Inst. Term" if rev_loan_cat ==1 & bank_term_loan_cat ==0 & inst_term_loan_cat ==1
replace package_type = "Bank Term + Inst. Term" if rev_loan_cat ==0 & bank_term_loan_cat ==1 & inst_term_loan_cat ==1
replace package_type = "Rev + Bank Term + Inst. Term" if rev_loan_cat ==1 & bank_term_loan_cat ==1 & inst_term_loan_cat ==1
replace package_type = "Only Other" if other_loan_cat ==1 & rev_loan_cat ==0 & bank_term_loan_cat ==0 & inst_term_loan_cat ==0
drop if mi(package_type)

qui sum rev_loan_cat if package_type == "Rev + Inst. Term" | package_type == "Bank Term + Inst. Term" ///
	| package_type == "Rev + Bank Term + Inst. Term"
local disc_obs = `r(N)'
qui sum rev_loan_cat
local num_obs = `r(N)'

local perc_disc = round(`disc_obs'/`num_obs'*100,0.01)

di "Percent of packages where we can calculate a discount: `perc_disc'"

*Correlation of bank term discount and revolving discount
use "$data_path/stata_temp/dealscan_discounts", clear
corr rev_discount_1_simple term_discount_1_simple
local corr = r(rho)
di "Correlation between simple revolving discount and bank term discoutn is : `corr'"

*Back of the envelope
*Cost of providing a discount: 45bps (coefficient) * 234M (avg revolver amount for compustat) * 23% bank allocation * 56% avg utilization
*Cost of providing = 0.14M a year
use  "$data_path/dealscan_compustat_loan_level", clear
sum facilityamt if category == "Revolver" & merge_compustat ==1 & !mi(discount_1_simple)
use "$data_path/stata_temp/facilityid_lender_merge_data", clear
sum bankallocation if lead_arranger_credit==1
*Benefit of providing: 10.9M (avg fee) * 12.8% = 1.40M. Expected benefit = 1.40/5 = 0.28M a year
*Be conservative and assume there is only assume they will have 1 issuance on average over 5 years
*Net benefit = .28M-.14M=140,000
/*
use "$data_path/sdc_all_clean", clear
sum gross_spread_dol
use "$data_path/sdc_all_clean", clear
gen count = 1
collapse (first) first_date_daily = date_daily (last) last_date_daily = date_daily ///
	(sum) count, by(cusip_6)
gen potential_years = year(last_date_daily) - year(first_date_daily) + 1
gen deals_per_year = count/potential_years
winsor2 deals_per_year, cut(0 99) replace
drop if potential_years ==1
sum deals_per_year
