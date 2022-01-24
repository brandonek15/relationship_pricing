*Import FRED data
set fredkey "6a2f0d0000f44640d7703bae4ebc5abb", permanently
import fred LIOR3M DPRIME FEDFUNDS, daterange(01/01/2001 12/31/2020) aggregate(quarterly,eop) clear
rename *, lower
replace lior3m = fedfunds if mi(lior3m)
gen date_quarterly = qofd(daten)
format date_quarterly %tq
*Need to adjust this and figure out a good way to merge this onto the main data
drop datestr daten
save "$data_path/fred_rates", replace
