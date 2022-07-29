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
replace lender = "US Bancorp" if lender == "Us Bancorp"


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
	
esttab . using "$regression_output_path/differences_all_discount_obs_paper.tex", ///
 label title("Loan and firm characteristics for observations where discounts are calculated and those that are not") replace ///
cells("mu_2(fmt(3)) mu_1(fmt(3)) b(star)") collabels("Disc Obs" "Non Disc Obs" "Difference") ///
 noobs eqlabels(none) addnotes("Discount Obs is an observation where a discount is calculated" ///
 "This occurs when a firm x quarter has both an institutional term loan and a revolver and/or a bank term loan") 

*Make a data dictionary 
clear
set obs 24
gen var = ""
gen desc = ""
label var var "Variable"
label var desc "Description"
replace var = "Log Facility Amount" if _n ==1
replace desc = "Log of the amount on the loan facility" if _n==1
replace var = "Maturity" if _n ==2
replace desc = "Maturity in months" if _n==2
replace var = "Leveraged Loan" if _n ==3
replace desc = "An indicator for whether the loan is classified as leveraged in Dealscan" if _n==3
replace var = "Contains Financial Covenants" if _n==4
replace desc = "Indicator of whether the loan has financial covenants" if _n==4
replace var = "Net Worth Covenants" if _n==5
replace desc = "Indicator of whether the loan has net worth covenants" if _n==5
replace var = "Cov-Lite" if _n==6
replace desc = "Indicator for whether the loan is classified as Cov-lite in Dealscan" if _n==6
replace var = "Spread" if _n==7
replace desc = "Spread over LIBOR of the loan facility" if _n==7
replace var = "Annual Sales (millions)" if _n==8
replace desc = "Annual sales of the firm in millions as of the start date of the loan" if _n==8
replace var = "Revolver" if _n==9
replace desc = "Indicator for a revolving line of credit" if _n==9
replace var = "Bank Term Loan" if _n==10
replace desc = "Indicator for bank term loan" if _n==10
replace var = "Inst. Term Loan" if _n==11
replace desc = "Indicator for an institutional term loan" if _n==11
replace var = "Other Loan" if _n==12
replace desc = "Indicator for any other type of loan" if _n==12
replace var = "L1 Market / Book" if _n==13
replace desc = "Lagged Market Value / Book Assets ; [atq - seqq + pstkq + (prccq*cshoq)]/atq)" if _n==13
replace var = "L1 PPE / Assets" if _n==14
replace desc = "Lagged Property, Plant, and Equipment / Assets ; ppentq/atq" if _n==14
replace var = "L1 Current Assets / Assets" if _n==15
replace desc = "Lagged Current Assets / Assets ; actq/atq" if _n==15
replace var = "L1 Log(assets)" if _n==16
replace desc = "Lagged Log of Book Assets" if _n==16
replace var = "L1 Book Leverage" if _n==17
replace desc = "Lagged Debt/ (Debt + Equity) ;(dlcq + dlttq)/(dlcq + dlttq+ceqq)" if _n==17
replace var = "L1 ROA" if _n==18
replace desc = "Lagged Return on Assets ; ibq/L1.atq" if _n==18
replace var = "L1 Annual Sales Growth" if _n==19
replace desc = "Lagged Annual Sales Growth ; (saleq-L4.saleq)/L4.saleq*100" if _n==19
replace var = "L1 EBITDA / Interest Expense" if _n==20
replace desc = "Lagged EBITDA / Interest Expense ; ebitdaq/xintq" if _n==20
replace var = "L1 Working Capital/Assets" if _n==21
replace desc = "Lagged Working Capital / Assets ; wcapq/atq" if _n==21
replace var = "L1 Capital Expenditures / Assets" if _n==22
replace desc = "Lagged Capital Expenditures / Assets ; capxq/atq" if _n==22
replace var = "L1 Firm Age (yrs)" if _n==23
replace desc = "Lagged Years Between Observation and IPO data; (datadate - ipodate)/365.25" if _n==23
replace var = "Credit Rating" if _n==24
replace desc = "S and P Credit Rating of the Firm at Time of Origination. Credit rating converted to numerical scale, with AAA=1 and D=22 " if _n==24

texsave using "$regression_output_path/variable_definitions.tex", ///
 frag replace varlabels title("Variable Definitions")
