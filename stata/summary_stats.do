*This program runs summary statistics and correlation tables
use  "$data_path/dealscan_compustat_loan_level", clear
keep if merge_compustat==1
*Want to do these sets of summary stats
*Firm characteristics of compustat firms matched to dealscan - split by whether discount is calculated or not - 
*define firm as discount firm if at any point they had a discount
local firm_chars L1_market_to_book L1_ppe_assets L1_current_assets L1_log_assets L1_leverage ///
L1_roa L1_sales_growth L1_ebitda_int_exp ///
L1_working_cap_assets L1_capex_assets L1_firm_age rating_numeric

*Drop duplicate observations
keep borrowercompanyid date_quarterly discount_obs d_1_simple_pos merge_ratings `firm_chars' 
duplicates drop

winsor2 `firm_chars', cuts(.5 99.5) replace

foreach sample in discount no_discount {
	if "`sample'" == "discount" {
		local cond "if discount_obs ==1"
		local title_add "Discount Obs"
	}
	else if "`sample'" == "no_discount" {
		local cond "if discount_obs ==0"
		local title_add "No Discount Obs"
	} 

	estpost tabstat `firm_chars' `cond', s(p5 p25 p50 p75 p95 mean sd count) c(s)
	esttab . using "$regression_output_path/sumstats_firm_chars_`sample'.tex", ///
	 label title("Origination Level Firm Characteristics- `title_add'") replace ///
	cells("p25(fmt(3)) p50(fmt(3)) p75(fmt(3)) mean(fmt(2)) sd(fmt(2)) count(fmt(0))") ///
	nomtitle  nonum noobs

}

*Make a difference of means table
*By discount calculated or not
eststo: estpost ttest `firm_chars' , by(discount_obs) unequal
	
esttab . using "$regression_output_path/differences_firm_chars_discount_obs.tex", ///
 label title("Origination Level Firm Characteristics") replace ///
cells("mu_2(fmt(3)) mu_1(fmt(3)) b(star)") collabels("Disc Obs" "Non Disc Obs" "Difference") ///
 nonum eqlabels(none) addnotes("Sample is Observations Merged to Compustat") 

*by positive discount or not
eststo: estpost ttest `firm_chars' , by(d_1_simple_pos) unequal
	
esttab . using "$regression_output_path/differences_firm_chars_discount_pos.tex", ///
 label title("Origination Level Firm Characteristics") replace ///
cells("mu_2(fmt(3)) mu_1(fmt(3)) b(star)") collabels("Pos Disc" "Non Pos Disc" "Difference") ///
 nonum eqlabels(none) addnotes("Sample is Observations Merged to Compustat")  
 
*Make a difference of means table
eststo: estpost ttest `firm_chars' , by(discount_obs) unequal
	
esttab . using "$regression_output_path/differences_firm_chars_discount_obs.tex", ///
 label title("Origination Level Firm Characteristics") replace ///
cells("mu_2(fmt(3)) mu_1(fmt(3)) b(star)") collabels("Disc Obs" "Non Disc Obs" "Difference") ///
 nonum eqlabels(none) addnotes("Sample is Observations Merged to Compustat") 

*Make a difference of means table for ratings
local exclude "rating_numeric"
local firm_chars: list firm_chars - exclude
eststo: estpost ttest `firm_chars' , by(merge_ratings) unequal
	
esttab . using "$regression_output_path/differences_firm_chars_ratings_obs.tex", ///
 label title("Origination Level Firm Characteristics") replace ///
cells("mu_2(fmt(3)) mu_1(fmt(3)) b(star)") collabels("Obs with Ratings" "Obs w/out Ratings" "Difference") ///
 nonum eqlabels(none) addnotes("Sample is Observations Merged to Compustat") 

*Loan characteristics - split in four samples - not matched to dealscan and no discount - not matched to dealscan and no discount
*matched to dealscan and discount, matched to dealscan and no discount.
use  "$data_path/dealscan_compustat_loan_level", clear
local loan_vars spread log_facilityamt maturity cov_lite leveraged asset_based senior secured

