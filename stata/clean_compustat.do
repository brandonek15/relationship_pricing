*Import the merged data
import delimited using "$data_path/compustat_merge.csv", clear

*Go get the list of unique matches of bcoid and gvkey
preserve
keep gvkey bcoid
drop if mi(bcoid)
duplicates drop
save "$data_path/stata_temp/gvkey_bcid_pairs", replace

restore

drop bcoid
duplicates drop


*xtset the data by getting a good date variable and getting rid of duplicates
foreach var in datadate rdq ipodate {
	gen temp = date(`var',"YMD")
	format temp %td
	drop `var' 
	rename temp `var'
}

*If missing fiscal quarter, replace it with the quarter of the financials
gen qrt_fin = quarter(rdq)
gen mi_fqtr = mi(fqtr)
replace fqtr = qrt_fin if mi(fqtr)
drop qrt_fin

bys gvkey fyearq fqtr (mi_fqtr): gen N = _N
*If one of the observations are a duplicate because it was filled in, drop it
drop if N>1 & mi_fqtr
drop N mi_fqtr
*If still have duplicates, keep the later finacials date and if they are tied, get one with greater assets
bys gvkey fyearq fqtr (rdq atq): keep if _n == _N
*Make fiscal year data quarterly.
gen fdate = yq(fyearq,fqtr)
format fdate %tq
label var fdate "Fiscal Quarterly Date"
isid gvkey fdate
*Now I have a company id x quarter dataset.
*Generate quarterly variables from the yearly variables
xtset gvkey fdate
foreach yearly_var in capx xrd prstkc aqc dv {
	gen temp_diff = `yearly_var'y - L1.`yearly_var'y
	gen `yearly_var'q = `yearly_var'y if fqtr ==1
	replace `yearly_var'q = temp_diff if fqtr >1
	drop temp_diff
}
*Drop ytd variables
drop capxy xrdy prstkcy aqcy dvy
*Drop unneccesary variable
drop fqtr fyearq
*Won't approximate observations for which I don't have fqtr1.

*Label current variables and create new ones.
label var atq "Total Book Assets"
label var seqq "Total Stockholders Equity"
label var chq "Cash"
label var cheq "Cash and Short-Term Inv"
label var ltq "Liabilities"
label var dlcq "Debt in Current Liabilities"
label var dlttq "Long-Term Debt"
label var gdwlq "Goodwill"
label var mkvaltq "Market Value"
label var oibdpq "Operating Income Before Dep"
label var nopiq "Non-Operating Income"
label var niq "Net Income"
label var revtq "Total Revenue"
label var cogsq "Cost of Goods Sold"
label var wcapq "Working Capital"
label var capxq "Capital Expenditures"
label var aqcq "Aquisitions"
label var dvq "Dividends"
label var prstkcq "Share Repurchases"
label var xsgaq "Selling, General, and Admin Expenses"
label var saleq "Sales"
label var ppentq "Property, Plant, and Equipment, Net"
label var xrdq "Research and Development"
label var actq "Current Assets"
label var lctq "Current Liabilities"
label var actq "Current Assets"
label var xintq "Interest Expense"
label var intanq "Intangible Assets"
label var xrdq "Research and Development Expenses"
label var rdq "Report Date of Quarterly Earnings"
*Add more labels

*Create lagged assets
gen L1_atq = L1.atq
label var L1_atq "L1 Assets"

*Create common variables - Controls
gen log_assets = log(atq)
label var log_assets "Log(assets)"
gen leverage = (dlcq + dlttq)/(dlcq + dlttq+ceqq)
label var leverage "Book Leverage"
*Not using CRSP compustat Data
*Market value = book assets - book equity + market equity + prefered shareholder equity
gen market_value = atq - seqq + pstkq + (prccq*cshoq)
gen market_to_book = market_value/atq
label var market_to_book "Market / Book"
gen sales_growth = (saleq-L4.saleq)/L4.saleq*100
label var sales_growth "Annual Sales Growth"
gen log_sales = log(saleq)
label var log_sales "Log(sales)"
gen quick_ratio = actq/lctq
label var quick_ratio "Quick Ratio"
gen current_assets = actq/atq
label var current_assets "Current Assets/Assets"

*Int Coverage Ratio - (EBITDA) to int expense
gen ebitdaq = saleq - cogsq -xsgaq
label var ebitdaq "EBITDA"
gen ebitda_int_exp = ebitdaq/xintq
label var ebitda_int_exp "EBITDA / Interest Expense"

*Create "Ineffecient activies" financial ratios
gen cash_assets = csh/atq
label var cash_assets "Cash/Assets"
*Drop bad observations
gen acq_assets = xrdq/atq
label var acq_assets "Acquisitions/Assets"
gen shrhlder_payout = dvq + prstkcq
label var shrhlder_payout "Dividends + Share Repurchases"
gen shrhlder_payout_assets = shrhlder_payout/atq
label var shrhlder_payout_assets "(Div + Share Repurchases)/Assets"

*Create "Effecient capital allocations ratios
gen working_cap_assets = wcapq/atq
label var working_cap_assets "Working Capital/Assets"
gen capex_assets = capxq/atq
label var capex_assets "Capital Expenditures/Assets"
gen ppe_assets = (ppentq)/atq
label var ppe_assets "PPE/Assets"

*Create firm performance ratios
gen roa = ibq/L1.atq
label var roa "ROA"
gen ebitda_assets = ebitdaq/atq
label var ebitda_assets "EBITDA/Assets"
gen sga_assets = xsgaq/atq
label var sga_assets "Selling, General, and Admin Exp./Assets"

*Create 2-digit SIC code
gen temp = sic
tostring temp, replace
gen sic_2 =  substr(temp,1,2)
destring sic_2, replace
drop temp

*Also create a quarterly ipo date
gen ipodate_quarterly = qofd(ipodate)
format ipodate_quarterly %tq
*Create a variabel for firm age
gen firm_age = (datadate - ipodate)/365.25
label var firm_age "Firm Age (yrs)"

*Create the changes variables 4,8,12 quarters.
foreach change_var in  $comp_outcome_vars {
	 
	 forval delta = 4(4)12 {
		gen FD`delta'_`change_var' = F`delta'.`change_var' - `change_var'
		local label: variable label `change_var'
		label var FD`delta'_`change_var' "FD`delta' `label'"
	 }
} 

