cap program drop clean_sdc
program define clean_sdc
	args type
	*Todo, make this cleaning a function that takes in a string as an input  
	local numeric_vars_equity shares_offered_local prim_shares_offered_local ///
	sec_shares_offered_local shares_offered_global yest_stock_price stock_price_close_offer ///
	perc_owned_before_spinoff perc_owned_after_spinoff shares_desc
	 
	local numeric_vars_debt coupon offer_ytm	
	
	if "`type'" == "equity" {
		local add_list `numeric_vars_equity'
	}
	else if "`type'" == "debt" {
		local add_list `numeric_vars_debt'
	}
	
	local numeric_vars gross_spread_per_unit management_fee_dol underwriting_fee_dol ///
	 selling_conc_dol reallowance_dol gross_spread_perc management_fee_perc underwriting_fee_perc ///
	 selling_conc_perc reallowance_perc gross_spread_dol principal_local principal_global ///
	 proceeds_local proceeds_global offer_price orig_price_high orig_price_low  ///
	 orig_price_mid shares_filed_local shares_filed_global amt_filed_local amt_filed_global ///
	`add_list'
	
	local millions_vars management_fee_dol underwriting_fee_dol selling_conc_dol reallowance_dol ///
	 gross_spread_dol principal_local principal_global proceeds_local proceeds_global

	local fee_vars management_fee_dol underwriting_fee_dol management_fee_perc underwriting_fee_perc
	gen comb_fees = 0
	label var comb_fees "Combined Fee Structure"

	foreach fee_var in `fee_vars' {
		replace comb_fees = 1 if regex(`fee_var',"Comb.")
	}

	foreach num_var in `numeric_vars' {
		replace `num_var' = subinstr(`num_var',",","",.)
		destring `num_var', replace force
	}
	
	foreach mil_var in `millions_vars' {
		replace `mil_var' = `mil_var'*1000000
	}


	*Need to be able to merge on the CUSIPs - will be merging based off of the ultimate parent
	gen cusip_6 = parent_ultimate_cusip_6 
	*Need to have cusip_6
	drop if mi(cusip_6)
	*Drop government agencies
	drop if regex(sic,"999[A-Z]+")
	*Drop financials (SIC codes 6000-6999)
	destring sic, force replace
	*Also drop government agencies (which are missing SIC code)
	drop if inrange(sic,6000,6999)

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

	*Keep only deals done in dollars (can adjust this later)
	keep if currency == "US" | mi(currency)
	*Create categories of deal
	gen public = (regex(marketplace,"Public") | regex(marketplace,"Shelf") ///
	 | regex(marketplace,"Registration") | regex(marketplace,"Universal"))
	gen private = (regex(marketplace,"Private"))
	gen withdrawn = (marketplace == "Withdrawn")
	
	*Todo clean the names of the issuers and bookrunners
	*Standardize SDC
	do "$code_path/standardize_sdc.do"
	standardize_bookrunners
	*Create a variable for each manager
	di "about to split"
	split bookrunners, gen(bookrunner_) parse("/")
	di "finished splitting"

end

*Import SDC equity data
import delimited using "$data_path/sdc_equity_issuance_all.csv", varnames(1) clear

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

*Generate indicators for the three types of securities
gen equity = 1
replace equity = 0 if regex(sec_type,"Cvt")
replace equity = 0 if regex(sec_type,"Conv")
replace equity = 0 if regex(sec_type,"Debt Sec")
gen debt =  (regex(sec_type,"Debt Sec"))
gen conv = (equity ==0 & debt ==0)

*create an IPO indicator
gen ipo = (ipo_ind == "Yes")
drop ipo_ind

*Then run the both cleaning program
clean_sdc "equity"

*Want to create a variable for number of units (usually shares)
*First rely on shares from the desc, then fill it in sequentialy if missing
gen num_units = shares_desc 
replace num_units = shares_offered_local if missing(num_units)

preserve
keep if equity ==1
save "$data_path/sdc_equity_clean", replace
restore

preserve
keep if conv ==1
*There are no convertable obs for these vars
drop bookrunner_13-bookrunner_16
save "$data_path/sdc_conv_clean", replace
restore


*Import SDC debt data
import delimited using "$data_path/sdc_debt_issuance_all.csv", varnames(1) clear

gen debt = 1
gen equity = 0
replace debt =  0 if regex(sec_type,"Cvt")
gen conv = (debt==0 & equity==0)
clean_sdc "debt"
gen num_units = amt_filed_local
replace num_units = shares_filed_local if mi(num_units)
gen ipo = 0
save "$data_path/sdc_debt_clean", replace

