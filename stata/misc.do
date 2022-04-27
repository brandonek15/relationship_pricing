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
egen past_relationship = rowmax(rel_equity rel_debt rel_conv rel_rev_loan rel_term_loan rel_other_loan)
reg hire past_relationship
*/

gen rev_loan_discount_inter = 0
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
br borrowercompanyid company  merge_compustat publicprivate date_quarterly gvkey 
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

estimates clear
local i =1

local lhs discount_1_simple
*Try to decompose why firm FE changes result of switchers
*First start with simplest regression, only time FE
reghdfe `lhs' prev_lender switcher_loan if date_quarterly >=tq(2005q1) , a(date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Time"
estadd local disc = "All Disc"
estadd local sample = "All"
estimates store est`i'
local ++i
*Keep only sample from FE regression
reghdfe `lhs' prev_lender switcher_loan if date_quarterly >=tq(2005q1) &sample_keep==1, a(date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Time"
estadd local disc = "All Disc"
estadd local sample = "FE Reg Obs"
estimates store est`i'
local ++i

*Keep only observations that can identify coefficients
reghdfe `lhs' prev_lender switcher_loan if date_quarterly >=tq(2005q1) &mult_obs==1 &sample_keep==1, a(date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Time"
estadd local disc = "All Disc"
estadd local sample = "Coeff Identifying Obs"
estimates store est`i'
local ++i

*Keep only firms that have both gone back to the previous lender and switched
reghdfe `lhs' prev_lender switcher_loan if date_quarterly >=tq(2005q1) &max_prev_lender==1 &max_switcher_loan==1 &sample_keep==1, a(date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Time"
estadd local disc = "All Disc"
estadd local sample = "Prev Lender and Switch Firms"
estimates store est`i'
local ++i

*The FE regression
reghdfe `lhs' prev_lender switcher_loan if date_quarterly >=tq(2005q1) , a(borrowercompanyid date_quarterly) vce(cl borrowercompanyid)
estadd local fe = "Firm, Time"
estadd local disc = "All Disc"
estadd local sample = "FE Reg Obs"
estimates store est`i'
local ++i

esttab est* using "$regression_output_path/discount_prev_lend_`lhs'_all_stay_leave_decomposition_slides.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
title("Discounts and Previous Lenders") scalars("fe Fixed Effects" "disc Discount" "sample Sample") ///
addnotes("SEs clustered at firm level" "Sample are all dealscan discounts from 2005Q1-2020Q4" "Dropping 2001Q1-2004Q4 as burnout period")	

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
