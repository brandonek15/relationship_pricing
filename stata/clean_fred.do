*Import FRED data
import fred LIOR3M DPRIME FEDFUNDS, daterange(01/01/2001 12/31/2020) aggregate(quarterly,eop) clear
rename *, lower
replace lior3m = fedfunds if mi(lior3m)
gen date_quarterly = qofd(daten)
format date_quarterly %tq
*Need to adjust this and figure out a good way to merge this onto the main data
drop datestr daten
save "$data_path/fred_rates", replace