/*
use "$data_path/sdc_equity_clean", clear
*/
foreach date_type in "quarterly" "daily" {
	foreach type in "equity" "conv" "debt" {

		use "$data_path/sdc_`type'_clean", clear

		local max_vars ipo equity debt conv public private withdrawn
		local last_vars issuer business_desc currency bookrunner* all_managers desc
		local sum_vars management_fee_dol underwriting_fee_dol selling_conc_dol ///
			reallowance_dol gross_spread_dol proceeds_local num_units
		local mean_vars gross_spread_per_unit gross_spread_perc management_fee_perc underwriting_fee_perc ///
			selling_conc_perc reallowance_perc 
		local weight_var proceeds_local

		collapse (rawsum) `sum_vars' (max) `max_vars' (last) `last_vars' ///
			(mean) `mean_vars' [aweight=`weight_var'], by(cusip_6 date_`date_type')

		foreach var in `sum_vars' `mean_vars' {
			replace `var' = . if `var' ==0
		}

		rename proceeds_local proceeds
		*Only do this for quarterly
		if "`date_type'" == "quarterly" {
			*Rename these so we can have different sets of these variables
			rename * *_`type'
			*For these variables, they are common accross the datasets
			foreach remove_type_var in cusip_6 date_`date_type' equity conv debt {
				rename `remove_type_var'_`type' `remove_type_var'
			}
		}
		*Most important variables: The gross spread_percent, gross_spread_dollar, the proceeds, the cusip_6 and the date_quarterly
		*From here I have whether there is a deal (make an indicator for whether it gets merged on?
		*And then I also have data on the "price" and the size
		isid cusip_6 date_`date_type'
		save  "$data_path/sdc_`type'_clean_`date_type'", replace

	}
}
*Make both an "all sdc clean dataset" where every deal is an observation and has an identifier
use "$data_path/sdc_equity_clean_daily", clear
append using "$data_path/sdc_conv_clean_daily"
append using "$data_path/sdc_debt_clean_daily"
*Add date_quarterly for relationship states
gen date_quarterly = qofd(date_daily)
format date_quarterly %tq
label var date_quarterly "Quarterly Date"
*Need to choose a set of variables that will give me the exact same sort every time so the index is a proper id
sort cusip_6 date_daily desc proceeds
gen log_proceeds = log(proceeds)
gen sdc_deal_id = _n
save "$data_path/stata_temp/sdc_all_clean_temp", replace

*******************************************************************************************
*Make a long dataset that is one observation per bookrunner x deal - this will be used for
*First load program that cleans dealscan to apply the same cleaning here as well
do "$code_path/standardize_sdc.do"
use "$data_path/stata_temp/sdc_all_clean_temp", clear
sdc_wide_to_long

*a joinby on name of bookrunner (will have minimal information and can merge on sdc_all_clean later)
preserve
	keep sdc_deal_id cusip_6 lender
	save "$data_path/sdc_deal_bookrunner", replace
restore

*Create the relationship states for sdc
*This code was adjusted from clean_dealscan
*This should work

isid sdc_deal_id lender
gen prev_lender = 0
drop if mi(cusip_6)
*Say you were a previous lender if you were the same lender to the same firm earlier
*Or if you were previoulsy a previous lender
bys cusip_6 lender (date_quarterly sdc_deal_id): replace prev_lender = 1 if lender[_n] == lender[_n-1] & date_quarterly[_n] != date_quarterly[_n-1]
bys cusip_6 lender (date_quarterly sdc_deal_id): replace prev_lender = 1 if prev_lender[_n-1] == 1
egen max_prev_lender = max(prev_lender), by(sdc_deal_id)
*br sdc_deal_id cusip_6 lender prev_lender max_prev_lender date_quarterly
sort cusip_6 sdc_deal_id date_quarterly

*Create three categories - first loans 
egen min_date_daily = min(date_daily), by(cusip_6)
format min_date_daily %td
*br sdc_deal_id cusip_6 date_quarterly min_date_quarterly
sort cusip_6 date_daily
gen first_loan = date_daily == min_date_daily
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

save "$data_path/sdc_deal_bookrunner_level", replace

*Now save a version that is at the deal level. This will drop observations that don't have a known bookrunner.
drop lender
duplicates drop
isid sdc_deal_id
save "$data_path/sdc_all_clean", replace