*Create lagged characteristics variables
foreach char_var in $comp_char_vars {
	gen L1_`char_var' = L1.`char_var'
	local label: variable label `char_var'
	label var L1_`char_var' "L1 `label'"
}

*Clear the xtset because I want the dataset to be based on true date, not fiscal date
xtset, clear

*Create a panel with the true date
gen date_quarterly = qofd(datadate)
format date_quarterly %tq
label var date_quarterly "Quarterly Date"

*When there is a duplicated, it is because there are mutliple fdate. in this case,
*usually match up, but earlier fiscal date is more populated
bys gvkey date_quarterly (fdate): keep if _n == 1

*Now merge on ratings
merge 1:1 gvkey date_quarterly using "$data_path/gvkey_ratings", keep(1 3)
gen merge_ratings = _merge ==3
label var merge_ratings "Rated Firm"
drop _merge

label var gvkey "Compustat Company ID"
*Get 6 digit cusip for mering
gen cusip_6 = substr(cusip,1,6)
*Drop obs without cusip_6
drop if mi(cusip_6)

*Need to have multiple unique identifiers: gvkey date_quarterly, cusip_6 date_quarterly
isid gvkey date_quarterly
*Could look at each case individually and choose, but instead I will just keep the biggest one
bys cusip_6 date_quarterly (atq): keep if _n ==_N

*Now do a left join to get
joinby gvkey using "$data_path/stata_temp/gvkey_bcid_pairs", unmatched(master)
drop _merge

*Rename borrower Company ID for dealscan merge
rename bcoid borrowercompanyid
label var borrowercompanyid "Dealscan Borrower Company ID"
*And also need to be able to merge on dealscan data that won't have a unique borrowercompanyid

*Figure stuff out here! For some reason we don't have borrowercompanyid
*Sometimes two compustat firms have the same borrowercompanyid
*When this happens, keep the one with the higher assets and if they are still tied, the one with the larger cik
*What I will do is save two datasets and then append back together. 1st is those with borrowercompanyid and then those without
preserve
drop if mi(borrowercompanyid)
bys borrowercompanyid date_quarterly (atq cik): keep if _n == _N
isid borrowercompanyid date_quarterly
save "$data_path/stata_temp/compustat_with_bcid", replace
restore

preserve 
keep if mi(borrowercompanyid)
save "$data_path/stata_temp/compustat_without_bcid", replace
restore
use "$data_path/stata_temp/compustat_without_bcid", clear
append using "$data_path/stata_temp/compustat_with_bcid"
*Now if I have a borrowercompanyid, then it is unique by quarter

*Now I have a proper panel
save "$data_path/compustat_clean", replace
