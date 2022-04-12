*This program will create a dataset where each observation is a "lender" x sdc_deal_id
* and the set of lenders is the set of biggest lenders/bookrunners
*Then it will merge on the most recent information from an equity, debt, conv offering
*and term, revolving, and other loan from the same lender.

*Make a skeleton dataset
do "$code_path/programs_relationship"

*As inputs it will take the following:
*Number of lenders per deal
local n_lenders 20
*Get the skeleton dataset (sdc_deal_id x lender)
use "$data_path/stata_temp/skeleton_sdc_`n_lenders'", clear

*Now fill out the skeleton. Need to pass the function 5 arguments
*Type is either SDC or DS (it is what the baseline structure of the skeleton is made of)
local type "sdc"
*base_vars are the variables you want about the current observation (meaning the deal/loan is the unit)
local base_vars issuer equity debt conv gross_spread_perc log_proceeds
*sdc_vars are the variables you want from the most recent equity,debt,conv offerings
local sdc_vars gross_spread_perc proceeds log_proceeds
*ds_vars are the variables you want from the most recent term,rev,other loans 
local ds_vars loantype packageid log_facilityamt maturity discount_1_simple discount_1_controls d_1_simple_pos d_1_controls_pos spread ///
	d_1_simple_le_0 d_1_simple_0 d_1_simple_0_25 d_1_simple_25_50 d_1_simple_50_100 d_1_simple_100_200 d_1_simple_ge_200 ///
		d_1_controls_le_0 d_1_controls_0 d_1_controls_0_25 d_1_controls_25_50 d_1_controls_50_100 d_1_controls_100_200 d_1_controls_ge_200

*ds_lender_vars are the variables you want abou the most recent dealscan lenders.
local ds_lender_vars lenderrole bankallocation lead_arranger_credit agent_credit
fill_out_skeleton "`type'" "`base_vars'" "`sdc_vars'" "`ds_vars'" "`ds_lender_vars'" "`n_lenders'"

*Create interactions and label variables
prepare_rel_dataset "`sdc_vars'" "`ds_vars'" "`ds_lender_vars'"

isid sdc_deal_id lender
save "$data_path/sdc_deals_with_past_relationships_`n_lenders'", replace 
