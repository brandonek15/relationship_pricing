*Preparing the lender data to get merged on later.
*Measuring who gets the relationship benefits
use "$data_path/dealscan_facility_lender_level", clear
keep facilityid lender lenderrole bankallocation agent_credit lead_arranger_credit
rename bankallocation loan_share
rename lenderrole role
isid facilityid lender
save "$data_path/dealscan_lender_level", replace

use "$data_path/dealscan_lender_level", clear
gsort facilityid -loan_share -agent_credit -lead_arranger_credit
*The biggest ones have the lowest numbers - then if many are missing, want to keep those that get agent credit and lead arranger credit
by facilityid: gen n = _n
*To keep data small, I will keep only 25, thought this will drop 40k/1.65m obs (but make data 12x smaller)
keep if n <=25
*Want to make this dataset so facilityid is a unique identifier
keep lender role loan_share facilityid n
reshape wide lender role loan_share, i(facilityid) j(n)
save "$data_path/stata_temp/lenders_facilityid_level", replace

*Make loan dataset -- cusip_6 x facilityid for merge
*Do the reshape and standardize
use "$data_path/dealscan_facility_lender_level", clear
*only keeping observations that I can merge on a cusip_6, which are those that can match to compustat.
merge m:1 borrowercompanyid date_quarterly using "$data_path/stata_temp/compustat_with_bcid", keep(1 3) keepusing(cusip_6) nogen
*Spread Cusip_6 by borrowercompanyid
*Implicitly assuming that the cusip_6 for the borrowercompanyid will be the same as it would be in the future
bys borrowercompanyid (date_quarterly): replace cusip_6 = cusip_6[_n+1] if mi(cusip_6)
keep if !mi(cusip_6)
*Now keep the lender data we care about in the merge
keep cusip_6 lender facilityid
save "$data_path/lender_facilityid_cusip6", replace