winsor2 `loan_vars', cuts(.5 99.5) replace
*Todo by loan type
foreach sample in discount_comp no_discount_comp discount_no_comp no_discount_no_comp ///
	revolver bank_term inst_term other {
	if "`sample'" == "discount_comp" {
		local cond "if discount_obs ==1 & merge_compustat ==1"
		local title_add "Discount Obs - Compustat Match"
	}
	if "`sample'" == "discount_no_comp" {
		local cond "if discount_obs ==1 & merge_compustat ==0"
		local title_add "Discount Obs - Not Compustat Matched"
	}
	if "`sample'" == "no_discount_comp" {
		local cond "if discount_obs ==0 & merge_compustat ==1"
		local title_add "No Discount Obs - Compustat Match"
	}
	if "`sample'" == "no_discount_no_comp" {
		local cond "if discount_obs ==0 & merge_compustat ==0"
		local title_add "No Discount Obs - Not Compustat Matched"
	}
	if "`sample'" == "revolver" {
		local cond `"if category =="Revolver""'
		local title_add "Revolvers"
	}
	if "`sample'" == "bank_term" {
		local cond `"if category =="Bank Term""'
		local title_add "Bank Term Loans"
	}
	if "`sample'" == "inst_term" {
		local cond `"if category =="Inst. Term""'
		local title_add "Institutional Term Loans"
	}
	if "`sample'" == "other" {
		local cond `"if category =="Other""'
		local title_add "Other Loans"
	}


	estpost tabstat `loan_vars' `cond', s(p5 p25 p50 p75 p95 mean sd count) c(s)
	esttab . using "$regression_output_path/sumstats_loan_chars_`sample'.tex", ///
	 label title("Origination Level Loan Characteristics - `title_add'") replace ///
	cells("p25(fmt(3)) p50(fmt(3)) p75(fmt(3)) mean(fmt(2)) sd(fmt(2)) count(fmt(0))") ///
	nomtitle  nonum noobs

}

*For Ben: loan_vars are there, we can just look at the first few that we actually use in the discounts to keep it simple
*The indicator "discount_obs_rev" is an indicator for a loan being in a package with a revolving discount,
* "discount_obs_b_term" same for bank term discount, and "discount_obs" for either of them.

*Make a difference of means table
local exclude "institutional"
local loan_vars: list loan_vars - exclude
keep if category == "Revolver" | category == "Bank Term"
eststo: estpost ttest `loan_vars', by(discount_obs) unequal
	
esttab . using "$regression_output_path/differences_loan_chars_discount_obs.tex", ///
 label title("Origination Level Loan Characteristics") replace ///
cells("mu_2(fmt(3)) mu_1(fmt(3)) b(star)") collabels("Disc Obs" "Non Disc Obs" "Difference") ///
 nonum eqlabels(none) addnotes("Sample is Revolver and Bank Term Loans") 

local loan_vars discount_1_simple discount_1_controls `loan_vars' 
keep if category == "Revolver" | category == "Bank Term"
eststo: estpost ttest `loan_vars', by(merge_ratings) unequal
	
esttab . using "$regression_output_path/differences_loan_chars_ratings_obs.tex", ///
 label title("Origination Level Loan Characteristics") replace ///
cells("mu_2(fmt(3)) mu_1(fmt(3)) b(star)") collabels("Obs with Ratings" "Obs w/out Ratings" "Difference") ///
 nonum eqlabels(none) addnotes("Sample is Revolver and Bank Term Loans") 

*Summary stats table of discounts/spreads and Correlation tables
use  "$data_path/dealscan_compustat_loan_level", clear
foreach var in discount_1_simple discount_1_controls discount_1_controls_np {
	gen temp_term_disc = `var' if category == "Bank Term" 
	egen temp_term_disc_sp = max(temp_term_disc), by(borrowercompanyid facilitystartdate)
	gen temp_rev_disc = `var' if category == "Revolver" 
	egen temp_rev_disc_sp = max(temp_rev_disc), by(borrowercompanyid facilitystartdate)
	*Drop the revolving discount and then recreate it so it is populated for all loans in the quarter x firm
	drop `var'
	*Create the term_discount, which will exist 
	gen term_`var' = temp_term_disc_sp
	gen rev_`var' = temp_rev_disc_sp
	drop temp*
	
}
*Need to spread the bank term, inst term, revolver, and other spread 
gen temp_term_sprd = spread if category == "Bank Term" 
egen term_sprd_sp = mean(temp_term_sprd), by(borrowercompanyid facilitystartdate)
gen temp_rev_sprd = spread if category == "Revolver" 
egen rev_sprd_sp = mean(temp_rev_sprd), by(borrowercompanyid facilitystartdate)
gen temp_inst_term_sprd = spread if category == "Inst. Term" 
egen inst_term_sprd_sp = mean(temp_inst_term_sprd), by(borrowercompanyid facilitystartdate)
gen temp_other_sprd = spread if category == "Other" 
egen other_sprd_sp = mean(temp_other_sprd), by(borrowercompanyid facilitystartdate)

*Want to match sample in regression tables, so now only include bank loans
keep if category == "Revolver" | category == "Bank Term"
drop if mi(rev_discount_1_simple) & mi(term_discount_1_simple)
keep borrowercompanyid rev_discount* term_discount_* *sprd_sp facilitystartdate date_quarterly
rename *sprd_sp *sprd	
save "$data_path/stata_temp/discounts_and_spreads_borrowercompanyid_facilitystartdate_loan_obs", replace

