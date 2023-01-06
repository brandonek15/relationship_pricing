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
*/
*Do joinbys on the same dataset to make matches

use "$data_path/sdc_all_clean", clear
rename * *_copy
rename cusip_6_copy cusip_6

joinby cusip_6 using "$data_path/sdc_deal_bookrunner",unmatched(none)
*Cannot do this, has 222m observations (obviously we have duplicates but this is unreasonable)

*As inputs it will take the following:
*Number of lenders per deal
local n_lenders 20
*Get the skeleton dataset (sdc_deal_id x lender)
make_skeleton "ds" `n_lenders'

use "$data_path/sdc_deals_with_past_relationships_20", clear

/*
egen past_relationship = rowmax(rel_equity rel_debt rel_conv rel_institutional_loan rel_term_loan rel_other_loan)
reg hire past_relationship
*/

gen institutional_loan_discount_inter = 0
replace rev_loan_discount_inter = discount_1_simple_rev_loan*rel_rev_loan if !mi(discount_1_simple_rev_loan)
*br rev_loan_discount_inter discount_1_simple_rev_loan rel_rev_loan

foreach type in all equity debt {

	if "`type'" == "equity" {
		local cond "if `type' ==1" 
	}
	if "`type'" == "debt" {
		local cond "if `type'==1" 
	}
	if "`type'" == "all" {
		local cond "if 1 ==1" 
	}
	estimates clear
	local i = 1

	reg hire rel* `cond'
	
	reg hire rel* rev_loan_discount_inter `cond'
	
}

*Make some figures
use "$data_path/sdc_deals_with_past_relationships_20", clear
gen count =1
*sort cusip_6 sdc_deal_id lender
collapse (sum) count (mean) rel_*, by(hire equity_base debt_base conv_base)
*

*Understand the discount
use "$data_path/stata_temp/dealscan_discounts_facilityid", clear
br borrowercompanyid date_quarterly packageid facilityid rev_loan institutional discount_1_simple ///
 spread spread_2 discount* if !mi(discount_1_simple)
 
br borrowercompanyid date_quarterly packageid facilityid rev_loan term_loan other_loan discount* ///
spread if borrowercompanyid == 19196 & date_quarterly == tq(2003q2)

*Do the same for term loan
use "$data_path/dealscan_compustat_loan_level", clear
keep if category =="Bank Term" & !mi(cusip_6) & !mi(discount_1_simple)
bys cusip_6 (facilitystartdate): gen n = _n
bys cusip_6 (facilitystartdate): gen N = _N
sum discount_1_simple if n ==1
sum discount_1_simple if n >1

sum discount_1_simple if n ==1 & N>1
sum discount_1_simple if n >1 & N>1

gen count = 1
reghdfe discount_1_simple n, absorb(count)
reghdfe discount_1_simple n, absorb(cusip_6)
reghdfe discount_1_simple n, absorb(cusip_6 date_quarterly)
reghdfe discount_2_simple n, absorb(cusip_6 date_quarterly)


*Make a simple graph of the average discount by observation num
collapse (sum) count (mean) discount*, by(n)
twoway line discount_1_simple n

		local discount_n (line discount_1_simple n, yaxis(1))
		local count_n (line count n, yaxis(2))

		twoway `discount_n' `count_n' , ///
			legend(order(1 "Discount" 2 "Number of Obs")) ///
			title("Avg Revolver Discount and Loan Number in Sample")  ytitle("Discount", axis(1)) ///	
			ytitle("Number of Observations", axis(2)) xtitle("Revolving Loan Number")
		gr export "$figures_output_path/bank_discount_across_loan_number.png", replace 



*
use "$data_path/ds_lending_with_past_relationships_20", clear
reghdfe log_facilityamt_base rel_* spread_base if rev_loan_base ==1 & hire !=0, absorb(constant) vce(robust)

*See fraction 0 over time
use "$data_path/dealscan_compustat_loan_level", clear
keep if rev_loan ==1
keep if !mi(discount_1_simple)
gen zero_discount = abs(discount_1_simple)<10e-6
collapse (mean) zero_discount, by(date_quarterly)
twoway line zero_discount date_quarterly

*See number of deals with a discount and multiple revolving lines of credit
use "$data_path/dealscan_compustat_loan_level", clear
drop if other_loan ==1
keep if !mi(discount_1_simple)
bys borrowercompanyid date_quarterly rev_loan: gen N = _N
br borrowercompanyid date_quarterly rev_loan discount_1_simple spread N
keep if rev_loan ==1
tab N
gen n = 1/N
collapse (sum) n, by(N)

*See who is giving out term loans and who is giving out revolving loans
use "$data_path/dealscan_compustat_lender_loan_level", clear
gen total = 1
collapse (sum) rev_loan term_loan institutional_term_loan total, by(lender)

gsort -total
br

*Try to make a table comparing means
use  "$data_path/dealscan_compustat_loan_level", clear
keep if merge_compustat==1

local firm_chars L1_market_to_book L1_ppe_assets L1_log_assets L1_leverage ///
L1_roa L1_sales_growth L1_ebitda_int_exp ///
L1_working_cap_assets L1_capex_assets
keep borrowercompanyid date_quarterly discount_obs  `firm_chars' 
duplicates drop

winsor2 `firm_chars', cuts(.5 99.5) replace

eststo: estpost ttest `firm_chars' , by(discount_obs) unequal
	
esttab . using "$regression_output_path/differences_firm_chars_discount_obs.tex", ///
 label title("Origination Level Loan Characteristics- `title_add'") replace ///
cells("mu_2(fmt(3)) mu_1(fmt(3)) b(star)") collabels("Disc Obs" "Non Disc Obs" "Difference") ///
 nonum eqlabels(none) addnotes("Sample is Observations Merged to Compustat") 

use  "$data_path/dealscan_compustat_loan_level", clear
keep if category == "Revolver" | category == "Bank Term"

local loan_vars log_facilityamt maturity leveraged fin_cov nw_cov borrower_base cov_lite asset_based spread institutional salesatclose 

winsor2 `loan_vars', cuts(.5 99.5) replace
eststo: estpost ttest `loan_vars', by(discount_obs) unequal
	
esttab . using "$regression_output_path/differences_loan_chars_discount_obs.tex", ///
 label title("Origination Level Loan Characteristics- `title_add'") replace ///
cells("mu_2(fmt(3)) mu_1(fmt(3)) b(star)") collabels("Disc Obs" "Non Disc Obs" "Difference") ///
 nonum eqlabels(none) addnotes("Sample is Revolver and Bank Term Loans") 


*Try making alternative discount measures where I drop non institutional term loans
*Get the facility level data
use "$data_path/dealscan_facility_level", clear

*I will use facilityid x revolving fixed effects.
*This gives me an coefficient for for facility id x  revolving and facilityid x term (through the FE). 
*The difference between the two will give me the "discount"
egen borrowerid_rev_loan_quarter = group(borrowercompanyid rev_loan date_quarterly)
*Loop over different measures of the discount
foreach spread_type in standard alternate {
	if "`spread_type'" == "standard" {
		local spread_var spread
		local spread_suffix 1
	}
	if "`spread_type'" == "alternate" {
		local spread_var spread_2
		local spread_suffix 2
	}
	
	foreach discount_type in simple controls {
	
		if "`discount_type'" == "simple" {
			local controls 
		}
		if "`discount_type'" == "controls" {
			local controls log_facilityamt maturity
		}
		*Only want term and rev_loan obs in the regression
		reghdfe `spread_var' `controls' if institutional_term_loan ==1 | rev_loan ==1, absorb(borrowerid_rev_loan_quarter, savefe) keepsingletons
		rename __hdfe1__ fe_coeff
		*Need to spread the fe_coeff by
		gen fe_coeff_term = fe_coeff if rev_loan==0
		gen fe_coeff_rev = fe_coeff if rev_loan ==1
		egen fe_coeff_term_sp = max(fe_coeff_term), by(borrowercompanyid date_quarterly)
		egen fe_coeff_rev_sp = max(fe_coeff_rev), by(borrowercompanyid date_quarterly)
		gen discount_`spread_suffix'_`discount_type' = fe_coeff_term_sp - fe_coeff_rev_sp
		*Don't want this to be populated for other loans
		replace discount_`spread_suffix'_`discount_type' = . if other_loan ==1
		replace discount_`spread_suffix'_`discount_type' = . if term_loan ==1 & institutional_term_loan==0
		*Want the "discount" to be the negative amount if it is a term loan because I want it then to "term-revolver"
		replace discount_`spread_suffix'_`discount_type' = -discount_`spread_suffix'_`discount_type' if term_loan ==1

		drop fe_coeff*
	}
}
sort borrowercompanyid date_quarterly rev_loan facilityid
/*
br borrowercompanyid date_quarterly packageid facilityid rev_loan discount* ///
 allindrawn spread spread_2
*/
isid facilityid
*Merge on cusip_6
merge m:1 borrowercompanyid date_quarterly using "$data_path/stata_temp/compustat_with_bcid", keep(1 3) keepusing(cusip_6) nogen
*Now I only want to keep the borrowercompanyid and discounts
keep if rev_loan ==1
keep borrowercompanyid discount* date_quarterly
duplicates drop
isid borrowercompanyid date_quarterly
save "$data_path/stata_temp/dealscan_discounts_no_noninstitutional_term", replace

use "$data_path/stata_temp/dealscan_discounts", clear
sum  discount_1_simple 
use "$data_path/stata_temp/dealscan_discounts_no_noninstitutional_term", clear
hist discount_1_simple
*Make the line graph again
collapse (mean) discount_* , by(date_quarterly)
		tw  ///
		(line discount* date_quarterly, ///
			legend(order(1 "1 (Simple)" 2 "1 (Controls)" 3 "2 (Simple)"  4 "2 (Controls)"))) ///
			, title("Discounts Over Time - `title_add'")  ytitle("`measure' Discount (bps) `measure_desc'") 

*Look at joint distribution of discounts and and rates

use "$data_path/dealscan_compustat_loan_level", clear
keep if (category =="Revolver" | category == "Bank Term")  & !mi(cusip_6) & !mi(discount_1_simple)
tddens spread discount_1_simple if category == "Revolver"

*Look at whether a loan has a previous same lender and then look at the discount
use "$data_path/dealscan_compustat_lender_loan_level", clear
isid facilityid lender
gen prev_lender = 0
drop if mi(borrowercompanyid)
*Can either use borrowercompanyid (which will give me all of DS) or use cusip_6, which will give me only merged compustat
*Say you were a previous lender if you were the same lender to the same firm earlier
*Or if you were previoulsy a previous lender
bys borrowercompanyid lender (date_quarterly facilityid): replace prev_lender = 1 if lender[_n] == lender[_n-1] & date_quarterly[_n] != date_quarterly[_n-1]
bys borrowercompanyid lender (date_quarterly facilityid): replace prev_lender = 1 if prev_lender[_n-1] == 1
sort borrowercompanyid lender date_quarterly facilityid
br borrowercompanyid lender date_quarterly facilityid prev_lender
egen max_prev_lender = max(prev_lender), by(facilityid)
keep if category == "Revolver"
keep facilityid borrowercompanyid max_prev_lender discount* date_quarterly
duplicates drop
reg discount_1_simple max_prev_lender if date_quarterly >=tq(2005q1), absorb(date_quarterly) 
reghdfe discount_1_simple max_prev_lender if date_quarterly >=tq(2005q1), absorb(date_quarterly borrowercompanyid) 
preserve
collapse (mean) max_prev_lender, by(date_quarterly)
twoway line max_prev_lender date_quarterly
restore
preserve
collapse (mean) discount_1_simple, by(date_quarterly max_prev_lender)
twoway (line discount_1_simple date_quarterly if max_prev_lender ==1, color(black)) ///
	(line discount_1_simple date_quarterly if max_prev_lender ==0, color(blue))
restore
preserve
gen year = yofd(dofq(date_quarterly))
collapse (mean) discount_1_simple, by(year max_prev_lender)
twoway (line discount_1_simple year if max_prev_lender ==1, color(black)) ///
	(line discount_1_simple year if max_prev_lender ==0, color(blue))
restore
	
*Try calculating discount with fake data - This fake data is perfect and the "base discount" doesn't vary within the same borrowerid_rev_loan_quarter
import excel "$input_data/fake_data_discount_works_perfectly.xlsx", sheet("Sheet1") firstrow clear
rename spread_no_noise spread
rename spread_w_noise spread_2
egen borrowerid_rev_loan_quarter = group(borrowercompanyid date_quarterly category)
*Loop over different measures of the discount
foreach spread_type in standard alternate {
	if "`spread_type'" == "standard" {
		local spread_var spread
		local spread_suffix 1
	}
	if "`spread_type'" == "alternate" {
		local spread_var spread_2
		local spread_suffix 2
	}
	
	foreach discount_type in simple controls {
	
		if "`discount_type'" == "simple" {
			local controls 
		}
		if "`discount_type'" == "controls" {
			local controls log_facilityamt maturity cov cov_lite asset_based senior
		}
		*Only want term and rev_loan obs in the regression
		reghdfe `spread_var' `controls', absorb(borrowerid_rev_loan_quarter, savefe) keepsingletons
		rename __hdfe1__ fe_coeff
		*Need to spread the fe_coeff by
		gen fe_coeff_term_ins = fe_coeff if category == "Inst. Term"
		gen fe_coeff_term_bank = fe_coeff if category == "Bank Term"
		gen fe_coeff_rev = fe_coeff if category == "Revolver"
		egen fe_coeff_term_ins_sp = max(fe_coeff_term_ins), by(borrowercompanyid date_quarterly)
		egen fe_coeff_term_bank_sp = max(fe_coeff_term_bank), by(borrowercompanyid date_quarterly)
		egen fe_coeff_rev_sp = max(fe_coeff_rev), by(borrowercompanyid date_quarterly)
		gen discount_`spread_suffix'_`discount_type' = fe_coeff_term_ins_sp - fe_coeff_rev_sp if category == "Revolver"
		replace discount_`spread_suffix'_`discount_type' = fe_coeff_term_ins_sp - fe_coeff_term_bank_sp if category == "Bank Term"
		*Don't want this to be populated for other loans or institutional term loans
		replace discount_`spread_suffix'_`discount_type' = . if category == "Inst. Term"

		drop fe_coeff*
	}
}

