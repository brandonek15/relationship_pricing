*This program runs summary statistics and other simple tables for the paper

*We will do a 20 biggest lenders/underwriters table.
local num_lenders 20
*First we will get the set of "lenders" in both SDC and dealscan (in dealscan only keep lead arrangers)
use "$data_path/lender_facilityid_cusip6", clear
merge m:1 facilityid lender using "$data_path/dealscan_facility_lender_level", ///
keepusing(lead_arranger_credit) keep(1 3) nogen
keep if lead_arranger_credit ==1
drop lead_arranger_credit

append using "$data_path/sdc_deal_bookrunner", gen(type)
bys lender: gen N = _N 
assert type == 0 if mi(sdc_deal_id)
assert type == 1 if mi(facilityid)
gen sdc_deal = (type==0)
gen ds_deal = (type==1)
*Get a list of the "lenders" that are in both
egen total_lender_obs_ds = total(sdc_deal), by(lender)
egen total_lender_obs_sdc = total(ds_deal), by(lender)
keep if total_lender_obs_ds >0 & total_lender_obs_sdc >0
keep lender N
duplicates drop
gsort -N
keep if _n<=`num_lenders'
save "$data_path/stata_temp/top_lenders_`num_lenders'" , replace

*Get the top 20 lead arrangers and their shares of deals
use "$data_path/lender_facilityid_cusip6", clear
merge m:1 facilityid lender using "$data_path/dealscan_facility_lender_level", ///
keepusing(lead_arranger_credit facilityid) keep(1 3) nogen
keep if lead_arranger_credit ==1
drop lead_arranger_credit
*Get the number of facilities with lead arrangers
bys facilityid: gen nvals = _n ==1
replace nvals = sum(nvals)
replace nvals = nvals[_N]
gen count =1
collapse (sum) count (first) nvals, by(lender)
merge 1:1 lender using "$data_path/stata_temp/top_lenders_`num_lenders'", keep (3)  nogen
rename count count_lead_arranger
rename nvals total_facilities
gen perc_deals_la = count_lead_arranger/total_facilities*100
save "$data_path/stata_temp/lenders_counts_`num_lenders'" , replace

*Now get the top 20 issuers
use "$data_path/sdc_deal_bookrunner", clear
*Get the number of facilities with lead arrangers
bys sdc_deal_id: gen nvals = _n ==1
replace nvals = sum(nvals)
replace nvals = nvals[_N]
gen count =1
collapse (sum) count (first) nvals, by(lender)
merge 1:1 lender using "$data_path/stata_temp/lenders_counts_`num_lenders'" , keep (3)  nogen
rename count count_issuer
rename nvals total_issuances
gen perc_deals_issuer = count_issuer/total_issuances*100
rename N total_issuances_loans
gsort -total_issuances_loans
keep lender count_lead_arranger perc_deals_la count_issuer perc_deals_issuer
order lender count_lead_arranger perc_deals_la count_issuer perc_deals_issuer
replace perc_deals_la = round(perc_deals_la,.01)
replace perc_deals_issuer = round(perc_deals_issuer,.01)

label var lender "Bank"
label var count_lead_arranger "Loans as Lead Arranger"
label var perc_deals_la "Percent of Loans as Lead Arranger"
label var count_issuer "Issuances as Bookrunner"
label var perc_deals_issuer "Percent of Issuances as Bookrunner"

replace lender = proper(lender)
replace lender = "JP Morgan" if lender == "Jp Morgan"
replace lender = "RBC" if lender == "Rbc"
replace lender = "UBS" if lender == "Ubs"
replace lender = "BNP Paribas" if lender == "Bnp Paribas"
replace lender = "RBS" if lender == "Rbs"
replace lender = "PNC" if lender == "Pnc"
replace lender = "HSBC" if lender == "Hsbc"
replace lender = "MUFG" if lender == "Mufg"


texsave using "${regression_output_path}/largest_lead_arrangers_issuers_paper.tex", ///
 frag replace varlabels title("Largest Issuers and Lead Arrangers")

********************************************************************************
*Summary stats -> for now one giant table 
*Want the loan level sample to be all loans in the sample
*Want the characteristics sample to be all firm_quarters matched to dealscan
*Want the discount tables to be all firm_quarters with a rev discount and/or bank term discount

