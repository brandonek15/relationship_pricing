*Get the facility level data
use "$data_path/dealscan_facility_level", clear
*Keep only observations with both a term loan and a revolving loan
egen max_revolving_credit = max(revolving_credit), by(packageid)
egen max_term_loan = max(term_loan), by(packageid)
keep if max_revolving_credit == 1 & max_term_loan ==1
drop max_revolving_credit max_term_loan

*egen groupby?

*This is too slow, think of another way
*Now need to create an indicator for every faciliy id * the indicator for revolving credit
levelsof facilityid, local(facilityids)
foreach facid of local facilityids {
	gen fac_rev_`facid' = (facilityid==`facid' & revolving_credit ==1)
}

*What if I instead use facilityid x revolving fixed effects.
*This gives me an indicator for facility id x  revolving and facilityid x term. The difference
*Between the two will give me the "discount"

*What I want is deal fixed effects and dealFE * revolving indicators
