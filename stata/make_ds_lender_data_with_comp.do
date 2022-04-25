*This program will make a lender x loan datasetload in the compustat data, merge on the dealscan data,

use "$data_path/dealscan_facility_lender_level", clear
keep if lead_arranger_credit ==1

*For now keep both that can be matched to compustat and those that cannot, which are those that can match to compustat.
merge m:1 borrowercompanyid date_quarterly using "$data_path/stata_temp/compustat_with_bcid", keep(1 3)
gen merge_compustat = _merge ==3
drop _merge
sort borrowercompanyid date_quarterly cusip_6
*merge on discount information
merge m:1 facilityid using "$data_path/stata_temp/dealscan_discounts_facilityid", keep(1 3) nogen
*Create an indicator whether it is a discount obs or not
gen not_missing_discount_temp = !mi(discount_1_simple)
egen discount_obs = max(not_missing_discount_temp), by(borrowercompanyid date_quarterly)
drop not_missing_discount_temp
gen constant = 1

*Save a loan x lender file
save "$data_path/dealscan_compustat_lender_loan_level", replace
drop lender agent_credit lead_arranger_credit bankallocation lenderrole
duplicates drop
*Save a loan level file
save "$data_path/dealscan_compustat_loan_level", replace

*Create a dataset where a loan has a previous same lender and then look at the discount
use "$data_path/dealscan_compustat_lender_loan_level", clear
isid facilityid lender
gen prev_lender = 0
drop if mi(borrowercompanyid)
*Can either use borrowercompanyid (which will give me all of DS) or use cusip_6, which will give me only merged compustat
*Say you were a previous lender if you were the same lender to the same firm earlier
*Or if you were previoulsy a previous lender
bys borrowercompanyid lender (date_quarterly facilityid): replace prev_lender = 1 if lender[_n] == lender[_n-1] & date_quarterly[_n] != date_quarterly[_n-1]
bys borrowercompanyid lender (date_quarterly facilityid): replace prev_lender = 1 if prev_lender[_n-1] == 1
egen max_prev_lender = max(prev_lender), by(facilityid)
br facilityid borrowercompanyid lender prev_lender max_prev_lender date_quarterly
sort borrowercompanyid facilityid date_quarterly
*sort borrowercompanyid lender date_quarterly facilityid
*br borrowercompanyid lender date_quarterly facilityid prev_lender
keep facilityid borrowercompanyid max_prev_lender discount* d_* date_quarterly category merge_compustat
duplicates drop
*Create three categories - first loans 
egen min_date_quarterly = min(date_quarterly), by(borrowercompanyid)
format min_date_quarterly %tq
br facilityid borrowercompanyid date_quarterly min_date_quarterly
sort borrowercompanyid date_quarterly
gen first_loan = date_quarterly == min_date_quarterly
label var first_loan "First Loan"
rename max_prev_lender prev_lender
label var prev_lender "Prev Lending Relationship"
gen switcher_loan = (first_loan ==0 & prev_lender==0)
label var switcher_loan "Switching Lender"
assert first_loan + prev_lender + switcher_loan ==1

		preserve
			freduse USRECM BAMLC0A4CBBB BAMLC0A1CAAA, clear
			gen date_quarterly = qofd(daten)
			collapse (max) USRECM , by(date_quarterly)
			tsset date_quarterly
			keep date_quarterly USRECM
			tempfile rec
			save `rec', replace
		restore

*Get recession data
joinby date_quarterly using `rec', unmatched(master) 
drop _merge

gen prev_lender_rec = USRECM * prev_lender
label var prev_lender_rec "Rec x Prev Lending Relationship"
gen first_loan_rec = USRECM * first_loan
label var first_loan_rec "Rec x First Loan"
gen switcher_loan_rec = USRECM * switcher_loan
label var switcher_loan_rec "Rec x Switching Lender"


save "$data_path/stata_temp/dealscan_discount_prev_lender", replace