*Now make the summary stats table
use "$data_path/stata_temp/discounts_and_spreads_borrowercompanyid_facilitystartdate_loan_obs", clear
gen rev_inst_term_sprd = inst_term_sprd if ~mi(rev_discount_1_simple)
gen term_inst_term_sprd = inst_term_sprd if ~mi(term_discount_1_simple)
replace rev_sprd = . if mi(rev_discount_1_simple)
replace term_sprd = . if mi(term_discount_1_simple)

duplicates drop

foreach type in rev term {
	
	if "`type'" == "rev" {
		local label_add "Rev Disc Sample:"
	}
	if "`type'" == "term" {
		local label_add "Term Disc Sample"
	}
	

	label var `type'_discount_1_simple "`label_add' Simple Discount"
	label var `type'_discount_1_controls "`label_add' Discount with Controls"
	label var `type'_discount_1_controls_np "`label_add' Discount with Non-Parametric Controls"
	label var `type'_sprd "`label_add' Revolving Spread"
	label var `type'_inst_term_sprd "`label_add' Institutional Term Spread"
	
}

local rev_vars rev_discount_1_simple rev_discount_1_controls  ///
	rev_discount_1_controls_np rev_sprd rev_inst_term_sprd

local term_vars term_discount_1_simple term_discount_1_controls  ///
	term_discount_1_controls_np term_sprd term_inst_term_sprd

estpost tabstat `rev_vars' `term_vars', s(min p5 p25 p50 p75 p95 max mean sd count) c(s)
esttab . using "$regression_output_path/sumstats_discounts_spreads.tex", ///
 label title("Loan Discounts") replace ///
cells("min(fmt(3)) p25(fmt(3)) p50(fmt(3)) p75(fmt(3)) max(fmt(3)) mean(fmt(2)) sd(fmt(2)) count(fmt(0))") ///
nomtitle  nonum noobs note("Only includes observations where the particular discount can be calculated")

*Now do a correlations table
use "$data_path/stata_temp/discounts_and_spreads_borrowercompanyid_facilitystartdate_loan_obs", clear
duplicates drop
isid borrowercompanyid facilitystartdate

*

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
			
corrtex *sprd *bbb_spread, title("Spread Correlations") sig ///
file("$regression_output_path/spread_correlations_both.tex") replace

corrtex *sprd rev_discount* term_discount_*, title("Spread Correlations with Discount") sig ///
file("$regression_output_path/discount_correlations_both.tex") replace

*Same tables but instead using time series correlations with simple averages
drop if mi(rev_discount_1_simple) & mi(term_discount_1_simple)
collapse (mean) *sprd *bbb_spread rev_discount* term_discount_*, by(date_quarterly)

corrtex *sprd *bbb_spread, title("Spread Correlations - Time Series Means") sig ///
file("$regression_output_path/spread_correlations_both_mean_time_series.tex") replace

corrtex *sprd rev_discount* term_discount_*, title("Spread Correlations with Discount - Time Series Means") sig ///
file("$regression_output_path/discount_correlations_both_mean_time_series.tex") replace


*New summary stats tables for the paper
use  "$data_path/dealscan_compustat_loan_level", clear
keep if category == "Revolver" | category == "Bank Term"
eststo clear

local firm_chars L1_market_to_book L1_ppe_assets L1_current_assets L1_log_assets L1_leverage ///
L1_roa L1_sales_growth L1_ebitda_int_exp ///
L1_working_cap_assets L1_capex_assets L1_firm_age rating_numeric

local loan_vars spread log_facilityamt maturity cov_lite leveraged asset_based senior secured

eststo: estpost tabstat  `firm_chars' `loan_vars', by(category)  statistics(mean sd) columns(statistics) listwise

eststo: estpost tabstat  `firm_chars' `loan_vars' if discount_obs==1, by(category )   statistics(mean sd) columns(statistics) listwise

esttab est1 est2 using "$regression_output_path/sumstats_by_discount_obs_paper.tex", ///
 cells("mean(label(Mean) fmt(3)) sd(label(St. Dev) fmt(3))") label  ///
	mgroups("Full Sample" "Discount Sample" ,pattern(1  1  )  ///
	prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) nonumber noobs replace

use  "$data_path/dealscan_compustat_loan_level", clear
drop if category == "Other"
*drop if category == "Inst. Term"
gen cat_new= ""
replace cat_new = "Rev" if category == "Revolver"
replace cat_new = "B Term" if category == "Bank Term"
replace cat_new = "I Term" if category == "Inst. Term"
eststo clear

eststo: estpost tabstat  `loan_vars', by(cat_new)  statistics(mean sd) columns(statistics) 

*Now just make it print nice
esttab est1 using "$regression_output_path/sumstats_by_loan_type_paper.tex", ///
 unstack cells("mean(label(Mean) fmt(3)) sd(label(St. Dev) fmt(3))") label replace

/*
esttab est1 using "$regression_output_path/sumstats_by_loan_type.tex", ///
 unstack  cells("mean(label(Mean) fmt(3)) sd(label(SD) fmt(3))" ) label  ///
nonumber noobs replace
