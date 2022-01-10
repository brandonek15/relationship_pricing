*This program will create all the indicators for looking at dynamics of the firm-bank relationship
*Todo - standardize identies of lenders/ bookrunners (probably do it in clean_sdc)
*Todo - merge on lender identities and shares from dealscan (do it in clean_dealscan) in a method that allows
*it to still be identifies by bcid and date_quarterly

use "$data_path/merged_data_comp_quart", clear
isid cusip_6 date_quarterly
*Create dynamic indicators using cusip_6 as a 
*Have indicators for all of the events
label var equity "Equity Issuance"
label var debt "Debt Issuance"
label var conv "Convertible Issuance"
gen loan = (term_loan==1 | rev_loan==1 | other_loan ==1)
label var loan "Loan Issuance"
foreach event_var in equity debt conv loan {
	replace `event_var' = 0 if mi(`event_var')
}
order cusip_6 date_quarterly equity debt conv loan
*From here we need identities of lenders/bookrunners and can make indicators 
*based off of whether past business is from same lender/bookrunner
*E.g. 1 if equity issuance this quarter with loan from same institution as bookrunner
*     0 if eqauity issuance this quarter with loan from diffirent institution as bookrunner
save "$data_path/merged_data_comp_quart_clean", replace