*Get loan level sample
use  "$data_path/dealscan_compustat_loan_level", clear
local loan_vars log_facilityamt maturity leveraged fin_cov nw_cov ///
cov_lite spread salesatclose rev_loan b_term_loan i_term_loan other_loan

keep borrowercompanyid date_quarterly discount_obs `loan_vars'
duplicates drop

winsor2 `loan_vars', cuts(.5 99.5) replace
save "$data_path/stata_temp/sumstats_loan_chars", replace


*Get firm characteristics table
use  "$data_path/dealscan_compustat_loan_level", clear
keep if merge_compustat==1
local firm_chars L1_market_to_book L1_ppe_assets L1_current_assets L1_log_assets L1_leverage ///
L1_roa L1_sales_growth L1_ebitda_int_exp ///
L1_working_cap_assets L1_capex_assets L1_firm_age rating_numeric

*Drop duplicate observations
keep borrowercompanyid date_quarterly discount_obs d_1_simple_pos merge_ratings `firm_chars' 
duplicates drop
winsor2 `firm_chars', cuts(.5 99.5) replace
save "$data_path/stata_temp/sumstats_firm_chars", replace

*Get discount obs
use  "$data_path/dealscan_compustat_loan_level", clear
keep if category == "Revolver"
keep borrowercompanyid date_quarterly discount_1_simple discount_1_controls discount_obs
rename discount_1* rev_discount_1*
save "$data_path/stata_temp/rev_discount_obs", replace

use  "$data_path/dealscan_compustat_loan_level", clear
keep if category == "Bank Term"
keep borrowercompanyid date_quarterly discount_1_simple discount_1_controls discount_obs
rename discount_1* term_discount_1*
append using "$data_path/stata_temp/rev_discount_obs"

local discount_vars rev_discount_1_simple rev_discount_1_controls term_discount_1_simple term_discount_1_controls

keep borrowercompanyid date_quarterly discount_obs `discount_vars'
label var rev_discount_1_simple "Revolving Discount - Simple"
label var rev_discount_1_controls "Revolving Discount - Controls"
label var term_discount_1_simple "Bank Term Discount - Simple"
label var term_discount_1_controls "Bank Term Discount - Controls"

winsor2 `discount_vars', cuts(.5 99.5) replace
save "$data_path/stata_temp/sumstats_discount_chars", replace

*Append all the samples together
use "$data_path/stata_temp/sumstats_loan_chars", clear
append using "$data_path/stata_temp/sumstats_firm_chars"
append using "$data_path/stata_temp/sumstats_discount_chars"

*Create the big summary stats table
estpost tabstat `loan_vars' `firm_chars' `discount_vars', s(p5 p25 p50 p75 p95 mean sd count) c(s)
esttab . using "$regression_output_path/sumstats_all_paper.tex", ///
 label title("Summary Statistics for Loans, Firm Characteristics, and Discounts") replace ///
cells("p25(fmt(3)) p50(fmt(3)) p75(fmt(3)) mean(fmt(2)) sd(fmt(2)) count(fmt(0))") ///
nomtitle  noobs
/*note("Loan sample contains all loans in Dealscan" ///
"Firm characteristics sample contains all firm quarters matched to Dealscan loans" ///
"Discount sample contains all loans where a discount was computed")
*/

*I want difference tables
*For loan level, I want it to be discount obs vs non-discount obs
*For firm charactersitics, I want it to be discount obs vs non-discount obs
*No difference in means for compustat vs non-compustat

eststo: estpost ttest `loan_vars' `firm_chars' , by(discount_obs) unequal
	
esttab . using "$regression_output_path/differences_all_discount_obs.tex", ///
 label title("Loan and firm characteristics for observations where discounts are calculated and those that are not") replace ///
cells("mu_2(fmt(3)) mu_1(fmt(3)) b(star)") collabels("Disc Obs" "Non Disc Obs" "Difference") ///
 noobs eqlabels(none) addnotes("Discount Obs is an observation where a discount is calculated" ///
 "This occurs when a firm x quarter has both an institutional term loan and a revolver and/or a bank term loan") 
