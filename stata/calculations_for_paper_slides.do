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


*Correlation of bank term discount and revolving discount
use "$data_path/stata_temp/dealscan_discounts", clear
corr rev_discount_1_simple term_discount_1_simple
local corr = r(rho)
di "Correlation between simple revolving discount and bank term discoutn is : `corr'"