*Try calculating discount with fake data - This fake data is not and the "base spread" varies within the same borrowerid_rev_loan_quarter
*Note this doesn't work - estimates sometimes are close to the truth, but it depends on the direction that the "base spread" moves along with
*Things that are being identified.
import excel "$input_data/fake_data_discount_doesnt_work_perfectly.xlsx", sheet("Sheet1") firstrow clear
rename spread_no_noise spread
rename spread_w_noise spread_2
egen borrowerid_rev_loan_quarter = group(borrowercompanyid date_quarterly category)
*Loop over different measures of the discount
foreach spread_type in standard alternate {
	if "`spread_type'" == "standard" {
		local spread_var spread
		local spread_suffix 1
	}
	if "`spread_type'" == "alternate" {
		local spread_var spread_2
		local spread_suffix 2
	}
	
	foreach discount_type in simple controls {
	
		if "`discount_type'" == "simple" {
			local controls 
		}
		if "`discount_type'" == "controls" {
			local controls log_facilityamt maturity cov cov_lite asset_based senior
		}
		*Only want term and rev_loan obs in the regression
		reghdfe `spread_var' `controls', absorb(borrowerid_rev_loan_quarter, savefe) keepsingletons
		rename __hdfe1__ fe_coeff
		*Need to spread the fe_coeff by
		gen fe_coeff_term_ins = fe_coeff if category == "Inst. Term"
		gen fe_coeff_term_bank = fe_coeff if category == "Bank Term"
		gen fe_coeff_rev = fe_coeff if category == "Revolver"
		egen fe_coeff_term_ins_sp = max(fe_coeff_term_ins), by(borrowercompanyid date_quarterly)
		egen fe_coeff_term_bank_sp = max(fe_coeff_term_bank), by(borrowercompanyid date_quarterly)
		egen fe_coeff_rev_sp = max(fe_coeff_rev), by(borrowercompanyid date_quarterly)
		gen discount_`spread_suffix'_`discount_type' = fe_coeff_term_ins_sp - fe_coeff_rev_sp if category == "Revolver"
		replace discount_`spread_suffix'_`discount_type' = fe_coeff_term_ins_sp - fe_coeff_term_bank_sp if category == "Bank Term"
		*Don't want this to be populated for other loans or institutional term loans
		replace discount_`spread_suffix'_`discount_type' = . if category == "Inst. Term"

		drop fe_coeff*
	}
}



*
*Get the facility level data
use "$data_path/dealscan_facility_level", clear

*I will make four categories of loans: revolvers (relationship loans), non-institutional term loans (relationship loans)
*institional term loans (market loans) and other loans (not considering)

*The difference between revolving and institutional and non-institutional term and instittuional term loanwill give me the "discount
gen category = ""
replace category = "Revolver" if rev_loan ==1
replace category = "Inst. Term" if term_loan ==1 & institutional ==1
replace category = "Bank Term" if term_loan ==1 & institutional ==0
replace category = "Other" if other_loan==1
assert !mi(category)

local loan_level_controls log_facilityamt maturity cov cov_lite asset_based senior secured

sort borrowercompanyid date_quarterly category facilityid

*For each variable that could vary within loan package (borrowercompanyid date_quarterly), get the average by category
foreach var in spread spread_2 `loan_level_controls' {
	egen m_`var' = mean(`var'), by(borrowercompanyid date_quarterly category)
	gen m_`var'_inst_t = m_`var' if category == "Inst. Term"
	egen m_`var'_inst = max(m_`var'_inst_t), by(borrowercompanyid date_quarterly)
	gen diff_`var' = m_`var'_inst-m_`var' if category == "Revolver" | category == "Bank Term"
	drop m_`var'*
	local var_label: variable label `var'
	label var diff_`var' "D-`var_label'"
}

*Now rename the simple discounts
rename diff_spread discount_1_simple
rename diff_spread_2 discount_2_simple

sum discount_1_simple, detail
sum discount_2_simple, detail

*Calculate the discount, residualized for loan level controls
foreach disc in discount_1 discount_2 {
	*Regress discount on loan characteristics
	reg `disc'_simple diff_*
	predict `disc'_controls, residual
	*Don't want to take out the constant so the level is interpretable
	replace `disc'_controls =  `disc'_controls + _b[_cons]
}

*label discount
label var discount_1_simple "Di-1-S"
label var discount_2_simple "Di-2-S"
label var discount_1_controls "Di-1-C"
label var discount_2_controls "Di-2-C"


