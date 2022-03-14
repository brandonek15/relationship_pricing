*This program runs summary statistics and correlation tables
use  "$data_path/dealscan_compustat_loan_level", clear
keep if merge_compustat==1
*Want to do these sets of summary stats
*Firm characteristics of compustat firms matched to dealscan - split by whether discount is calculated or not - 
*define firm as discount firm if at any point they had a discount
local firm_chars L1_market_to_book L1_ppe_assets L1_log_assets L1_leverage ///
L1_roa L1_sales_growth L1_ebitda_int_exp ///
L1_working_cap_assets L1_capex_assets

*Drop duplicate observations
keep borrowercompanyid date_quarterly discount_obs  `firm_chars' 
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

*Loan characteristics - split in four samples - not matched to dealscan and no discount - not matched to dealscan and no discount
*matched to dealscan and discount, matched to dealscan and no discount.
use  "$data_path/dealscan_compustat_loan_level", clear

local loan_vars log_facilityamt maturity leveraged fin_cov nw_cov borrower_base cov_lite asset_based spread salesatclose 

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
	 label title("Origination Level Loan Characteristics- `title_add'") replace ///
	cells("p25(fmt(3)) p50(fmt(3)) p75(fmt(3)) mean(fmt(2)) sd(fmt(2)) count(fmt(0))") ///
	nomtitle  nonum noobs

}

/*
*Correlation tables
use  "$data_path/dealscan_compustat_loan_level", clear

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
		
*Need to make a dataset where it is
		
corrtex spread *bbb_spread if category == "Revolver", title("Spread Correlations") sig ///
file("$regression_output_path/discount_correlations_both.tex") replace
