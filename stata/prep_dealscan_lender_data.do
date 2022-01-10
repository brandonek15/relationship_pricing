*Preparing the lender data to get merged on later.
*Measuring who gets the relationship benefits
use "$data_path/dealscan_facility_lender_level", clear
keep facilityid lender lenderrole bankallocation agentcredit leadarrangercredit
rename bankallocation loan_share
rename lenderrole role
isid facilityid lender
save "$data_path/dealscan_lender_level", replace

use "$data_path/dealscan_lender_level", clear
gsort facilityid -loan_share -agentcredit -leadarrangercredit
*The biggest ones have the lowest numbers - then if many are missing, want to keep those that get agent credit and lead arranger credit
by facilityid: gen n = _n
*To keep data small, I will keep only 25, thought this will drop 40k/1.65m obs (but make data 12x smaller)
keep if n <=25
*Want to make this dataset so facilityid is a unique identifier
keep lender role loan_share facilityid n
reshape wide lender role loan_share, i(facilityid) j(n)
save "$data_path/stata_temp/lenders_facilityid_level", replace