*Loop over different measures of the discount
foreach spread_type in standard alternate {
	if "`spread_type'" == "standard" {
		local spread_var spread
		local spread_suffix 1
	}
	if "`spread_type'" == "alternate" {
		local spread_var spread_2
		local spread_suffix 2
	}
	
	foreach discount_type in simple controls {
	
		if "`discount_type'" == "simple" {
			local controls 
		}
		if "`discount_type'" == "controls" {
			local controls `loan_level_controls'
		}
		*Only want term and rev_loan obs in the regression
		reghdfe `spread_var' `controls' if term_loan ==1 | rev_loan ==1, absorb(borrowerid_rev_loan_quarter, savefe) keepsingletons
		rename __hdfe1__ fe_coeff
		*Need to spread the fe_coeff by
		gen fe_coeff_term_ins = fe_coeff if category == "Inst. Term"
		gen fe_coeff_term_bank = fe_coeff if category == "Bank Term"
		gen fe_coeff_rev = fe_coeff if category == "Revolver"
		egen fe_coeff_term_ins_sp = max(fe_coeff_term_ins), by(borrowercompanyid date_quarterly)
		egen fe_coeff_term_bank_sp = max(fe_coeff_term_bank), by(borrowercompanyid date_quarterly)
		egen fe_coeff_rev_sp = max(fe_coeff_rev), by(borrowercompanyid date_quarterly)
		gen discount_`spread_suffix'_`discount_type' = fe_coeff_term_ins_sp - fe_coeff_rev_sp if category == "Revolver"
		replace discount_`spread_suffix'_`discount_type' = fe_coeff_term_ins_sp - fe_coeff_term_bank_sp if category == "Bank Term"
		*Don't want this to be populated for other loans or institutional term loans
		replace discount_`spread_suffix'_`discount_type' = . if other_loan ==1 | category == "Inst. Term"

		drop fe_coeff*
		*Make buckets for discount
		gen d_`spread_suffix'_`discount_type'_le_0 = (discount_`spread_suffix'_`discount_type'<-10e-9) 
		gen d_`spread_suffix'_`discount_type'_0 = (discount_`spread_suffix'_`discount_type'>=-10e-9 & discount_`spread_suffix'_`discount_type' <=10e-9) 
		gen d_`spread_suffix'_`discount_type'_0_25 = (discount_`spread_suffix'_`discount_type'>=10e-9 & discount_`spread_suffix'_`discount_type' <=25+10e-9) 
		gen d_`spread_suffix'_`discount_type'_25_50 = (discount_`spread_suffix'_`discount_type'>=25+10e-9 & discount_`spread_suffix'_`discount_type' <=50+10e-9) 
		gen d_`spread_suffix'_`discount_type'_50_100 = (discount_`spread_suffix'_`discount_type'>=50+10e-9 & discount_`spread_suffix'_`discount_type' <=100+10e-9) 
		gen d_`spread_suffix'_`discount_type'_100_200 = (discount_`spread_suffix'_`discount_type'>=100+10e-9 & discount_`spread_suffix'_`discount_type' <=200+10e-9) 
		gen d_`spread_suffix'_`discount_type'_ge_200 = (discount_`spread_suffix'_`discount_type'>=200+10e-9)
		
		foreach var of varlist d_`spread_suffix'_`discount_type'_* {
			replace `var' = . if mi(discount_`spread_suffix'_`discount_type')
		}
	}
}

isid facilityid
*Merge on cusip_6
merge m:1 borrowercompanyid date_quarterly using "$data_path/stata_temp/compustat_with_bcid", keep(1 3) keepusing(cusip_6) nogen
save "$data_path/stata_temp/dealscan_discounts_facilityid", replace
*This dataset will contain all of the discoutn information but cannot be merged onto a quarterly panel - would require some adjustment.
foreach var in discount_1_simple discount_1_controls discount_2_simple discount_2_controls {
	gen temp_term_disc = `var' if category == "Bank Term" 
	egen temp_term_disc_sp = max(temp_term_disc), by(borrowercompanyid date_quarterly)
	gen temp_rev_disc = `var' if category == "Revolver" 
	egen temp_rev_disc_sp = max(temp_rev_disc), by(borrowercompanyid date_quarterly)
	*Drop the revolving discount and then recreate it so it is populated for all loans in the quarter x firm
	drop `var'
	*Create the term_discount, which will exist 
	gen term_`var' = temp_term_disc_sp
	gen rev_`var' = temp_rev_disc_sp
	drop temp*
	
}
keep borrowercompanyid rev_discount* term_discount_* date_quarterly
duplicates drop
isid borrowercompanyid date_quarterly 
save "$data_path/stata_temp/dealscan_discounts", replace

*Explore who is matched to compustat and who isn't
use "$data_path/dealscan_compustat_loan_level", clear
sort company borrowercompanyid date_quarterly
br borrowercompanyid company  merge_compustat publicprivate date_quarterly gvkey discount_1_simple  if !mi(discount_1_simple)
br borrowercompanyid company  merge_compustat publicprivate date_quarterly gvkey if borrowercompanyid == 113895 | borrowercompanyid == 35357

use "$data_path/compustat_clean", clear
br conm gvkey date_quarterly borrowercompanyid if  gvkey == 9899
sort gvkey date_quarterly

*Figure out how the prev_lender and switcher are identified - explore more
use "$data_path/stata_temp/dealscan_discount_prev_lender", clear
gen constant = 1
egen max_first_loan = max(first_loan) if date_quarterly>=tq(2005q1), by(borrowercompanyid)
egen max_prev_lender = max(prev_lender) if date_quarterly>=tq(2005q1), by(borrowercompanyid)
egen max_switcher_loan = max(switcher_loan) if date_quarterly>=tq(2005q1), by(borrowercompanyid)
gen obs_types = max_first_loan + max_prev_lend + max_switcher_loan
gen mult_obs = (obs_types) >=2 & !mi(max_first_loan)
gen all_types = (obs_types) ==3 & !mi(max_first_loan)
qui reghdfe discount_1_simple prev_lender switcher_loan if date_quarterly >=tq(2005q1) , a(borrowercompanyid date_quarterly) vce(cl borrowercompanyid)
gen sample_keep = e(sample)

reghdfe discount_1_simple prev_lender switcher_loan if date_quarterly >=tq(2005q1) , a(date_quarterly) vce(cl borrowercompanyid)
reghdfe discount_1_simple prev_lender switcher_loan if date_quarterly >=tq(2005q1) &sample_keep==1, a(date_quarterly) vce(cl borrowercompanyid)
reghdfe discount_1_simple prev_lender switcher_loan if date_quarterly >=tq(2005q1) &mult_obs==1 &sample_keep==1, a(date_quarterly) vce(cl borrowercompanyid)
reghdfe discount_1_simple prev_lender switcher_loan if date_quarterly >=tq(2005q1) &max_prev_lender==1 &max_switcher_loan==1 &sample_keep==1, a(date_quarterly) vce(cl borrowercompanyid)
reghdfe discount_1_simple prev_lender switcher_loan if date_quarterly >=tq(2005q1) , a(borrowercompanyid date_quarterly) vce(cl borrowercompanyid)

reghdfe discount_1_simple prev_lender switcher_loan if date_quarterly >=tq(2005q1) &max_first_loan ==1, a(date_quarterly) vce(cl borrowercompanyid)
reghdfe discount_1_simple prev_lender switcher_loan if date_quarterly >=tq(2005q1) &max_first_loan ==1, a(borrowercompanyid date_quarterly) vce(cl borrowercompanyid)


reghdfe discount_1_simple prev_lender switcher_loan if date_quarterly >=tq(2005q1) &sample_keep==1, a(date_quarterly) vce(cl borrowercompanyid)


reghdfe discount_1_simple prev_lender switcher_loan if date_quarterly >=tq(2005q1) &all_types==1 , a(borrowercompanyid date_quarterly) vce(cl borrowercompanyid)
reghdfe discount_1_simple prev_lender switcher_loan if date_quarterly >=tq(2005q1) &all_types==1, a(date_quarterly) vce(cl borrowercompanyid)


reghdfe discount_1_simple prev_lender switcher_loan if date_quarterly >=tq(2005q1) &max_first_loan ==1, a(date_quarterly) vce(cl borrowercompanyid)
reghdfe discount_1_simple prev_lender switcher_loan if date_quarterly >=tq(2005q1) &max_first_loan ==1, a(date_quarterly borrowercompanyid) vce(cl borrowercompanyid)

br borrowercompanyid facilityid date_quarterly first_loan prev_lender switcher_loan ///
	max_first_loan max_prev_lender max_switcher_loan obs_types mult_obs ///
	  sample_keep discount_1_simple if !mi(discount_1_simple) & date_quarterly >=tq(2005q1)

*Make the nice regression table to decompose
use "$data_path/dealscan_compustat_loan_level", clear
keep if rev_loan ==1
egen max_first_loan = max(first_loan), by(borrowercompanyid)
egen max_prev_lender = max(prev_lender), by(borrowercompanyid)
egen max_switcher_loan = max(switcher_loan) , by(borrowercompanyid)
gen obs_types = max_first_loan + max_prev_lend + max_switcher_loan
gen mult_obs = (obs_types) >=2 & !mi(max_first_loan)
gen all_types = (obs_types) ==3 & !mi(max_first_loan)
qui reghdfe discount_1_simple prev_lender switcher_loan , a(borrowercompanyid date_quarterly) vce(cl borrowercompanyid)
gen sample_keep = e(sample)

estimates clear
local i =1

local lhs discount_1_simple
*Try to decompose why firm FE changes result of switchers
*First start with simplest regression, only time FE
reghdfe `lhs' no_prev_lender , a(date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Time"
estadd local disc = "All Disc"
estadd local sample = "All"
estimates store est`i'
local ++i
*Keep only sample from FE regression
reghdfe `lhs' no_prev_lender if sample_keep==1, a(date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Time"
estadd local disc = "All Disc"
estadd local sample = "FE Reg Obs"
estimates store est`i'
local ++i

*Keep only observations that can identify coefficients
reghdfe `lhs' no_prev_lender if mult_obs==1 &sample_keep==1, a(date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Time"
estadd local disc = "All Disc"
estadd local sample = "Coeff Identifying Obs"
estimates store est`i'
local ++i

*The FE regression without time FE
reghdfe `lhs' no_prev_lender , a(borrowercompanyid) vce(cl borrowercompanyid)
estadd local fe = "Firm"
estadd local disc = "All Disc"
estadd local sample = "FE Reg Obs"
estimates store est`i'
local ++i

*The FE regression
reghdfe `lhs' no_prev_lender , a(borrowercompanyid date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Firm, Time"
estadd local disc = "All Disc"
estadd local sample = "FE Reg Obs"
estimates store est`i'
local ++i

esttab est* using "$regression_output_path/discount_prev_lend_`lhs'_rev_decomposition_slides.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
title("Discounts and Previous Lenders") scalars("fe Fixed Effects" "disc Discount" "sample Sample") ///
addnotes("SEs clustered at firm level")	

*
*Make the nice regression table to decompose for term loans
use "$data_path/dealscan_compustat_loan_level", clear
/*
keep term_loan discount_1_simple prev_lender switcher_loan borrowercompanyid date_quarterly ///
	first_loan prev_lender switcher_loan no_prev_lender
duplicates drop
*/
keep if ~mi(discount_1_simple)
keep if term_loan ==1
egen max_no_prev_lender = max(no_prev_lender), by(borrowercompanyid)
egen max_prev_lender = max(prev_lender), by(borrowercompanyid)
gen obs_types = max_prev_lend + max_no_prev_lend
gen mult_obs = (obs_types) >=2 & !mi(max_no_prev_lender)
qui reghdfe discount_1_simple prev_lender switcher_loan , a(borrowercompanyid date_quarterly) vce(cl borrowercompanyid)
gen sample_keep = e(sample)

*Create an indicator for the first discount within a no_prev_lender category in a firm
bys borrowercompanyid no_prev_lender (date_daily): gen first_discount_of_type = (_n==1)

estimates clear
local i =1

local lhs discount_1_simple
*Try to decompose why firm FE changes result of switchers
*First start with simplest regression, only time FE
reghdfe `lhs' no_prev_lender , a(date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Time"
estadd local disc = "All Disc"
estadd local sample = "All"
estimates store est`i'
local ++i
*Keep only sample from FE regression
reghdfe `lhs' no_prev_lender if sample_keep==1, a(date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Time"
estadd local disc = "All Disc"
estadd local sample = "FE Reg Obs"
estimates store est`i'
local ++i

*Keep only observations that can identify coefficients
reghdfe `lhs' no_prev_lender if mult_obs==1 &sample_keep==1, a(date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Time"
estadd local disc = "All Disc"
estadd local sample = "Coeff Identifying Obs"
estimates store est`i'
local ++i

*Keep only first of each type observation that can identify coefficients
reghdfe `lhs' no_prev_lender if mult_obs==1 &sample_keep==1 & first_discount_of_type==1, a(date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Time"
estadd local disc = "All Disc"
estadd local sample = "Coeff Identifying Obs,First"
estimates store est`i'
local ++i



*The FE regression without time FE
reghdfe `lhs' no_prev_lender , a(borrowercompanyid) vce(cl borrowercompanyid)
estadd local fe = "Firm"
estadd local disc = "All Disc"
estadd local sample = "FE Reg Obs"
estimates store est`i'
local ++i

*The FE regression
reghdfe `lhs' no_prev_lender , a(borrowercompanyid date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Firm, Time"
estadd local disc = "All Disc"
estadd local sample = "FE Reg Obs"
estimates store est`i'
local ++i

esttab est* using "$regression_output_path/discount_prev_lend_`lhs'_term_decomposition_slides.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
title("Discounts and Previous Lenders") scalars("fe Fixed Effects" "disc Discount" "sample Sample") ///
addnotes("SEs clustered at firm level")	

*Try to figure some stuff out with summary stats
*Look at term loan observations that are in the FE sample
*keep if sample_keep==1 & term_loan ==1
br borrowercompanyid date_daily discount_1_simple no_prev_lender max_* if mult_obs==1
br borrowercompanyid date_daily discount_1_simple no_prev_lender max_* if mult_obs==1 & first_discount_of_type==1

sum discount_1_simple if no_prev_lender ==1, detail
sum discount_1_simple if no_prev_lender ==0, detail
sum discount_1_simple if no_prev_lender ==1 &mult_obs==1 &sample_keep==1, detail
sum discount_1_simple if no_prev_lender ==0 &mult_obs==1 &sample_keep==1, detail
sum discount_1_simple if no_prev_lender ==1 &mult_obs==1 &sample_keep==1& first_discount_of_type==1, detail
sum discount_1_simple if no_prev_lender ==0 &mult_obs==1 &sample_keep==1& first_discount_of_type==1, detail

sum discount_1_simple if mult_obs==1, detail
sum discount_1_simple if mult_obs ==0, detail

*Look at mult_obs only, see average discount
preserve
keep if mult_obs==1
collapse (sum) constant (mean) discount_1_simple, by(borrowercompanyid no_prev_lender)

sum discount_1_simple if constant ==1 & no_prev_lender ==1
sum discount_1_simple if constant ==1 & no_prev_lender ==0

sum discount_1_simple if constant ==2 & no_prev_lender ==1
sum discount_1_simple if constant ==2 & no_prev_lender ==0

sum discount_1_simple if constant ==3 & no_prev_lender ==1
sum discount_1_simple if constant ==3 & no_prev_lender ==0

sum discount_1_simple if constant ==4 & no_prev_lender ==1
sum discount_1_simple if constant ==4 & no_prev_lender ==0

*Want a dataset which has borrowercompanyid avg_discount_no_prev avg_discount_prev count_no_prev count_prev
reshape wide discount_1_simple constant, i(borrowercompanyid) j(no_prev_lender)
*Generate difference
gen diff_discount = discount_1_simple1-discount_1_simple0
gen count = constant0 + constant1
corr count diff_discount
restore




*Count the average discount by number of discounts received
use "$data_path/dealscan_compustat_loan_level", clear
drop if mi(borrowercompanyid) 
drop if mi(discount_1_simple)

collapse (sum) constant (mean) discount_1_simple , by(borrowercompanyid rev_loan term_loan)

collapse (mean) discount_1_simple, by(constant rev_loan term_loan)

*See how the nth discount looks by firms that receive N discounts
use "$data_path/dealscan_compustat_loan_level", clear
drop if mi(borrowercompanyid) 
drop if mi(discount_1_simple)

gen discount_number = 1 if no_prev_lender==1
bys borrowercompanyid category (facilitystartdate): replace discount_num = discount_num[_n-1] + 1 if mi(discount_num)


egen total_discounts = count(discount_1_simple), by(borrowercompanyid)
collapse (mean) discount_1_simple, by(discount_number total_discount rev_loan term_loan)
local cond_add "& rev_loan ==1"

twoway (scatter discount_1_simple discount_number if total_discounts ==1 `cond_add', lcolor(blue)) ///
	(line discount_1_simple discount_number if total_discounts ==2 `cond_add', lcolor(red)) ///
	(line discount_1_simple discount_number if total_discounts ==3 `cond_add', lcolor(green)) ///
	(line discount_1_simple discount_number if total_discounts ==4 `cond_add', lcolor(gold)) ///
	(line discount_1_simple discount_number if total_discounts ==5 `cond_add', lcolor(brown)) ///
	(line discount_1_simple discount_number if total_discounts ==6 `cond_add', lcolor(lavender))

*Collapse by state so each observation only has up to 2, see if that fixes it.
use "$data_path/dealscan_compustat_loan_level", clear
drop if mi(borrowercompanyid) 
drop if mi(discount_1_simple)

collapse (sum) constant (mean) discount_1_simple, by(borrowercompanyid rev_loan term_loan no_prev_lender)
gen count =1
local lhs discount_1_simple
reghdfe `lhs' no_prev_lender if rev_loan==1, a(count) vce(cl borrowercompanyid)
reghdfe `lhs' no_prev_lender if rev_loan==1, a(borrowercompanyid) vce(cl borrowercompanyid)
reghdfe `lhs' no_prev_lender if term_loan==1, a(count) vce(cl borrowercompanyid)
reghdfe `lhs' no_prev_lender if term_loan==1, a(borrowercompanyid) vce(cl borrowercompanyid)
gen sample_keep = e(sample)
reghdfe `lhs' no_prev_lender if term_loan==1 &sample_keep==1, a(count) vce(cl borrowercompanyid)
br if term_loan==1 &sample_keep==1
*Keep term_loan discounts and only look at 
	
*Try to understand how interactions and the FE can produce a giant number for compustat sample
use "$data_path/stata_temp/dealscan_discount_prev_lender", clear
gen flag_min_date_quarterly = (USRECM ==1 & date_quarterly == min_date_quarterly & date_quarterly >=tq(2005q1))
egen drop_obs = max(flag_min_date_quarterly), by(borrowercompanyid)
br borrowercompanyid date_quarterly  min_date_quarterly  flag_min_date_quarterly  drop_obs USRECM discount_1_simple first_loan
local extra_cond "&drop_obs==0"
local lhs discount_1_simple
*local sample_cond "& merge_comp ==1"
local rhs prev_lender switcher_loan prev_lender_rec switcher_loan_rec
local fe date_quarterly borrowercompanyid
reghdfe `lhs' `rhs'  if date_quarterly >=tq(2005q1)  `sample_cond' `extra_cond' , a(`fe') vce(cl borrowercompanyid)

br borrowercompanyid date_quarterly  min_date_quarterly  drop_obs USRECM discount_1_simple first_loan if drop_obs ==1 


*Find a nice example of a loan that I can use in the slides
use "$data_path/dealscan_compustat_loan_level", clear
bys packageid date_quarterly: gen num_packages = _N
sort borrowercompanyid packageid date_quarterly facilityid
br conm borrowercompanyid packageid facilityid date_quarterly category loantype merge_compustat discount_1_simple sic_2 ///
if merge_compustat ==1 & (!mi(discount_1_simple) | category== "Inst. Term") & num_packages==3 & date_quarterly >=tq(2013q1)

*Yum Brands 2016Q2 - has one term, n
br conm borrowercompanyid packageid facilityid date_quarterly category loantype merge_compustat discount_1_simple ///
 if packageid == 254937

br conm date_quarterly category loantype ///
 spread facilityamt maturity cov cov_lite asset_based senior secured if packageid == 254937 & date_quarterly == tq(2016q2)

*Find lenders
use "$data_path/dealscan_compustat_lender_loan_level", clear
br conm date_quarterly facilityid lender lenderrole bankallocation lead_arranger_credit agent_credit ///
	if (facilityid == 360935 | facilityid == 360936 | facilityid == 360937) & date_quarterly == tq(2016q2) & lead_arranger_credit ==1
br if (facilityid == 360935 | facilityid == 360936 | facilityid == 360937) & date_quarterly == tq(2016q2) 

*Check Boyd gaming
use "$data_path/dealscan_compustat_lender_loan_level", clear
br conm date_quarterly facilityid lender lenderrole bankallocation lead_arranger_credit agent_credit ///
	if (facilityid == 365049) & lead_arranger_credit ==1



*Avis Budge packageid == 234741 - negative discount

*Lannett co inc 
br conm borrowercompanyid packageid facilityid date_quarterly category loantype merge_compustat discount_1_simple ///
 if packageid == 245911
 
br conm date_quarterly category loantype ///
 facilityamt maturity cov cov_lite asset_based senior secured if packageid == 245911 & date_quarterly == tq(2015q4)

*Try to see if the term pos discount indicator matters if I don't include the revolving characteristics
*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

use "$data_path/sdc_deals_with_past_relationships_20", clear
append using "$data_path/ds_lending_with_past_relationships_20"

egen sdc_obs = rowmax(equity_base debt_base conv_base)
egen ds_obs = rowmax(rev_loan_base term_loan_base other_loan_base)
*Date quarterly
gen date_quarterly = qofd(date_daily)
format date_quarterly %tq

local rhs rel_*  i_d_1_simple_pos* mi_d_1_simple_pos* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* 
local cond "if ds_obs==1" 
local absorb constant
reghdfe hire `rhs' `cond', absorb(`absorb') vce(cl cusip_6)

local rhs rel_*  i_d_1_simple_pos*term mi_d_1_simple_pos*term i_maturity_*term i_log_facilityamt_*term i_spread_*term mi_spread_*term 
local cond "if ds_obs==1" 
local absorb constant
reghdfe hire `rhs' `cond', absorb(`absorb') vce(cl cusip_6)

local rhs rel_*  i_d_1_simple_pos* mi_d_1_simple_pos*
local cond "if ds_obs==1" 
local absorb constant
reghdfe hire `rhs' `cond', absorb(`absorb') vce(cl cusip_6)

*See if non senior/ non secured (inst. term) loans are the ones that end up producing giant discounts
use "$data_path/dealscan_compustat_loan_level", clear
sum discount_1_simple, detail
sum discount_1_simple if diff_cov==1, detail
sum discount_1_simple if diff_cov_lite==-1, detail
sum discount_1_simple if diff_asset_based==1, detail
sum discount_1_simple if diff_senior==-1, detail
sum discount_1_simple if diff_secured==-1, detail

tab diff_cov
tab diff_cov_lite
tab diff_asset_based
tab diff_senior
tab diff_secured


*Past lender and future pricing - Only compustat firms - comparing bond market vs no bond market
preserve
	use "$data_path/stata_temp/dealscan_discount_prev_lender", clear
	keep if merge_compustat ==1
	foreach lhs in  discount_1_simple discount_1_controls {

		label var discount_1_simple "Disc"		
		estimates clear
		local i =1
			
		*Regression 1 Regress discount on constant and
		reg `lhs' merge_ratings if date_quarterly >=tq(2005q1) , vce(cl borrowercompanyid)
		estadd local fe = "None"
		estadd local disc = "All"
		estadd local sample = "Compustat"
		estimates store est`i'
		local ++i
		/*
		*Regression 3 - Add pooled  prev_rel (Time FE)
		reghdfe `lhs' prev_lender if date_quarterly >=tq(2005q1) , a(date_quarterly) vce(cl borrowercompanyid)
		estadd local fe = "Time"
		estadd local disc = "All"
		estadd local sample = "Compustat"
		estimates store est`i'
		local ++i
		*Regression 4 - Add interaction to prev_rel (Time FE)
		reghdfe `lhs' prev_lender merge_ratings prev_merge_ratings if date_quarterly >=tq(2005q1) , a(date_quarterly) vce(cl borrowercompanyid)
		estadd local fe = "Time"
		estadd local disc = "All"
		estadd local sample = "Compustat"
		estimates store est`i'
		local ++i
		*/
		*Regression 5 - Add pooled prev_rel and switcher_loan (Time FE)
		reghdfe `lhs' prev_lender switcher_loan if date_quarterly >=tq(2005q1) , a(date_quarterly) vce(cl borrowercompanyid)
		estadd local fe = "Time"
		estadd local disc = "All"
		estadd local sample = "Compustat"
		estimates store est`i'
		local ++i
		*Regression 6 - Add interaction to prev_rel and switcher (Time FE)
		reghdfe `lhs' merge_ratings  prev_merge_compustat_no_ratings switc_merge_compustat_no_ratings ///
		prev_merge_ratings switc_merge_ratings if date_quarterly >=tq(2005q1) , a(date_quarterly) vce(cl borrowercompanyid)
		estadd local fe = "Time"
		estadd local disc = "All"
		estadd local sample = "Compustat"
		estimates store est`i'
		local ++i

		esttab est* using "$regression_output_path/discount_prev_lend_`lhs'_all_comp_rating_cat_slides.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
		title("Discounts and Previous Lenders") scalars("fe Fixed Effects" "disc Discount" "sample Sample") ///
		addnotes("SEs clustered at firm level" "Sample are all dealscan discounts from 2005Q1-2020Q4" "Dropping 2001Q1-2004Q4 as burnout period")	
	}

restore

*Past lender and future pricing - all three categories
preserve
	use "$data_path/stata_temp/dealscan_discount_prev_lender", clear
	gen constant = 1
	foreach lhs in  discount_1_simple discount_1_controls {

		label var discount_1_simple "Disc"		
		estimates clear
		local i =1
			
		*Regression 1 Regress discount on constant and
		reghdfe `lhs' merge_compustat_no_ratings merge_ratings if date_quarterly >=tq(2005q1), absorb(constant) nocons  vce(cl borrowercompanyid)
		estadd local fe = "None"
		estadd local disc = "All"
		estadd local sample = "All"
		estimates store est`i'
		local ++i
		/*
		*Regression 2 - Add Firm and Time FE
		reghdfe `lhs' merge_compustat_no_ratings merge_ratings if date_quarterly >=tq(2005q1) , a(date_quarterly borrowercompanyid) vce(cl borrowercompanyid)
		estadd local fe = "Time,Firm"
		estadd local disc = "All"
		estadd local sample = "All"
		estimates store est`i'
		local ++i
		*Regression 3 - Add pooled  prev_rel (Time FE)
		reghdfe `lhs' prev_lender if date_quarterly >=tq(2005q1) , a(date_quarterly) vce(cl borrowercompanyid)
		estadd local fe = "Time"
		estadd local disc = "All"
		estadd local sample = "All"
		estimates store est`i'
		local ++i
		*Regression 4 - Add interaction to prev_rel (Time FE)
		reghdfe `lhs' merge_compustat_no_ratings merge_ratings prev_no_merge_compustat prev_merge_compustat_no_ratings prev_merge_ratings if date_quarterly >=tq(2005q1) , a(date_quarterly) vce(cl borrowercompanyid)
		estadd local fe = "Time"
		estadd local disc = "All"
		estadd local sample = "All"
		estimates store est`i'
		local ++i
		*/
		*Regression 5 - Add pooled prev_rel and switcher_loan (Time FE)
		reghdfe `lhs' prev_lender switcher_loan if date_quarterly >=tq(2005q1) , a(date_quarterly) vce(cl borrowercompanyid)
		estadd local fe = "Time"
		estadd local disc = "All"
		estadd local sample = "All"
		estimates store est`i'
		local ++i
		*Regression 6 - Add interaction to prev_rel and switcher (Time FE)
		reghdfe `lhs' prev_no_merge_compustat switc_no_merge_compustat ///
		merge_compustat_no_ratings merge_ratings prev_merge_compustat_no_ratings switc_merge_compustat_no_ratings prev_merge_ratings ///
		  switc_merge_ratings if date_quarterly >=tq(2005q1) , a(date_quarterly) vce(cl borrowercompanyid)
		estadd local fe = "Time"
		estadd local disc = "All"
		estadd local sample = "All"
		estimates store est`i'
		local ++i

		esttab est* using "$regression_output_path/discount_prev_lend_`lhs'_all_rating_cat_slides.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
		title("Discounts and Previous Lenders") scalars("fe Fixed Effects" "disc Discount" "sample Sample") ///
		addnotes("SEs clustered at firm level" "Sample are all dealscan discounts from 2005Q1-2020Q4" "Dropping 2001Q1-2004Q4 as burnout period")	
	}

restore

*What if I try to do this same analysis with firm FE
*Past lender and future pricing - all three categories
preserve
	use "$data_path/stata_temp/dealscan_discount_prev_lender", clear
	gen constant = 1
	foreach lhs in  discount_1_simple discount_1_controls {

		label var discount_1_simple "Disc"		
		estimates clear
		local i =1
			
		*Regression 1 Regress discount on constant and
		reghdfe `lhs' merge_compustat_no_ratings merge_ratings if date_quarterly >=tq(2005q1), absorb(constant) nocons  vce(cl borrowercompanyid)
		estadd local fe = "None"
		estadd local disc = "All"
		estadd local sample = "All"
		estimates store est`i'
		local ++i

		*Regression 5 - Add pooled prev_rel and switcher_loan (Time FE)
		reghdfe `lhs' prev_lender switcher_loan if date_quarterly >=tq(2005q1) , a(date_quarterly) vce(cl borrowercompanyid)
		estadd local fe = "Time"
		estadd local disc = "All"
		estadd local sample = "All"
		estimates store est`i'
		local ++i
		*Regression 6 - Add interaction to prev_rel and switcher (Time FE)
		reghdfe `lhs' prev_no_merge_compustat switc_no_merge_compustat ///
		merge_compustat_no_ratings merge_ratings prev_merge_compustat_no_ratings switc_merge_compustat_no_ratings prev_merge_ratings ///
		  switc_merge_ratings if date_quarterly >=tq(2005q1) , a(date_quarterly) vce(cl borrowercompanyid)
		estadd local fe = "Time"
		estadd local disc = "All"
		estadd local sample = "All"
		estimates store est`i'
		local ++i
		
		*Regression 5 - Add pooled prev_rel and switcher_loan (Time FE)
		reghdfe `lhs' prev_lender switcher_loan if date_quarterly >=tq(2005q1) , a(borrowercompanyid date_quarterly) vce(cl borrowercompanyid)
		estadd local fe = "Time"
		estadd local disc = "All"
		estadd local sample = "All"
		estimates store est`i'
		local ++i
		*Regression 6 - Add interaction to prev_rel and switcher (Time FE)
		reghdfe `lhs' prev_no_merge_compustat switc_no_merge_compustat ///
		merge_compustat_no_ratings merge_ratings prev_merge_compustat_no_ratings switc_merge_compustat_no_ratings prev_merge_ratings ///
		  switc_merge_ratings if date_quarterly >=tq(2005q1) , a(borrowercompanyid date_quarterly) vce(cl borrowercompanyid)
		estadd local fe = "Time"
		estadd local disc = "All"
		estadd local sample = "All"
		estimates store est`i'
		local ++i		

		esttab est* using "$regression_output_path/discount_prev_lend_`lhs'_all_rating_cat_ffe_slides.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
		title("Discounts and Previous Lenders") scalars("fe Fixed Effects" "disc Discount" "sample Sample") ///
		addnotes("SEs clustered at firm level" "Sample are all dealscan discounts from 2005Q1-2020Q4" "Dropping 2001Q1-2004Q4 as burnout period")	
	}

restore

*Look at how initial discounts vary across groups
use "$data_path/stata_temp/dealscan_discount_prev_lender", clear
sum discount_1_simple if first_loan ==1 & no_merge_compustat, detail
sum discount_1_simple if first_loan ==1 & merge_compustat_no_ratings, detail
sum discount_1_simple if first_loan ==1 & merge_ratings, detail

sum discount_1_simple if prev_lender ==1 & no_merge_compustat, detail
sum discount_1_simple if prev_lender ==1 & merge_compustat_no_ratings, detail
sum discount_1_simple if prev_lender ==1 & merge_ratings, detail

sum discount_1_simple if switcher_loan ==1 & no_merge_compustat, detail
sum discount_1_simple if switcher_loan ==1 & merge_compustat_no_ratings, detail
sum discount_1_simple if switcher_loan ==1 & merge_ratings, detail


*See how average discount looks across rating
use "$data_path/dealscan_compustat_loan_level", clear
collapse (sum) constant (mean) discount_* , by(rating_numeric)
twoway line discount_1_simple rating_numeric

*Look at refinancings
use "$data_path/dealscan_compustat_loan_level", clear
br borrowercompanyid packageid facilityid category date_quarterly  refinancingindicator discount_1_simple if !mi(discount_1_simple)
sort borrowercompanyid packageid facilityid date_quarterly 

sum discount_1_simple if refinancingindicator =="No"
sum discount_1_simple if refinancingindicator =="Yes"

*Look at CDS data
use "$data_path/cds_spreads_cleaned", clear
isid cusip_6 date_quarterly

*Naive merge
use "$data_path/dealscan_compustat_loan_level", clear
drop if mi(cusip_6)
collapse (mean) 
replace cusip_6 = "-1" if mi(cusip_6)
merge 1:1 cusip_6 date_quarterly using "$data_path/cds_spreads_cleaned"


*Get example for relationship figure
use "$data_path/stata_temp/dealscan_discount_prev_lender", clear
egen max_first_loan = max(first_loan) if date_quarterly>=tq(2005q1), by(borrowercompanyid)
egen max_prev_lender = max(prev_lender) if date_quarterly>=tq(2005q1), by(borrowercompanyid)
egen max_switcher_loan = max(switcher_loan) if date_quarterly>=tq(2005q1), by(borrowercompanyid)
br  borrowercompanyid date_quarterly first_loan prev_lender switcher_loan ///
 if max_first_loan == 1 & max_prev_lender ==1 & max_switcher_loan ==1 & !mi(discount_1_simple) ///
 & merge_compustat==1

use "$data_path/dealscan_compustat_lender_loan_level", clear
*Dyncorp International
br company borrowercompanyid publicprivate facilityid date_quarterly lender merge_compustat if /// 
borrowercompanyid == 3785 &  (date_quarterly==tq(2005q1) | date_quarterly==tq(2006q2) | date_quarterly==tq(2010q3))
*borrowercompanyid == 3785 &  (date_quarterly==tq(2005q1) | date_quarterly==tq(2006q2) | date_quarterly==tq(2010q3))
*borrowercompanyid == 31461 & (date_quarterly==tq(2006q2) | date_quarterly==tq(2011q2) | date_quarterly==tq(2014q3))
*borrowercompanyid == 118826 & (date_quarterly==tq(2007q1) | date_quarterly==tq(2012q1) | date_quarterly==tq(2013q1))

/*
* Run Regressions
*Get the sample of firms that are in the first regression
qui reg cds_spread_mean spreadrev spreadinstitutional 
gen sample_rev = e(sample)
qui reg cds_spread_mean spreadbank spreadinstitutional
gen sample_term = e(sample)

eststo clear

eststo: reg cds_spread_mean spreadrev if sample_rev==1
eststo: reg cds_spread_mean spreadrev spreadinstitutional 
eststo: reg cds_spread_mean spreadbank if sample_term==1 
eststo: reg cds_spread_mean spreadbank spreadinstitutional
*/
*Try to decompose discount
*Correlation tables
use  "$data_path/stata_temp/dealscan_discounts_facilityid", clear
replace category = "Other" if secured == 0 | senior ==0 | asset_based ==1
*Keep only observations that have less than two of each type of discount
gen count = 1
egen count_bank_term_temp = total(count) if category == "Bank Term", by(borrowercompanyid date_quarterly)
egen count_rev_temp = total(count) if category == "Revolver", by(borrowercompanyid date_quarterly)
egen count_inst_term_temp = total(count) if category == "Inst. Term", by(borrowercompanyid date_quarterly)
egen count_bank_term = max(count_bank_term_temp), by(borrowercompanyid date_quarterly)
egen count_rev = max(count_rev_temp), by(borrowercompanyid date_quarterly)
egen count_inst_term = max(count_inst_term_temp), by(borrowercompanyid date_quarterly)


drop if count_bank_term >1 & !mi(count_bank_term)
drop if count_inst_term >1 & !mi(count_inst_term)
drop if count_rev >1 & !mi(count_rev)

foreach var in discount_1_simple discount_1_controls discount_2_simple discount_2_controls {
	gen temp_term_disc = `var' if category == "Bank Term" 
	egen temp_term_disc_sp = max(temp_term_disc), by(borrowercompanyid date_quarterly)
	gen temp_rev_disc = `var' if category == "Revolver" 
	egen temp_rev_disc_sp = max(temp_rev_disc), by(borrowercompanyid date_quarterly)
	*Drop the revolving discount and then recreate it so it is populated for all loans in the quarter x firm
	drop `var'
	*Create the term_discount, which will exist 
	gen term_`var' = temp_term_disc_sp
	gen rev_`var' = temp_rev_disc_sp
	drop temp*
	
}

*Need to spread the bank term, inst term, revolver, and other spread 
gen temp_term_sprd = spread if category == "Bank Term" 
egen term_sprd_sp = max(temp_term_sprd), by(borrowercompanyid date_quarterly)
gen temp_rev_sprd = spread if category == "Revolver" 
egen rev_sprd_sp = max(temp_rev_sprd), by(borrowercompanyid date_quarterly)
gen temp_inst_term_sprd = spread if category == "Inst. Term" 
egen inst_term_sprd_sp = max(temp_inst_term_sprd), by(borrowercompanyid date_quarterly)
gen temp_other_sprd = spread if category == "Other" 
egen other_sprd_sp = max(temp_other_sprd), by(borrowercompanyid date_quarterly)

keep borrowercompanyid rev_discount* term_discount_* *sprd_sp date_quarterly
duplicates drop

		preserve
			freduse USRECM BAMLC0A4CBBB BAMLC0A1CAAA, clear
			rename BAMLC0A4CBBB bbb_spread
			rename BAMLC0A1CAAA aaa_spread
			replace bbb_spread = bbb_spread*100
			replace aaa_spread = aaa_spread*100
			gen date_quarterly = qofd(daten)
			collapse (max) USRECM bbb_spread aaa_spread, by(date_quarterly)
			tsset date_quarterly
			gen L1_aaa_spread = L.aaa_spread
			gen L1_bbb_spread = L.bbb_spread
			gen L2_aaa_spread = L2.aaa_spread
			gen L2_bbb_spread = L2.bbb_spread
			gen L3_aaa_spread = L3.aaa_spread
			gen L3_bbb_spread = L3.bbb_spread
			gen L4_aaa_spread = L4.aaa_spread
			gen L4_bbb_spread = L4.bbb_spread
			keep date_quarterly USRECM *bbb_spread *aaa_spread
			tempfile rec
			save `rec', replace
		restore

		joinby date_quarterly using `rec', unmatched(master)
		
*Here we have a dataset identified by borrowercompanyid date_quarterly 
rename *sprd_sp *sprd

gen diff_rev = inst_term_sprd - rev_sprd
*br if diff_rev != rev_discount_1_simple

gen diff_bank_term = inst_term_sprd - term_sprd
*br if diff_bank_term != term_discount_1_simple

*Indeed it is working as expected
reg diff_rev inst_term_sprd rev_sprd
reg diff_bank_term term_sprd inst_term_sprd

winsor2 diff_rev diff_bank_term, replace cut(1 99)
br if diff_rev != rev_discount_1_simple
	

reg rev_discount_1_simple rev_sprd inst_term_sprd
reg diff_rev inst_term_sprd rev_sprd
reg term_discount_1_simple term_sprd inst_term_sprd
reg diff_bank_term term_sprd inst_term_sprd
reg diff_bank_term term_sprd inst_term_sprd


use "$data_path/dealscan_compustat_loan_level", clear
br if borrowercompanyid == 163 & date_quarterly == tq(2007q1)
br if borrowercompanyid == 45 & date_quarterly == tq(2001q3)
br if borrowercompanyid == 719 & date_quarterly == tq(2011q1)

*Get the aggregate discount series to get discount decomposition
use "$data_path/dealscan_compustat_loan_level", clear
		drop if other_loan ==1
		*Get a sample to keep. Keep if you have an institutional loan and either a rev loan or term loan
		gen inst_term = category== "Inst. Term"
		gen noninst_term = category == "Bank Term"
		egen  rev_loan_max = max(rev_loan), by(borrowercompanyid date_quarterly)
		egen  inst_term_max = max(inst_term), by(borrowercompanyid date_quarterly)
		egen  noninst_term_max = max(noninst_term), by(borrowercompanyid date_quarterly)
		keep if inst_term_max ==1 & (rev_loan_max==1 | noninst_term_max==1)
			
		gen loan_type = "other"
		replace loan_type = "rev" if category == "Revolver"
		replace loan_type = "bank" if category=="Bank Term"
		replace loan_type = "institutional" if category=="Inst. Term"

		*Keep only pe of loan per category
		bys borrowercompanyid date_quarterly category: keep if _n ==1
		drop category
		
		collapse (mean) discount_1_simple spread , by(date_quarterly loan_type)
		reshape wide discount_1_simple spread, i(date_quarterly) j(loan_type) string
		tset date_quarterly
		foreach var in spreadbank spreadinstitutional spreadrev {
			forval i = 1/4 {
				gen L`i'_`var' = L`i'.`var'
			}
		}
		reg discount_1_simplerev spreadrev
		reg discount_1_simplerev spreadrev L1_spreadrev
		reg discount_1_simplerev spreadrev L1_spreadrev L2_spreadrev 
		reg discount_1_simplerev spreadrev L1_spreadrev L2_spreadrev L3_spreadrev 
		reg discount_1_simplerev spreadrev L1_spreadrev L2_spreadrev L3_spreadrev L4_spreadrev
		
		reg discount_1_simplerev spreadinstitutional
		reg discount_1_simplerev spreadinstitutional L1_spreadinstitutional
		reg discount_1_simplerev spreadinstitutional L1_spreadinstitutional L2_spreadinstitutional 
		reg discount_1_simplerev spreadinstitutional L1_spreadinstitutional L2_spreadinstitutional L3_spreadinstitutional 
		reg discount_1_simplerev spreadinstitutional L1_spreadinstitutional L2_spreadinstitutional L3_spreadinstitutional L4_spreadinstitutional

		reg discount_1_simplebank spreadbank
		reg discount_1_simplebank spreadbank L1_spreadbank
		reg discount_1_simplebank spreadbank L1_spreadbank L2_spreadbank 
		reg discount_1_simplebank spreadbank L1_spreadbank L2_spreadbank L3_spreadbank 
		reg discount_1_simplebank spreadbank L1_spreadbank L2_spreadbank L3_spreadbank L4_spreadbank
		
		reg discount_1_simplebank spreadinstitutional
		reg discount_1_simplebank spreadinstitutional L1_spreadinstitutional
		reg discount_1_simplebank spreadinstitutional L1_spreadinstitutional L2_spreadinstitutional 
		reg discount_1_simplebank spreadinstitutional L1_spreadinstitutional L2_spreadinstitutional L3_spreadinstitutional 
		reg discount_1_simplebank spreadinstitutional L1_spreadinstitutional L2_spreadinstitutional L3_spreadinstitutional L4_spreadinstitutional

*Do a variance decomposition
use "$data_path/dealscan_compustat_loan_level", clear
* Collapse data to borrower - date - loantype level
collapse (mean) spread discount_1_simple, by(borrowercompanyid category date_quarterly cusip_6)

gen loan_type = "other"
replace loan_type = "rev" if category == "Revolver"
replace loan_type = "bank" if category=="Bank Term"
replace loan_type = "institutional" if category=="Inst. Term"
keep date_quarterly borrowercompanyid discount_1_simple spread loan_type

* Reshape data so it is identified by borrower - loantype
reshape wide spread discount_1_simple, i(borrowercompanyid date_quarterly) j(loan_type) string

/*
*Roughly: discount = institutional - revolver
take covariance => var(discount) = cov(inst,discount) - cov(rev,discount)
divide by var(discount) => 1 = cov(inst,discount)/var(discount) - cov(rev,discount)/var(discount)
*Can estiamate (1) by regressing inst. spread on discount and
(2) by regressing negative revolving spread on discount
*/
gen neg_spreadrev = -spreadrev 
reg spreadinstitutional discount_1_simplerev
reg neg_spreadrev discount_1_simplerev

gen neg_spreadbank = -spreadbank
reg spreadinstitutional discount_1_simplebank
reg neg_spreadbank discount_1_simplebank


*Want to create a better version of the "discount on loan number" 
*I want the loan number to be 1 if it is labeled as a "no_prev_lender" and then the number number goes up
*until it hits no_prev_lending relationship again.
use "$data_path/stata_temp/dealscan_discount_prev_lender", clear
gen loan_number = 1 if no_prev_lending ==1

*See if we can add charactersitics that don't vary by loan

use "$data_path/dealscan_facility_level", clear
egen borrower_facilitystartdate = group(borrowercompanyid facilitystartdate)
bys borrower_facilitystartdate: egen max_sales = max(salesatclose)
bys borrower_facilitystartdate: egen min_sales = min(salesatclose)
gen temp = max_sales-min_sales
gen public = (publicprivate == "Public")
local loan_level_controls log_facilityamt maturity cov_lite
local extra_controls senior secured fin_cov nw_cov borrower_base
reg spread `loan_level_controls' `extra_controls' , absorb(borrower_facilitystartdate)

*quick analysis about previous and future business.
use "$data_path/sdc_ds_stacked_cleaned_with_rel_measures", clear
keep if date_daily>=td(01jan2001)
bys deal_id: gen weight = 1/_N
*Discount that is correlated with previous business.
corr discount_1_simple duration num_interactions_prev scope_total concentration
corr discount_1_simple duration num_interactions_prev scope_total concentration if rev_loan ==1
corr spread discount_1_simple duration num_interactions_prev scope_total concentration if rev_loan ==1
*Discount that is correlated with future business
corr discount_1_simple num_interactions_fut scope_total_fut scope_loan_fut scope_underwriting_fut ///
scope_loan_underwriting_fut if rev_loan ==1 
corr discount_1_simple num_interactions_fut scope_total_fut scope_loan_fut scope_underwriting_fut ///
scope_loan_underwriting_fut if rev_loan ==1
corr discount_1_simple num_interactions_fut scope_total_fut scope_loan_fut scope_underwriting_fut ///
scope_loan_underwriting_fut if rev_loan ==1
corr spread num_interactions_fut scope_total_fut scope_loan_fut scope_underwriting_fut ///
scope_loan_underwriting_fut if rev_loan ==1

reg discount_1_simple num_interactions_fut 
reg discount_1_simple num_interactions_fut [w=weight]
reg discount_1_simple num_interactions_fut if num_interactions_fut <16

reg discount_1_simple scope_loan_fut scope_underwriting_fut scope_loan_underwriting_fut
reg discount_1_simple scope_*_fut 
preserve
reg discount_1_simple num_interactions_fut
drop num_interactions_fut
reg discount_1_simple num_*_fut  
restore

use "$data_path/sdc_ds_stacked_cleaned_with_rel_measures", clear


reg discount_1_simple log_amount_total_fut
preserve
drop log_amount_total_fut
reg discount_1_simple log_amount_*_fut

restore

*Want to do a similar analysis but instead only looking at observations that did not have a prev lending relationship
use "$data_path/sdc_ds_stacked_cleaned_with_rel_measures", clear
corr discount_1_simple duration num_interactions_prev scope_total concentration if rev_loan ==1 & no_prev_lender==1
corr discount_1_simple num_interactions_fut scope_total_fut scope_loan_fut scope_underwriting_fut ///
scope_loan_underwriting_fut if rev_loan ==1 & no_prev_lender==1

corr discount_1_simple duration scope_* if rev_loan ==1 
corr discount_1_simple num_*prev if rev_loan ==1 


corr discount_1_simple num_equity_prev num_debt_prev num_conv_prev num_equity_fut num_debt_fut num_conv_fut ///
	if rev_loan ==1 
corr discount_1_simple num_rev_loan_prev num_b_term_loan_prev num_i_term_loan_prev num_other_loan_prev num_equity_prev num_debt_prev num_conv_prev num_equity_fut num_debt_fut num_conv_fut ///
	if rev_loan ==1 & no_prev_lender==1
corr discount_1_simple num_rev_loan_prev num_b_term_loan_prev num_i_term_loan_prev num_other_loan_prev num_equity_prev num_debt_prev num_conv_prev num_equity_fut num_debt_fut num_conv_fut ///
	if rev_loan ==1 & refinancingindicator=="No"


reg discount_1_simple num_equity_prev num_debt_prev num_conv_prev num_equity_fut num_debt_fut num_conv_fut ///
	if rev_loan ==1 
reg discount_1_simple num_rev_loan_prev num_b_term_loan_prev num_i_term_loan_prev num_other_loan_prev num_equity_prev num_debt_prev num_conv_prev num_equity_fut num_debt_fut num_conv_fut ///
	if rev_loan ==1  & no_prev_lender==1
reg discount_1_simple num_rev_loan_prev num_b_term_loan_prev num_i_term_loan_prev num_other_loan_prev num_equity_prev num_debt_prev num_conv_prev num_equity_fut num_debt_fut num_conv_fut ///
	if rev_loan ==1  & refinancingindicator=="No"

reg discount_1_simple num_rev_loan_prev num_b_term_loan_prev num_i_term_loan_prev num_other_loan_prev num_equity_prev num_debt_prev num_conv_prev log_amount_equity_fut log_amount_debt_fut log_amount_conv_fut ///
	if rev_loan ==1 
reg discount_1_simple num_rev_loan_prev num_b_term_loan_prev num_i_term_loan_prev num_other_loan_prev num_equity_prev num_debt_prev num_conv_prev log_amount_equity_fut log_amount_debt_fut log_amount_conv_fut ///
	if rev_loan ==1  & no_prev_lender==1
reg discount_1_simple num_rev_loan_prev num_b_term_loan_prev num_i_term_loan_prev num_other_loan_prev num_equity_prev num_debt_prev num_conv_prev log_amount_equity_fut log_amount_debt_fut log_amount_conv_fut ///
	if rev_loan ==1  & refinancingindicator=="No"


use "$data_path/sdc_ds_stacked_cleaned_with_rel_measures", clear
collapse (mean) discount_1_simple, by(num_interactions_fut)
twoway line discount_1_simple num_interactions_fut

*Do a way to bring it down to loan level
use "$data_path/sdc_ds_stacked_cleaned_with_rel_measures", clear
*Only keep the lender observation that has had the most interactions with the firm
bys deal_id (scope_total lender): keep if _n ==_N
*Only keep the first discount observation
drop if mi(discount_1_simple)
keep if rev_loan ==1
bys cusip_6 (date_daily): keep if _n == 1

*Most baseline result:
use "$data_path/dealscan_compustat_loan_level", clear
local lhs discount_1_simple
local rhs no_prev_lender
local rhs_add
local cond `"if category =="Revolver""'
local sample_cond
local fe date_quarterly
reghdfe `lhs' `rhs' `rhs_add' `cond' `sample_cond' , a(`fe') vce(cl borrowercompanyid)

local fe "date_quarterly borrowercompanyid"
reghdfe `lhs' `rhs' `rhs_add' `cond' `sample_cond' , a(`fe') vce(cl borrowercompanyid)

*What if I get rid of refinances
local fe date_quarterly
local sample_cond `"& refinancingindicator !="Yes""'
reghdfe `lhs' `rhs' `rhs_add' `cond' `sample_cond' , a(`fe') vce(cl borrowercompanyid)
local fe "date_quarterly borrowercompanyid"
reghdfe `lhs' `rhs' `rhs_add' `cond' `sample_cond' , a(`fe') vce(cl borrowercompanyid)


*Random sum stats
use "$data_path/dealscan_compustat_loan_level", clear
replace refinancingindicator = "Missing" if mi(refinancingindicator)
local cond `"if category =="Revolver""'
sum discount_1_simple `cond' & refinancingindicator =="Yes"
sum discount_1_simple `cond' & refinancingindicator =="No"
sum discount_1_simple `cond' & refinancingindicator ==""

tab no_prev_lender if ~mi(discount_1_simple) & category == "Revolver" & refinancingindicator =="Yes"
tab no_prev_lender if ~mi(discount_1_simple) & category == "Revolver" & refinancingindicator =="No"
tab no_prev_lender if ~mi(discount_1_simple) & category == "Revolver"

tab no_prev_lender refinancingindicator if ~mi(discount_1_simple) & category == "Revolver" 

tab no_prev_lender refinancingindicator if ~mi(discount_1_simple) & category == "Revolver" & merge_compustat==1
tab no_prev_lender refinancingindicator if ~mi(discount_1_simple) & category == "Revolver" & merge_compustat==0


*Get the two by two table of means (not an actual table)
sum discount_1_simple `cond' & refinancingindicator =="Yes" & no_prev_lender ==1
sum discount_1_simple `cond' & refinancingindicator =="Yes" & no_prev_lender ==0
sum discount_1_simple `cond' & refinancingindicator =="No" & no_prev_lender ==1
sum discount_1_simple `cond' & refinancingindicator =="No" & no_prev_lender ==0
sum discount_1_simple `cond' & refinancingindicator =="Missing" & no_prev_lender ==1
sum discount_1_simple `cond' & refinancingindicator =="Missing" & no_prev_lender ==0

*Look at the stacked data to see if there is switching
use "$data_path/sdc_ds_stacked_cleaned_with_rel_measures", clear
gen switcher_loan_sdc = switcher_loan if sdc_obs==1
egen firm_has_switcher_sdc = max(switcher_loan_sdc), by(cusip_6)
gen type = ""
foreach var in $ds_types $sdc_types {
	replace type = "`var'" if `var' ==1
}
br deal_id cusip_6  type date_daily prev_lender first_loan switcher_loan type lender spread ///
if firm_has_switcher_sdc == 1
sort cusip_6 date_daily lender type

*Look at loans that are refinanced and compare their terms to the previous loans
use "$data_path/dealscan_compustat_loan_level", clear
gen refinance = (refinancingindicator=="Yes")
egen ever_refinance = max(refinance), by(borrowercompanyid)
gen discount_not_missing = !mi(discount_1_simple)
egen ever_discount = max(discount_not_missing), by(borrowercompanyid)

br borrowercompanyid packageid facilitystartdate category spread discount_1_simple refinance refinancingindicator facilityamt dealamount if ever_refinance ==1 & ever_discount==1

*Get nice examples of firms that have both banking discounts and future IB activity
use "$data_path/sdc_ds_stacked_cleaned_with_rel_measures", clear
br deal_id cusip_6 date_daily company issuer discount_1_simple
gen not_mi_discount = !mi(discount_1_simple)
egen firm_not_mi_discount = max(not_mi_discount), by(cusip_6)
br deal_id cusip_6 date_daily company issuer discount_1_simple if firm_not_mi_discount==1
*We will use NRG and Goldman Sachs as the example

*Do a more formal analysis of relationship strength measures and discounts
use "$data_path/sdc_ds_stacked_cleaned_with_rel_measures", clear
keep if date_daily >=td(01jan2006)
*create some locals
local num_interactions_list_sdc
local scope_list_sdc
local num_interactions_list_ds
local scope_list_ds
foreach var in  $sdc_types  { 
	local num_interactions_list_sdc `num_interactions_list_sdc' num_`var'_prev
	local scope_list_sdc `scope_list_sdc' scope_`var'
}
foreach var in  $ds_types  { 
	local num_interactions_list_ds `num_interactions_list_ds' num_`var'_prev
	local scope_list_ds `scope_list_ds' scope_`var'
}
foreach lhs in  discount_1_simple /* discount_1_controls */ {

	foreach discount_type in rev /* b_term */ {

		if "`discount_type'" == "rev" {
			local cond `"if category =="Revolver""'
			local disc_add "Rev"
			local discount_type_suffix_add "_rev"
		}
		if "`discount_type'" == "b_term" {
			local cond `"if category =="Bank Term""'
			local disc_add "B Term"
			local discount_type_suffix_add "_term"
		}
	
		local fe "date_quarterly"
		local fe_add "Time"
		local sample_add "Comp"
		estimates clear
		local i =1
	

					
		foreach rhs_type in simple_duration  simple_num_int simple_scope simple_all ///
		 split_num_interactions split_scope_total {
			
			if "`rhs_type'" == "simple_duration" {
				local rhs duration
			}
			if "`rhs_type'" == "simple_num_int" {
				local rhs num_interactions_prev
			}
			if "`rhs_type'" == "simple_scope" {
				local rhs scope_total
			}
			if "`rhs_type'" == "simple_all" {
				local rhs duration num_interactions_prev scope_total
			}
			
			if "`rhs_type'" == "split_num_interactions" {
				local rhs duration `num_interactions_list_ds' `num_interactions_list_sdc' 
			}
			if "`rhs_type'" == "split_scope_total"  {
				local rhs duration `scope_list_ds' `scope_list_sdc' 
			}

					
			reghdfe `lhs' `rhs' `rhs_add' `cond' `sample_cond' , a(`fe') vce(cl borrowercompanyid)
			estadd local fe = "`fe_add'"
			estadd local disc = "`disc_add'"
			estadd local sample = "`sample_add'"
			estimates store est`i'
			local ++i
			

		}
		esttab est* using "$regression_output_path/discount_rel_strength_`lhs'`discount_type_suffix_add'.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
		title("Discounts and Relationship Strength") scalars("fe Fixed Effects" "disc Discount" "sample Sample") ///
		addnotes("SEs clustered at firm level" "Sample are all dealscan discounts x lead arrangers from 2006Q1-2020Q4")	
	}
	
}


*Some random plots about ratings and discounts
use "$data_path/dealscan_compustat_loan_level", clear
twoway (scatter discount_1_simple rating_numeric ) (lfit discount_1_simple rating_numeric) ///
(qfit discount_1_simple rating_numeric)

*Look at loan packages over time to really understand the evolution of these things.
use "$data_path/dealscan_compustat_loan_level", clear
keep if !mi(borrowercompanyid) 
*In case there is a missing and a discount calculated, keep the not missing obs
bys borrowercompanyid category facilitystartdate first_loan prev_lender switcher_loan (discount_1_simple): keep if _n == 1

*I want the loan number to be 1 if it is labeled as a "no_prev_lender" and then the number number goes up
*until it hits no_prev_lending relationship again.
gen loan_number = 1 if no_prev_lender==1
bys borrowercompanyid (facilitystartdate): replace loan_num = loan_num[_n-1] + 1 if mi(loan_num)
*If I have multiple loans at the same point in time, set them equal to the same loan num
bys borrowercompanyid (facilitystartdate): replace loan_num = loan_num[_n-1] if facilitystartdate == facilitystartdate[_n-1]

*Only want to look at loans that at some point have a discount
gen refinance = (refinancingindicator=="Yes")
egen ever_refinance = max(refinance), by(borrowercompanyid)
gen discount_not_missing = !mi(discount_1_simple)
egen ever_discount = max(discount_not_missing), by(borrowercompanyid)

*Do a nice browse of the evolution of loans.
gsort borrowercompanyid facilitystartdate loan_num category -facilityamt
order borrowercompanyid facilitystartdate loan_num category spread discount_1_simple refinance
br if ever_discount ==1

corr discount_1_simple loan_num
reg discount_1_simple loan_num

*Do another browse on the evolution of loans
use "$data_path/dealscan_compustat_loan_level_with_loan_num", clear
order borrowercompanyid borrower_lender_group_id facilitystartdate category loan_number loan_num_category ///
spread spread_resid discount_1_simple discount_1_controls log_facilityamt 

gen t_discount_obs_rev = !mi(discount_1_simple) & category == "Revolver"
*Make similar dummies for whether they are firms with discounts, but now do it by firm x lender group and across time observations
egen discount_obs_rev_bco = max(t_discount_obs_rev), by(borrowercompanyid)
br if discount_obs_rev_bco ==1

*Do a simple analysis. For firms that have discounts calculated (discount_obs_rev_bco_group==1) at some point
*Are the observations where they are both getting a revolver and institutional loan have higher spreads?
reg spread discount_obs if category == "Inst. Term" & discount_obs_rev_bco_group==1
reg spread discount_obs if category == "Inst. Term" & discount_obs_rev_bco_group==1, absorb(borrower_lender_group_id)

*Look at how discounts/ spreads look like for IG loans
use "$data_path/dealscan_compustat_loan_level_with_loan_num", clear
br company borrowercompanyid facilitystartdate borrower_lender_group_id loan_number spread category discount_1_simple investment_grade rating_numeric ///
if borrower_lender_group_id == 29110
*if ~mi(investment_grade) & spread >500 & investment_grade ==1 & !mi(spread)

*Look to see if I have the CLO and mutual find identities for the institutional loans
use "$data_path/dealscan_facility_lender_level", clear
order facilityid borrowercompanyid facilitystartdate lender lead_arranger lenderrole institutional
br if institutional ==1
br if regexm(lender,"GOLUB")
tab lender if institutional ==1

gen institutional_lender = 0
foreach str in "FUND" "CLO" "LEVERAGED CAPITAL" "INSTITUTIONAL" "ADVISORS" ///
 "INVESTORS" "INVESTMENT MANAGEMENT" "LIFE" "INVESTMENTS" "ALLSTATE" "HIGH-YIELD" "PARTNERS" ///
 "ASSET" "INSURANCE" "RETIREMENT" "GOLUB" "BLACKSTONE" "CIFC" "CARLYLE" "ARES" ///
 "OCTAGON" "PGIM" "MJX" "ANCHORAGE CAPITAL" "NEUBERGER BERMAN" "FIRST EAGLE" "KKR" "VOYA" ///
 "SOUND POINT" "BLACKROCK" "BAIN CAPITAL" "PALMER SQUARE" "OAK HILL" "BARINGS" "CVC CREDIT" ///
 "CBAM" "FORTRESS INVESTMENT" "BENEFIT STREET" "LCM ASSET" "SCULPTOR LOAN" "ASSURED INVESTMENT" ///
 "REDDING RIDGE" "GOLDENTREE" "ONEX" "APOLLO GLOBAL" "ANTARES" "AGL" "NAPIER PARK" ///
 "HPS INVESTMENT" "ASSET MANAGEMENT" "SIXTH STREET" "CERBERUS CAPITAL" "CAPITAL MANAGEMENT" ///
 "REGIMENT CAPITAL" "FORTIS" "VAN KAMPEN" "TRAVELERS" "TRANSAMERICA" {
	replace institutional_lender = 1 if regexm(lender,"`str'")
}

gen lender_first_letter = substr(lender,1,1)
tab lender if institutional ==1
tab lender institutional_lender if institutional ==1 & lender_first_letter<"B"
tab lender institutional_lender if institutional ==1 & lender_first_letter>"S" & lender_first_letter<"W"
tab lender institutional_lender if institutional ==1 & lender_first_letter>"W"

*Do some simple correlations of discounts with number of instittional lenders on the instittional loans
use "$data_path/dealscan_compustat_loan_level", clear
gen no_i_lender = i_institutional_lender_count == 0
winsor2 i_lender_count i_institutional_lender_count, cuts (0 95) replace

gen i_share_i_lend_0_25 = i_share_institutional_lender>0 & i_share_institutional_lender <=.25
gen i_share_i_lend_25_50 = i_share_institutional_lender>.25 & i_share_institutional_lender <=.5
gen i_share_i_lend_50_100 = i_share_institutional_lender>.5 & i_share_institutional_lender <=1
label var i_share_i_lend_0_25 "Inst. Share = (0,0.25] for Inst. Loan"
label var i_share_i_lend_25_50 "Inst. Share = (.25,0.5] for Inst. Loan"
label var i_share_i_lend_50_100 "Inst. Share = (0.5,1] for Inst. Loan"
*Omitted group is 0

corr discount_1_simple i_lender_count i_institutional_lender_count i_share_institutional_lender
corr discount_1_simple i_lender_count i_institutional_lender_count i_share_institutional_lender if category == "Revolver"
reghdfe discount_1_simple i_lender_count i_institutional_lender_count i_share_institutional_lender if category == "Revolver", a(date_quarterly) vce(cl borrowercompanyid)
reghdfe discount_1_simple i_lender_count i_share_institutional_lender if category == "Revolver", a(date_quarterly) vce(cl borrowercompanyid)
reghdfe discount_1_simple i_lender_count i_institutional_lender_count if category == "Revolver", a(date_quarterly) vce(cl borrowercompanyid)
reghdfe discount_1_simple i_lender_count i_institutional_lender_count i_share_institutional_lender if category == "Revolver", a(date_quarterly) vce(cl borrowercompanyid)

reghdfe discount_1_simple i_lender_count no_i_lender i_share_institutional_lender if category == "Revolver", a(date_quarterly) vce(cl borrowercompanyid)

reghdfe discount_1_simple i_share_institutional_lender if category == "Revolver", a(date_quarterly) vce(cl borrowercompanyid)
reghdfe discount_1_simple i_lender_count i_share_i_lend_* if category == "Revolver", a(date_quarterly) vce(cl borrowercompanyid)

*See how these relate to 
use "$data_path/dealscan_compustat_loan_level_with_loan_num", clear
corr discount_1_simple prop_rev_total prop_rev_inst if category == "Revolver"

*Look at the total discounts
use "$data_path/dealscan_compustat_loan_level", clear
*Get discount x loan amounts by category x year
keep if category == "Revolver" | category == "Bank Term"
gen discount_loan_amount = discount_1_simple/10000 * facilityamt / 1000000 //Now the units are in millions dollars of discounts
keep if !mi(discount_loan_amount)
gen facility_start_year = year(facilitystartdate)
gen count = 1
collapse (sum) count discount_loan_amount, by(facility_start_year category)
sort facility_start_year category
export delimited using "$data_path/discount_amount_per_year_millions", replace

*Kdensity of compustat vs non compustat 
**** Customized distribution of discount graph - kdensity
use "$data_path/dealscan_compustat_loan_level", clear

ttest discount_1_simple if category == "Revolver", by(merge_compustat) unequal

local comp (kdensity  discount_1_simple if category == "Revolver" & merge_compustat ==1, color(midblue) bwidth(20)  lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))
local non_comp (kdensity discount_1_simple if category == "Revolver" & merge_compustat ==0, col(orange) bwidth(20) lpattern(solid) cmissing(n) lwidth(medthin) yaxis(1))

twoway `comp' `non_comp'  ///
, ytitle("Density",axis(1))  ///
 title("Kernel Density of Revolving Discount - Compustat vs Non Compustat",size(medsmall)) ///
graphregion(color(white))  xtitle("Discount") ///
legend(order(1 "Compustat" 2 "Non Compustat")) ///
 note("" "Epanechnikov kernel with bandwidth 20")
graph export "$figures_output_path/discount_kdensity_rev_comp_non_comp.png", replace
