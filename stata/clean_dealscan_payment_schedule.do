*Import the payment schedule data - This tells me exactly how the principal will be repaid.
*The sums of the payments add up to the facilityamt
import delimited using "$data_path/dealscan_facilitypaymentscheduledata.csv", clear

sort facilityid begindate

foreach var in begindate {
	gen temp = date(`var',"YMD")
	format temp %td
	drop `var' 
	rename temp `var'
}

gen payment_start_date_quarterly = qofd(begindate )
format payment_start_date_quarterly %tq

merge m:1 facilityid using "$data_path/dealscan_facility_level_no_amort", keep(1 3) keepusing(facilityamt facilitystartdate date_quarterly) nogen

gen num_quarters_first_payment = payment_start_date_quarterly - date_quarterly

*We will have two measures, the first is the number of quarters before the first payment. 
*The second is the amortization (quarterly) of the first payment
/*
*Test
gen product = numberofperiods*payment
collapse (sum) product (first) facilityamt, by(facilityid)
*/

*test

*So we see that

*We can look at just the initial amortization

bys facilityid (begindate): keep if _n ==1

local drop_list in "Irregular" "Unknown" 

foreach drop_type in `drop_list' {
	drop if period == "`drop_type'"
}

*I'm not differentiating by type of payment
gen init_amort = payment/facilityamt*100
label var num_quarters_first_payment "Number of Quarters Before First Payment"
label var init_amort"Initial Amortization of First Payment"

keep facilityid init_amort num_quarters_first_payment period 
rename period payment_period
isid facilityid

save "$data_path/stata_temp/initial_amortization", replace

