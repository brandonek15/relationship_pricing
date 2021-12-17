*Import SDC equity data
import delimited using "$data_path/sdc_equity_issuance_all.csv", varnames(1) clear

local numeric_vars gross_spread_per_unit management_fee_dol underwriting_fee_dol ///
 selling_conc_dol reallowance_dol gross_spread_perc management_fee_perc underwriting_fee_perc ///
 selling_conc_perc reallowance_perc gross_spread_dol principal_local principal_global ///
 proceeds_local proceeds_global offer_price orig_price_high orig_price_low ///
 orig_price_mid shares_filed_local shares_filed_global amt_filed_local amt_filed_global ///
 shares_offered_local prim_shares_offered_local sec_shares_offered_local shares_offered_global ///
 yest_stock_price stock_price_close_offer perc_owned_before_spinoff perc_owned_after_spinoff
 

local fee_vars management_fee_dol underwriting_fee_dol management_fee_perc underwriting_fee_perc
gen comb_fees = 0
label var comb_fees "Combined Fee Structure"

foreach fee_var in `fee_vars' {
	replace comb_fees = 1 if regex(`fee_var',"Comb.")
}

*stock_price_close_offer is messed up for some observation bc it was truncated, make an ind
gen stock_price_close_offer_trun = !regexm(stock_price_close_offer,"\.")
replace stock_price_close_offer_trun = 0 if mi(stock_price_close_offer)
label var stock_price_close_offer_trun "Truncated stock price at close"

*Get number of shares form desc
gen temp = desc
replace temp = regexr(temp,"'[0-9]+$","") 
replace temp = regexr(temp,"[0-9.]+\%","")
gen shares_desc = regexs(0) if(regexm(temp,"[0-9,]+"))
drop temp

foreach num_var in `numeric_vars' shares_desc {
	replace `num_var' = subinstr(`num_var',",","",.)
	destring `num_var', replace force
}

*Need to be able to merge on the CUSIPs - will be merging based off of the ultimate parent
gen cusip_6 = parent_ultimate_cusip_6 

*Create a date to merge on with
gen month = substr(issue_date,1,2)
gen date = substr(issue_date,4,2)
gen year = "20" + substr(issue_date,7,2)
destring month date year, replace
gen date_daily = mdy(month,date,year)
format date_daily %td
gen date_quarterly = qofd(date_daily)
format date_quarterly %tq
label var date_quarterly "Quarterly Date"
drop month date year issue_date

*create an IPO indicator
gen ipo = (ipo_ind == "Yes")
drop ipo_ind

*Want to create a variable for number of units (usually shares)
*First rely on shares from the desc, then fill it in sequentialy if missing
gen num_units = shares_desc 
replace num_units = shares_offered_local if missing(num_units)

*Want to seperate convertable bonds to another dataset and then merge it on later?
gen equity = 1
replace equity = 0 if regex(sec_type,"Cvt")
replace equity = 0 if regex(sec_type,"Conv")
replace equity = 0 if regex(sec_type,"Debt Sec")
gen debt =  (regex(sec_type,"Debt Sec"))
gen conv = (equity ==0 & debt ==0)

*Todo clean the names of the issuers and bookrunners

preserve
keep if equity ==1
save "$data_path/sdc_equity_clean", replace
restore

preserve
keep if conv ==1
save "$data_path/sdc_conv_clean", replace
restore

foreach type in "equity" "conv" {
	use "$data_path/sdc_`type'_clean", clear

	local collapse_vars sec_type
	local max_vars ipo equity debt conv
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
	*Rename these so we can have different sets of these variables
	foreach var of varlist management_fee_dol-reallowance_perc {
		rename `var' `var'_`type'
	}
	*Most important variables: The gross spread_percent, gross_spread_dollar, the proceeds, the cusip_6 and the date_quarterly
	*From here I have whether there is a deal (make an indicator for whether it gets merged on?
	*And then I also have data on the "price" and the size
	save  "$data_path/sdc_`type'_clean_quarterly", replace
	isid cusip_6 date_quarterly

}


*Import SDC debt data
import delimited using "$data_path/sdc_debt_issuance_all.csv", varnames(1) clear
