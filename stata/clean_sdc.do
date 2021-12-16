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

*Todo clean the names of the issuers and bookrunners
save "$data_path/sdc_equity_clean", replace

*Import SDC debt data
import delimited using "$data_path/sdc_debt_issuance_all.csv", varnames(1) clear
