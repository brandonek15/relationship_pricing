*Import the merged data
import delimited using "$data_path/dealscan_merge.csv", clear

duplicates drop

*Since we need lender identities, we will drop those observations without them - small number
drop if mi(lender)
*Drop Financials
drop if inrange(primarysiccode,6000,6999)
*Keep only US borrowers
keep if country == "USA"

*Format dates
foreach var in facilitystartdate facilityenddate {
	gen temp = date(`var',"YMD")
	format temp %td
	drop `var' 
	rename temp `var'
}
sort borrowercompanyid facilityid packageid loantype facilitystartdate

*Renamecovenant variables
rename covenanttype cov_type_fin
rename initialratio init_ratio_fin
rename baseamt base_amt_nw
rename percentofnetincome perc_ni_nw
rename covenanttype_nw cov_type_nw

*Generate covenant existence variables
gen fin_cov = (!mi(init_ratio_fin) | !mi(cov_type_fin))
gen nw_cov = (!mi(base_amt_nw) | !mi(cov_type_nw) | !mi(perc_ni_nw))
gen borrower_base = (!mi(borrowerbasetype) | !mi(borrowerbasepercentage))
gen cov = fin_cov ==1 | nw_cov==1
label var fin_cov "Financial Cov"
label var nw_cov "Net Worth Cov"
label var borrower_base "Borrowing Base"
label var cov "Contains Covenants"

replace marketsegment = "N/A" if mi(marketsegment)
replace cov_type_fin = "None" if mi(cov_type_fin)
replace cov_type_nw = "None" if mi(cov_type_nw)
replace borrowerbasetype = "N/A" if mi(borrowerbasetype)

*Create a variable for seniority and secured
gen senior = (seniority == "Senior")
label var senior "Senior Loan"
gen secured_num = (secured == "Yes") 
drop secured
rename secured_num secured
label var secured "Secured"

*Create variables based off of marketsegment
gen leveraged = (marketsegment == "Leveraged" | marketsegment == "Highly Leveraged")
gen cov_lite = (marketsegment == "Covenant Lite")
replace borrower_base = 1 if (marketsegment == "Borrowing Base")
gen asset_based = (marketsegment == "Asset Based")
gen institutional = (marketsegment == "Institutional")

*Starting with this type of a dataset
isid borrowercompanyid facilityid marketsegment cov_type_fin cov_type_nw borrowerbasetype lender
*Want to get down to a facility x lender dataset

save "$data_path/stata_temp/dealscan_pre_collapse", replace

*Create indiciators for financial covenants, net worth covenants, and borrower base
*Note that this dataset would still be valid if I didn't collapse by lender, but want to do a 1:1 merge later
use "$data_path/stata_temp/dealscan_pre_collapse", clear
collapse (max) fin_cov nw_cov borrower_base leveraged cov_lite asset_based institutional, by(facilityid lender)
isid facilityid lender
save "$data_path/stata_temp/dealscan_indicators", replace

use "$data_path/stata_temp/dealscan_pre_collapse", clear
*Get it into a facilityid lender dataset to merge on indicators
drop marketsegment borrowerbasetype borrowerbasepercentage cov_type_fin ///
 init_ratio_fin base_amt_nw perc_ni_nw cov_type_nw ///
 fin_cov nw_cov borrower_base ///
 leveraged cov_lite asset_based institutional

duplicates drop
isid facilityid lender
merge 1:1 facilityid lender using  "$data_path/stata_temp/dealscan_indicators", assert(3) nogen

*Now we need to use loan types 
*Create indicators for the different types of loans
gen rev_loan = ///
 (loantype == "364-Day Facility" | loantype  == "Revolver/Line < 1 Yr." | ///
 loantype  == "Revolver/Line >= 1 Yr." | loantype  == "Revolver/Term Loan")
gen institutional_term_loan = 0
foreach type in B C D E F G H I J K {
	replace institutional_term_loan = 1 if loantype == "Term Loan `type'"
}

gen amortizing_term_loan = (loantype == "Term Loan" | loantype == "Term Loan A")
*Create a generic term loan indicator
gen term_loan = institutional_term_loan + amortizing_term_loan
*Create indicitator for other loan that isn't term or revolving credit
gen other_loan = rev_loan ==0 & term_loan ==0

*Create categories
gen i_term_loan = term_loan ==1 & institutional ==1
gen b_term_loan =  term_loan ==1 & institutional ==0
label var i_term_loan "Inst. Term Loan"
label var b_term_loan "Bank Term Loan"
label var rev_loan  "Revolver"
label var other_loan "Other Loan"

gen category = ""
replace category = "Revolver" if rev_loan ==1
replace category = "Inst. Term" if i_term_loan ==1
replace category = "Bank Term" if b_term_loan ==1 
replace category = "Other" if other_loan==1
*Create quarter date variable.
gen date_quarterly = qofd(facilitystartdate)
format date_quarterly %tq
label var date_quarterly "Quarterly Start Date"
gen end_date_quarterly = qofd(facilityenddate)
format end_date_quarterly %tq
label var end_date_quarterly "Quarterly End Date"
*Make a date_daily variable
gen date_daily = facilitystartdate
label var date_daily "Date Daily of Start Date"
format date_daily %td
*Need to make an adjustment to cov variable based on Berlin, Nini, Yu. All revolving loans have covenants
replace cov = 1 if rev_loan==1

*Merge on FRED rate data to make a comparable spread variable
merge m:1 date_quarterly using "$data_path/fred_rates", nogen keep(1 3)
*Make some fair adjustments to rates- don't want to throw it out of the sample
replace minbps = allindrawn if minbps>=10000 //100% interest is not realistic

gen spread = allindrawn 
*allindrawn is the amount the borrower pays in bps over LIBOR for each dollar drawn, including spread and annual/facility fee
*Will make another measure of spread with minbps (note that maxbps and minbps are almost always the same)
gen spread_2 = minbps
replace spread_2 = allindrawn + dprime - lior3m if baserate == "Prime"
replace spread_2 = allindrawn if baserate == "Fixed Rate"
*Will assume all other rates are spreads over libor (they are very small, collectively like 100 obs)

*Make variables for discount regression
*First make sure the currencies match up
replace facilityamt = facilityamt*exchangerate
gen log_facilityamt = log(facilityamt)

*Before running, then this is true
isid facilityid lender 

*Load in the function for standardization of lenders
do "$code_path/standardize_dealscan.do"
*Run standardization function
standardize_ds
*After standardizing, this is not an identifer (check out facilityid 446806 for a good example)
*Need to collapse to facilityid lender
*The variables that vary are agentcredit leadarrangercredit bankallocation lenderrole
gen agent_credit = (agentcredit == "Yes")
gen lead_arranger_credit = (leadarrangercredit == "Yes")
drop agentcredit leadarrangercredit

*Make a dataset with collapsing only the variables that vary
preserve
keep facilityid lender agent_credit lead_arranger_credit bankallocation lenderrole
gsort facilityid lender -bankallocation -lead_arranger_credit agent_credit
*Want to keep the role of the observation with the higher allocatoin, but if not allocation, then lead_arranger_credit agent_credit
collapse (max) agent_credit lead_arranger_credit (sum) bankallocation (first) lenderrole, by(facilityid lender)
*Want to make bankallocation missing if zero
replace bankallocation = . if bankallocation==0 | bankallocation>100
save "$data_path/stata_temp/facilityid_lender_merge_data", replace
restore
*
drop agent_credit lead_arranger_credit bankallocation lenderrole
duplicates drop
merge 1:1 facilityid lender using "$data_path/stata_temp/facilityid_lender_merge_data", nogen assert(3)

isid facilityid lender 

*Make bins for maturity
forval i = 0(12)108 {
	local start = `i'
	local stop = `i'+11
	gen maturity_`start'_`stop' = (maturity >=`start' & maturity <=`stop')
	label var maturity_`start'_`stop' "Maturity = [`start',`stop']"
}
gen maturity_120_plus = (maturity>=120 & ~mi(maturity))
label var maturity_120_plus "Maturity = [120,inf)"

*Make maturity [60,71] the baseline
drop maturity_60_71
*Make missing maturity variable
gen maturity_mi = mi(maturity)
label var maturity_mi "Maturity Missing"

*Create deciles for loan size (will do log_facilityamt bc why not
xtile xtile_log_facilityamt = log_facilityamt, nquantiles(10)
forval i = 1(1)10 {
	gen log_facilityamt_dec_`i' = xtile_log_facilityamt==`i'
	label var log_facilityamt_dec_`i' "Facility Amt Decile `i'"
}
*Make decile 1 be the baseline
drop log_facilityamt_dec_1

*Label important variables
label var log_facilityamt "Log Facility Amount"
label var maturity "Maturity"
label var leveraged "Leveraged Loan"
label var fin_cov "Contains Financial Covenants"
label var nw_cov "Contains Net Worth Covenants"
label var borrower_base "Borrower Base"
label var cov_lite "Cov-Lite"
label var asset_based "Asset-Based Loan"
label var spread "Spread"
label var salesatclose "Annual Sales (millions)"
replace salesatclose = salesatclose/1000000

save "$data_path/dealscan_facility_lender_level", replace

*Create a datset with only facility variables that can used in analyses
*First create a dataset with the number of lenders and institutional lenders
use "$data_path/dealscan_facility_lender_level", clear
gen lender_count =1
collapse (sum) lender_count institutional_lender, by(facilityid)
rename institutional_lender institutional_lender_count

gen share_institutional_lender = institutional_lender_count/lender_count
save "$data_path/stata_temp/facilityid_institutional_lender_counts", replace

*This will also create the types of loan relationship states
use "$data_path/dealscan_facility_lender_level", clear
isid facilityid lender
gen prev_lender = 0
drop if mi(borrowercompanyid)
*Can either use borrowercompanyid (which will give me all of DS) or use cusip_6, which will give me only merged compustat
*Say you were a previous lender if you were the same lender to the same firm earlier
*Or if you were previoulsy a previous lender
bys borrowercompanyid lender (date_quarterly facilityid): replace prev_lender = 1 if lender[_n] == lender[_n-1] & date_quarterly[_n] != date_quarterly[_n-1]
bys borrowercompanyid lender (date_quarterly facilityid): replace prev_lender = 1 if prev_lender[_n-1] == 1
egen max_prev_lender = max(prev_lender), by(facilityid)
*br facilityid borrowercompanyid lender prev_lender max_prev_lender date_quarterly
sort borrowercompanyid facilityid date_quarterly

*Create three categories - first loans 
egen min_facilitystartdate = min(facilitystartdate), by(borrowercompanyid)
format min_facilitystartdate %td
*br facilityid borrowercompanyid date_quarterly min_date_quarterly
sort borrowercompanyid facilitystartdate
gen first_loan = facilitystartdate == min_facilitystartdate
label var first_loan "First Loan"
drop prev_lender
*The max_prev_lender is basically saying any previous lending relationship means this is a 1
rename max_prev_lender prev_lender
label var prev_lender "Prev Lending Relationship"
*Create the opposite dummy
gen no_prev_lender = 1 - prev_lender
label var no_prev_lender "No Prev Lending Relationship"
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

*Make recession interactions
gen prev_lender_rec = USRECM * prev_lender
label var prev_lender_rec "Rec x Prev Lending Relationship"
gen no_prev_lender_rec = USRECM * no_prev_lender
label var no_prev_lender_rec "Rec x No Prev Lending Relationship"
gen first_loan_rec = USRECM * first_loan
label var first_loan_rec "Rec x First Loan"
gen switcher_loan_rec = USRECM * switcher_loan
label var switcher_loan_rec "Rec x Switching Lender"

drop lender institutional_lender lenderrole bankallocation agent_credit lead_arranger_credit
duplicates drop
isid facilityid

merge 1:1 facilityid using "$data_path/stata_temp/facilityid_institutional_lender_counts", nogen assert(3)

save "$data_path/dealscan_facility_level", replace

*Now we will get the discounts by packageid
do "$code_path/prep_discount_regression_data.do"
*Create datasets with only lender variables that can be merged on later
do "$code_path/prep_dealscan_lender_data.do"

*Collapsing to the quarterly level. Want
*An indicator for whether a loan occured in that package
*The facilityid of the revolving, term, and other loans (the largest ones)
*A discount for observations where it can be estimated
use "$data_path/dealscan_facility_level", clear

foreach type in term rev other {
	egen `type'_max = max(facilityamt) if `type'_loan ==1, by(borrowercompanyid date_quarterly)
	gen facilityid_`type'_max = facilityid if (facilityamt==`type'_max & `type'_loan ==1)
	*This will be the facilityid of the the biggest type of loan in the package (to merge on later)
	egen facilityid_`type' = max(facilityid_`type'_max), by(borrowercompanyid date_quarterly)
	*Want an indicator for whether the package has this type of loan in it
	egen `type'_loan_max = max(`type'_loan), by(borrowercompanyid date_quarterly)	
	drop `type'_max facilityid_`type'_max
}
*br borrowercompanyid loantype facilityamt facilityid facilityid_*

keep borrowercompanyid *_max facilityid_* date_quarterly borrowercompanyid
rename *_max *
duplicates drop
merge 1:1 borrowercompanyid date_quarterly using "$data_path/stata_temp/dealscan_discounts", assert (1 3) nogen
isid borrowercompanyid date_quarterly
save "$data_path/stata_temp/dealscan_quarterly_no_lender", replace

*Merge on lender (need to loop over the two  types of loans and create temporary datasets where I rename
*all variables with suffix of type and then merge the lender data on. Will have 25 x 2 x 3 do I need to keep all
foreach type in term rev {
	use "$data_path/stata_temp/lenders_facilityid_level", clear
	rename * *_`type'
	tempfile lender_temp_`type'
	save `lender_temp_`type''
}
use "$data_path/stata_temp/dealscan_quarterly_no_lender", clear
foreach type in term rev {
	merge m:1 facilityid_`type' using `lender_temp_`type'', keep(1 3) nogen 
}
save "$data_path/dealscan_quarterly", replace
