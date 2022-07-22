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


*Correlation of bank term discount and revolving discount
use "$data_path/stata_temp/dealscan_discounts", clear
corr rev_discount_1_simple term_discount_1_simple
local corr = r(rho)
di "Correlation between simple revolving discount and bank term discoutn is : `corr'"
