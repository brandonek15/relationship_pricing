*This program will create a dataset where each observation is a "lender" x facilityid
* and the set of lenders is the set of biggest lenders/bookrunners
*Then it will merge on the most recent information from an equity, debt, conv offering
*and term, revolving, and other loan from the same lender.

*Make a skeleton dataset
do "$code_path/programs_relationship"

*As inputs it will take the following:
*Number of lenders per deal
local n_lenders 20
*Get the skeleton dataset (sdc_deal_id x lender)
use "$data_path/stata_temp/skeleton_ds_`n_lenders'", clear

*Now fill out the skeleton. Need to pass the function 5 arguments
*Type is either SDC or DS (it is what the baseline structure of the skeleton is made of)
local type "ds"
*base_vars are the variables you want about the current observation (meaning the deal/loan is the unit)
local base_vars borrowercompanyid rev_loan term_loan other_loan spread rev_discount_1_simple log_facilityamt
*sdc_vars are the variables you want from the most recent equity,debt,conv offerings
local sdc_vars gross_spread_perc proceeds log_proceeds
*ds_vars are the variables you want from the most recent term,rev,other loans 
local ds_vars loantype packageid log_facilityamt maturity rev_discount_1_simple spread
*ds_lender_vars are the variables you want abou the most recent dealscan lenders.
local ds_lender_vars lenderrole bankallocation lead_arranger_credit agent_credit
fill_out_skeleton "`type'" "`base_vars'" "`sdc_vars'" "`ds_vars'" "`ds_lender_vars'" "`n_lenders'"

*Create interactions and label variables
prepare_rel_dataset

isid facilityid lender
save "$data_path/ds_lending_with_past_relationships_`n_lenders'", replace 
