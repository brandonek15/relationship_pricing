
* Clean CDS Spreads
foreach v in "" "_name" {
	di "`v'"
	import delimited "$data_path/all_cds_spreads`v'.csv", clear
	gen date_quarterly = qofd(date(date,"YMD"))
	drop if mi(redcode) | mi(cusip_6)
	format date_quarterly %tq

	gen x = (docclause == "XR14" ) | (docclause == "XR14")
	egen y = max(x), by(redcode date_quarterly)
	drop if x == 0 & y ==1
	drop if (y==0 & (docclause == "MR" | docclause == "MR14"))
	gen x2 = inlist(docclause,"CR","CR14")
	egen y2 = max(x2), by(redcode date_quarterly)
	drop if x2==0 & y2==1
	drop x x2 y y2
	duplicates drop date_quarterly redcode, force

	egen cds_spread_mean = rowfirst(parspread_mean convspread_mean)
	egen cds_spread_median = rowfirst(parspread_median convspread_median)
	drop if mi(cds_spread_mean) & mi(cds_spread_median)

	save "$data_path/cds_spreads_cleaned`v'.dta", replace
}


* Join to CDS Spreads
use "$data_path/stata_temp/dealscan_discounts_facilityid", clear
 
* Drop missing spreads
drop if mi(spread)
drop if mi(cusip_6)

// preserve
// keep cusip_6 company
// duplicates drop 
// tempfile key 
// save `key', replace
// restore

* Collapse data to borrower - date - loantype level
collapse (mean) spread, by(borrowercompanyid category date_quarterly cusip_6)

gen loan_type = "other"
replace loan_type = "rev" if category == "Revolver"
replace loan_type = "bank" if category=="Bank Term"
replace loan_type = "institutional" if category=="Inst. Term"
keep date_quarterly borrowercompanyid cusip_6 spread loan_type

* Reshape data so it is identified by borrower - loantype
reshape wide spread, i(borrowercompanyid date_quarterly cusip_6) j(loan_type) string

* Merge together Spreads with CDS Spreads
joinby cusip_6 date_quarterly using "$data_path/cds_spreads_cleaned_name.dta", unmatched(master)

keep if _merge ==3
drop _merge

*Merge on the discount data
merge 1:1 borrowercompanyid date_quarterly using "$data_path/stata_temp/dealscan_discounts", nogen

corr cds_spread_mean spreadrev
corr cds_spread_mean spreadinstitutional
corr cds_spread_mean spreadbank


// keep if _merge == 1
// drop _merge
// joinby  cusip_6 using `key', unmatched(none)


* Run Regressions

foreach var of varlist cds_spread_mean cds_spread_median {
	replace `var' = `var'*1000
}

* Run Regressions
eststo clear
eststo: reg cds_spread_mean spreadrev spreadinstitutional 
eststo: reg cds_spread_mean spreadbank spreadinstitutional

eststo: reg cds_spread_median spreadrev spreadinstitutional
eststo: reg cds_spread_median spreadbank spreadinstitutional

label var spreadrev "Revolving Loan Spread"
label var spreadbank "Bank Term Loan Spread"
label var spreadinstitutional "Institutional Term Loan Spread"

#de ;
	esttab * using "$regression_output_path/cds_spread_regs.tex", se b(3) label replace tex 
	nodepvars nonumbers nomtitles
	drop(_cons) order(spreadrev spreadbank)
		title("CDS Spreads vs. Loan Spreads")
				mgroups("Mean CDS" "Median CDS" , pattern(1 0 1 0 )
				prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span}))
				stats( r2 N , label("$ R^2$" "$ N $ ")
					fmt(%9.2f %12.0gc))
					;
#de cr;

				
/*				
reg cds_spread_mean  spreadinstitutional spreadrev
reg cds_spread_mean spreadinstitutional rev_discount_1_simple

reg cds_spread_mean spreadinstitutional spreadbank 
reg cds_spread_mean spreadinstitutional term_discount_1_simple

reg cds_spread_mean  spreadinstitutional spreadrev spreadbank
reg cds_spread_mean spreadinstitutional rev_discount_1_simple term_discount_1_simple


