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
