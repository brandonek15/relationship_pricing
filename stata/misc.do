*Random stuff to explore data
use "$data_path/sdc_equity_clean", clear

bys cusip_6 date_quarterly (date_daily): gen N = _N

local collapse_vars sec_type
local max_vars ipo debt equity convertible
local last_vars issuer business_desc currency bookrunners all_managers
local sum_vars management_fee_dol underwriting_fee_dol selling_conc_dol ///
	reallowance_dol gross_spread_dol proceeds_local num_units
local mean_vars gross_spread_per_unit gross_spread_perc management_fee_perc underwriting_fee_perc ///
	selling_conc_perc reallowance_perc 
local weight_var proceeds_local

collapse (rawsum) `sum_vars' (max) `max_vars' (last) `last_vars' ///
	(mean) `mean_vars' [aweight=`weight_var'], by(cusip_6 date_quarterly)

foreach var in `sum_vars' `mean_vars' {
	replace `var' = . if `var' ==0
}

rename proceeds_local proceeds
*Most important variables: The gross spread_percent, gross_spread_dollar, the proceeds, the cusip_6 and the date_quarterly
*From here I have whether there is a deal (make an indicator for whether it gets merged on?
*And then I also have data on the "price" and the size
isid cusip_6 date_quarterly


*Todo, figure out how to deal with bookrunners? some sort of egen to combine information? Need to standardize names


use "$data_path/compustat_clean", clear
bys cusip_6 date_quarterly: gen N = _N

use "$data_path/dealscan_quarterly", clear

*

/* If I want to merge a different way
joinby borrowercompanyid date_quarterly using "$data_path/dealscan_facility_level", ///
unmatched(master) _merge(dealscan_merge_cat)
*Now I have a dataset that may have multiple observations for the same cusip_6 date_quarterly if there are multiple
*Facilities. It is a company x quarter x facility dataset
save "$data_path/merged_data_comp_quart_fac", replace

use "$data_path/merged_data_comp_quart", clear
sort cusip_6 date_quarterly
br merge_equity conm issuer_equity date_quarterly cusip_6 cusip cik public_equity private_equity withdrawn_equity
br conm issuer_equity cik date_quarterly merge_equity  cusip_6 borrowercompanyid  merge_dealscan
br merge_equity conm issuer_equity date_quarterly cusip_6 cusip cik public private withdrawn if merge_equity == 2
*/

*Start standardizing bookrunners
use "$data_path/sdc_debt_clean", clear
br issuer date_daily bookrunners all_managers bookrunner_*
sort bookrunner_1
br issuer date_daily bookrunners all_managers bookrunner_* if bookrunner_1 == "Ameritas"

*
use "$data_path/dealscan_facility_lender_level", clear


use "$data_path/dealscan_lender_level", clear
bys lender: gen N = _N

/* All the datasets
use "$data_path/sdc_dealscan_pairwise_combinations", clear
isid sdc_deal_id facilityid lender cusip_6
*Other data I may need to merge on
use "$data_path/sdc_all_clean", clear
isid sdc_deal_id
use "$data_path/stata_temp/dealscan_discounts_facilityid", clear
isid facilityid
use "$data_path/sdc_deal_bookrunner", clear
isid sdc_deal_id lender
use "$data_path/lender_facilityid_cusip6", clear
isid facilityid lender


*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

*Use the all possible relationships data
use "$data_path/sdc_dealscan_pairwise_5yrs_post_ds", clear

*isid cusip_6 lender_dealscan lender_sdc sdc_deal_id facilityid 
br issuer lender* same_lender cusip_6  date_daily_sdc date_daily_dealscan loantype loan_share ///
	rev_discount_1_simple gross_spread_perc proceeds sdc_deal_id facilityid

*Analyses
*E.g. regress any future SDC issuance on whether the bookrunner of the issuance
*Observation should be a dealscan lender x facility, regression is indicator of future issuance with t days on nothign, and then on discount
*Can seperate by whether the issuance is equity, debt, convertible
*Max vars are the SDC variables, last_vars are the Dealscan variables (which don't change by obs)
local max_vars same_lender* equity debt conv term_loan rev_loan other_loan 
local last_vars spread rev_discount_* loan_share maturity log_facilityamt agent_credit lead_arranger_credit
*The sample here is dealscan lender x facilityid 
collapse (max) `max_vars' (last) `last_vars' ///
	, by(lender_dealscan facilityid)

cap gen constant = 1

foreach type in all equity debt {

	if "`type'" == "equity" {
		local cond "if `type' ==1" 
	}
	if "`type'" == "debt" {
		local cond "if `type' ==1" 
	}
	if "`type'" == "all" {
		local cond "" 
	}
	estimates clear
	local i = 1

	reghdfe same_lender `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reghdfe same_lender rev_loan term_loan other_loan `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reghdfe same_lender lead_arranger_credit agent_credit `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reghdfe same_lender loan_share `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reghdfe same_lender spread maturity log_facilityamt `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reghdfe same_lender rev_discount_1_simple `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	reghdfe same_lender rev_loan term_loan other_loan lead_arranger_credit agent_credit ///
	loan_share spread maturity log_facilityamt  rev_discount_1_simple `cond', a(constant) vce(robust)
	estadd local fe = "No"
	estimates store est`i'
	local ++i

	esttab est* using "$regression_output_path/regressions_likelihood_from_ds_to_sdc_`type'.tex", replace b(%9.3f) se(%9.3f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
	title("Time to Securitization Regressions - `vert_type'") scalars("fe Fixed Effects" ) addnotes("Robust SEs"  ///
	"Fixed effects codes: G=Group (property type),P=Pool,T=Origination Month,O=Originator")

}
