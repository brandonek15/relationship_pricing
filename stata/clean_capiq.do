*Clean CapitalIQ
*Import the merged data
import delimited using "$data_path/capiq_merge.csv", clear

foreach var in ratingdate {
	gen temp = date(`var',"YMD")
	format temp %td
	drop `var' 
	rename temp `var'
}

*Want to end up with a gvkey by quarter dataset.
keep gvkey ratingdate ratingsymbol
drop if mi(gvkey) | ratingsymbol == "NR" | ratingsymbol =="R"
replace ratingsymbol = "D" if ratingsymbol == "SD"
*Replace some weird ratings 
foreach weird_str in "/A-1" "/A-2" "/A-3" "/NR" "/A" {
	replace ratingsymbol = regexr(ratingsymbol,"`weird_str'","")
}

label def Rating 1 "AAA" 2 "AA+" 3 "AA" 4 "AA-" 5 "A+"  6 "A"  7 "A-"  8 "BBB+"  9 "BBB" 10 "BBB-"  11 "BB+" ///
		12 "BB" 13 "BB-" 14 "B+" 15 "B"  16 "B-" 17 "CCC+" 18 "CCC" 19 "CCC-" 20 "CC" 21 "C" 22 "D"
encode ratingsymbol, label(Rating) gen(rating_numeric)
label var rating_numeric "Credit Rating"

*Create an investment grade indicator
gen investment_grade = rating_numeric<=10
label var investment_grade "Investment Grade Issuer"

gen date_quarterly = qofd(ratingdate)
format date_quarterly %tq
label var date_quarterly "Quarterly Date"
*Keep the latest rating in a quarter
bys gvkey date_quarterly (ratingdate): keep if _n == _N
drop ratingdate
egen min_date_quarterly = min(date_quarterly), by(gvkey)
egen max_date_quarterly = max(date_quarterly), by(gvkey)

save "$data_path/stata_temp/gvkey_ratings_base", replace

use "$data_path/stata_temp/gvkey_ratings_base", clear
keep date_quarterly gvkey
qui sum date_quarterly
local min_date = `r(min)'
local max_date = `r(max)'
local num_obs_expand = `max_date'-`min_date' 
keep gvkey
duplicates drop
expand `num_obs_expand'
gen date_quarterly = `min_date'
bys gvkey: replace date_quarterly = date_quarterly + _n -1
format date_quarterly %tq

merge 1:1 gvkey date_quarterly using "$data_path/stata_temp/gvkey_ratings_base", keep(1 3) nogen
xtset gvkey date_quarterly

foreach backfill in ratingsymbol investment_grade rating_numeric min_date_quarterly max_date_quarterly {
	bys gvkey (date_quarterly): replace `backfill' = `backfill'[_n-1] if mi(`backfill')
}
drop if date_quarterly < min_date_quarterly | date_quarterly >max_date_quarterly | mi(ratingsymbol)
drop min_date_quarterly max_date_quarterly
drop ratingsymbol

save "$data_path/gvkey_ratings", replace
