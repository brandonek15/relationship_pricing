*This program will run all analysis for the tables in the paper first,
*And then the rest of the analyses for the slides at the end.

*Past lender and future pricing
use "$data_path/dealscan_compustat_loan_level", clear
foreach lhs in  discount_1_simple discount_1_controls  {

	foreach discount_type in rev b_term {

		if "`discount_type'" == "rev" {
			local cond `"if category =="Revolver""'
			local disc_add "Rev"
			local discount_type_suffix_add "_rev"
		}
		if "`discount_type'" == "b_term" {
			local cond `"if category =="Bank Term""'
			local disc_add "B Term"
			local discount_type_suffix_add "_term"
		}	

		foreach rhs_type in pooled split {
		
			if "`rhs_type'" == "pooled" {
				local rhs no_prev_lender
				local rhs_suffix_add 
				local rhs_extra no_prev_lender_rec
			}
			if "`rhs_type'" == "split" {
				local rhs first_loan switcher_loan
				local rhs_suffix_add _stay_leave
				local rhs_extra first_loan_rec switcher_loan_rec
			}			

			foreach rec_type in yes no {

				if "`rec_type'" == "yes" {
					local rhs_add `rhs_extra'
					local suffix_add _rec
					local fes time 
				}
				if "`rec_type'" == "no" {
					local rhs_add 
					local suffix_add 
					local fes time time_borrower
				}

				estimates clear
				local i =1
				
				foreach sample_type in all comp_merge no_comp_merge {
					
					if "`sample_type'" == "all" {
						local title_add "All Firms"
						local sample_add "All Firms"
						local sample_cond 
					}
					if "`sample_type'" == "comp_merge" {
						local sample_cond "& merge_compustat ==1"
						local sample_add "Comp Firms"
						local title_add "Compustat Firms"
					}
					if "`sample_type'" == "no_comp_merge" {
						local sample_cond "& merge_compustat ==0"
						local title_add "Non-Compustat Firms"
						local sample_add "Non-Comp"
					}

					foreach fe_type in  `fes' {

						if "`fe_type'" == "time" {
							local fe "date_quarterly"
							local fe_add "Time"
						}
						if "`fe_type'" == "time_borrower" {
							local fe "date_quarterly borrowercompanyid"
							local fe_add "Time,Borr"
						}
						
						reghdfe `lhs' `rhs' `rhs_add' `cond' `sample_cond' , a(`fe') vce(cl borrowercompanyid)
						estadd local fe = "`fe_add'"
						estadd local disc = "`disc_add'"
						estadd local sample = "`sample_add'"
						estimates store est`i'
						local ++i
					}


				}
				
				esttab est* using "$regression_output_path/discount_prev_lend_`lhs'`suffix_add'`rhs_suffix_add'`discount_type_suffix_add'_slides.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
				title("Discounts and Previous Lenders") scalars("fe Fixed Effects" "disc Discount" "sample Sample") ///
				addnotes("SEs clustered at firm level" "Sample are all dealscan discounts from 1991Q3-2020Q4")	
			}
		}
	}
}


*This program will do analyses on fraction/likelihood of future deals conditional 
*on previous deals in either SDC to Dealscan or Dealscan to SDC

use "$data_path/sdc_deals_with_past_relationships_20", clear
append using "$data_path/ds_lending_with_past_relationships_20"

local sdc_obs_types
foreach sdc in $sdc_types {
	local sdc_obs_types `sdc_obs_types' `sdc'_base
}
local ds_obs_types
foreach ds in $ds_types {
	local ds_obs_types `ds_obs_types' `ds'_base
}


egen sdc_obs = rowmax(`sdc_obs_types')
egen ds_obs = rowmax(`ds_obs_types')
*Date quarterly
gen date_quarterly = qofd(date_daily)
format date_quarterly %tq

*Past relationship and future pricing
*Six specifications (discount on any past relationship, then add lender FE and then split up by type of relationship, for discount and spread)
local drop_add 
local cond

foreach table_type in  simple controls {

	if "`table_type'" == "simple" {
		local lhs_vars discount_1_simple_base /* spread_base */
		local table_suffix_add 
	}
	if "`table_type'" == "controls" {
		local lhs_vars discount_1_controls_base /* spread_base */
		local table_suffix_add "_controls"
	}

	estimates clear
	local i = 1
	foreach lhs in `lhs_vars' {

		if "`lhs'" == "spread_base" {
			local rhs_add maturity_base log_facilityamt_base
			local fe_add date_quarterly  cusip_6
			local fe_scalar_add "T,F"
		}
		if "`lhs'" == "discount_1_simple_base" {
			local rhs_add 
			local fe_add date_quarterly
			local fe_scalar_add "T"
		}
		if "`lhs'" == "discount_1_controls_base" {
			local rhs_add 
			local fe_add date_quarterly
			local fe_scalar_add "T"
		}
		if "`lhs'" == "discount_1_pos_base" {
			local rhs_add
			local fe_add date_quarterly 
			local fe_scalar_add "T"
		}
		
		reghdfe `lhs' past_relationship `rhs_add' if (rev_loan_base ==1 | b_term_loan_base==1) & hire !=0 , absorb(`fe_add') vce(cl cusip_6)
		estadd local fe = "`fe_scalar_add'"
		estadd local sample = "All Discounts"
		estimates store est`i'
		local ++i
		/*
		reghdfe `lhs' past_relationship `rhs_add' if (rev_loan_base ==1 | b_term_loan_base==1) & hire !=0, absorb(`fe_add' lender) vce(cl cusip_6)
		estadd local fe = "`fe_scalar_add',L"
		estadd local sample = "All Discounts"
		estimates store est`i'
		local ++i
		*/
		reghdfe `lhs' rel_* `rhs_add' if (rev_loan_base ==1 | b_term_loan_base==1) & hire !=0, absorb(`fe_add') vce(cl cusip_6)
		estadd local fe = "`fe_scalar_add'"
		estadd local sample = "All Discounts"
		estimates store est`i'
		local ++i

	}

	esttab est* using "$regression_output_path/regressions_exten_pricing_rel_discount`table_suffix_add'_slides.tex", ///
	replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
	title("Pricing/Discounts after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
	addnotes("Observation is DS loan x lender" "Sample is DS revolving loans x lender on loan" "SEs clustered at firm level" ///
		"FE Codes: T= Quarter, F = Firm, L = Lender")
}

*Use discount >0 as a lhs
local drop_add 
estimates clear
local i = 1

foreach lhs in d_1_simple_pos_base d_1_controls_pos_base {
	
	reghdfe `lhs' past_relationship if (rev_loan_base ==1 | b_term_loan_base==1) & hire !=0 , absorb(date_quarterly) vce(cl cusip_6)
	estadd local fe = "T"
	estadd local sample = "All Discounts"
	estimates store est`i'
	local ++i
	reghdfe `lhs' past_relationship  if (rev_loan_base ==1 | b_term_loan_base==1) & hire !=0, absorb(date_quarterly lender) vce(cl cusip_6)
	estadd local fe = "T,L"
	estadd local sample = "All Discounts"
	estimates store est`i'
	local ++i
	reghdfe `lhs' rel_*  if (rev_loan_base ==1 | b_term_loan_base==1) & hire !=0, absorb(date_quarterly lender) vce(cl cusip_6)
	estadd local fe = "T,L"
	estadd local sample = "All Discounts"
	estimates store est`i'
	local ++i

}
esttab est* using "$regression_output_path/regressions_exten_disc_post_rel_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Positive Discount after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Observation is DS loan x lender" "Sample is DS revolving loans x lender on loan" "SEs clustered at firm level" ///
	"FE Codes: T= Quarter, F = Firm, L = Lender")

*Simple past relationship table
local rhs rel_* 
local drop_add 
local absorb constant
local fe_local "None"
foreach table in sdc ds {

	if "`table'" == "sdc" {
		local lhs all_sdc $sdc_types
		local notes_add "SDC deal x lender"
	}
	if "`table'" == "ds" {
		
		local lhs all_ds $ds_types
		local notes_add "Dealscan loan x lender"
	}
	
	estimates clear
	local i = 1

	foreach type in  `lhs'  {
		if "`type'" == "all_sdc" {
			local cond "if sdc_obs==1" 
			local scalar_label "All Securities"
		}
		
		if "`type'" == "equity" {
			local cond "if `type' ==1" 
			local scalar_label "Equity Issuance"
		}
		if "`type'" == "debt" {
			local cond "if `type' ==1" 
			local scalar_label "Debt Issuance"
		}
		if "`type'" == "conv" {
			local cond "if `type' ==1" 
			local scalar_label "Convertible Issuance"
		}
		if "`type'" == "all_ds" {
			local cond "if ds_obs==1" 
			local scalar_label "All Loans"
		}
		if "`type'" == "b_term_loan" {
			local cond "if `type' ==1" 
			local scalar_label "Bank Term Loans"
		}
		if "`type'" == "rev_loan" {
			local cond "if `type' ==1" 
			local scalar_label "Rev Loans"
		}
		if "`type'" == "i_term_loan" {
			local cond "if `type' ==1" 
			local scalar_label "Inst. Term Loans"
		}
		if "`type'" == "other_loan" {
			local cond "if `type' ==1" 
			local scalar_label "Other Loans"
		}
		
		reghdfe hire `rhs' `cond', absorb(`absorb') vce(cl cusip_6)
		estadd local fe = "`fe_local'"
		estadd local sample = "`scalar_label'"
		estimates store est`i'
		local ++i
	}

	esttab est* using "$regression_output_path/regressions_inten_baseline_`table'_slides.tex", ///
	replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
	title("Likelihood of hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
	addnotes("Observation is `notes_add'" "Sample is 20 largest lenders x each deal/loan" ///
	"Hire indicator either 0 or 100 for readability" "SEs clustered at firm level" )
}
*Past discounts and future business
foreach table_type in  simple controls {

	if "`table_type'" == "simple" {
		local rhs rel_*  i_discount_1_simple* mi_discount_1_simple* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* 
		local table_suffix_add 
	}
	if "`table_type'" == "controls" {
		local rhs rel_*  i_discount_1_controls* mi_discount_1_controls* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* 
		local table_suffix_add "_controls"
	}

	estimates clear
	local i = 1

	local drop_add mi_* rel_* *_other
	local absorb constant
	local fe_local "None"

	foreach type in all_sdc all_ds equity debt b_term rev {

		if "`type'" == "all_sdc" {
			local cond "if sdc_obs==1" 
		}
		if "`type'" == "all_ds" {
			local cond "if ds_obs==1" 
		}
		if "`type'" == "equity" {
			local cond "if `type' ==1" 
		}
		if "`type'" == "debt" {
			local cond "if `type' ==1" 
		}
		if "`type'" == "b_term" {
			local cond "if `type'_loan ==1" 
		}
		if "`type'" == "rev" {
			local cond "if `type'_loan ==1" 
		}
		
		reghdfe hire `rhs' `cond', absorb(`absorb') vce(cl cusip_6)
		estadd local fe = "`fe_local'"
		estadd local sample = "`type'"
		estimates store est`i'
		local ++i
	}

	esttab est* using "$regression_output_path/regressions_inten_ds_chars`table_suffix_add'_slides.tex", ///
	replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
	title("Likelihood of hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
	addnotes("Table suppresses past relationship indicators and Other Loan characteristics"  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" ///
	"Hire indicator either 0 or 100 for readability" "SEs clustered at firm level" )
}
*Past discounts positive indicator and future business
foreach table in sdc ds {

	if "`table'" == "sdc" {
		local lhs all_sdc $sdc_types
		local notes_add "SDC deal x lender"
	}
	if "`table'" == "ds" {
		local lhs all_ds $ds_types
		local notes_add "Dealscan loan x lender"
	}
	foreach table_type in  simple controls {

		if "`table_type'" == "simple" {
			local rhs rel_*  i_d_1_simple_pos* mi_d_1_simple_pos* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* 
			local table_suffix_add 
		}
		if "`table_type'" == "controls" {
			local rhs rel_*  i_d_1_controls_pos* mi_d_1_controls_pos* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* 
			local table_suffix_add "_controls"
		}

		estimates clear
		local i = 1

		local drop_add mi_* rel_* *_other
		local absorb constant
		local fe_local "None"

		foreach type in  `lhs'  {

			if "`type'" == "all_sdc" {
				local cond "if sdc_obs==1" 
				local scalar_label "All Securities"
			}
			if "`type'" == "equity" {
				local cond "if `type' ==1" 
				local scalar_label "Equity Issuance"
			}
			if "`type'" == "debt" {
				local cond "if `type' ==1" 
				local scalar_label "Debt Issuance"
			}
			if "`type'" == "conv" {
				local cond "if `type' ==1" 
				local scalar_label "Convertible Issuance"
			}
			if "`type'" == "all_ds" {
				local cond "if ds_obs==1" 
				local scalar_label "All Loans"
			}
			if "`type'" == "b_term_loan" {
				local cond "if `type' ==1" 
				local scalar_label "Bank Term Loans"
			}
			if "`type'" == "i_term_loan" {
				local cond "if `type' ==1" 
				local scalar_label "Inst. Term Loans"
			}
			if "`type'" == "rev_loan" {
				local cond "if `type' ==1" 
				local scalar_label "Rev Loans"
			}
			if "`type'" == "other_loan" {
				local cond "if `type' ==1" 
				local scalar_label "Other Loans"
			}
			
			reghdfe hire `rhs' `cond', absorb(`absorb') vce(cl cusip_6)
			estadd local fe = "`fe_local'"
			estadd local sample = "`scalar_label'"
			estimates store est`i'
			local ++i
		}

		esttab est* using "$regression_output_path/regressions_inten_ds_chars_pos_`table'`table_suffix_add'_slides.tex", ///
		replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) keep(i_d_1_*_rev i_d_1_*_b_term) ///
		title("Likelihood of hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
		addnotes("Table suppresses past relationship indicators and other loan characteristics"  "Observation is `notes_add'" ///
		"Hire indicator either 0 or 100 for readability" "SEs clustered at firm level" )
	}
}
*Past discount bins and future business
foreach table in sdc ds {

	if "`table'" == "sdc" {
		local lhs all_sdc $sdc_types
		local notes_add "SDC deal x lender"
	}
	if "`table'" == "ds" {
		local lhs all_ds $ds_types
		local notes_add "Dealscan loan x lender"
	}
	foreach table_type in  simple controls {

		if "`table_type'" == "simple" {
			local rhs rel_*  i_d_1_simple_le_0* i_d_1_simple_0_25* i_d_1_simple_25_50* i_d_1_simple_50_100* i_d_1_simple_100_200* i_d_1_simple_ge_200*  ///
		 mi_discount_1_simple* 
			local table_suffix_add 
		}
		if "`table_type'" == "controls" {
			local rhs rel_*  i_d_1_controls_0_25* i_d_1_controls_25_50* i_d_1_controls_50_100* i_d_1_controls_100_200* i_d_1_controls_ge_200*  ///
		 mi_discount_1_controls* 
			local table_suffix_add "_controls"
		}

		local drop_add mi_* rel_* *_other *_i_term
		local absorb constant
		local fe_local "None"

		estimates clear
		local i = 1

		foreach type in `lhs' {

			if "`type'" == "all_sdc" {
				local cond "if sdc_obs==1" 
				local scalar_label "All Securities"
			}
			if "`type'" == "equity" {
				local cond "if `type' ==1" 
				local scalar_label "Equity Issuance"
			}
			if "`type'" == "debt" {
				local cond "if `type' ==1" 
				local scalar_label "Debt Issuance"
			}
			if "`type'" == "conv" {
				local cond "if `type' ==1" 
				local scalar_label "Convertible Issuance"
			}
			if "`type'" == "all_ds" {
				local cond "if ds_obs==1" 
				local scalar_label "All Loans"
			}
			if "`type'" == "b_term_loan" {
				local cond "if `type' ==1" 
				local scalar_label "Bank Term Loans"
			}
			if "`type'" == "i_term_loan" {
				local cond "if `type' ==1" 
				local scalar_label "Inst. Term Loans"
			}
			if "`type'" == "rev_loan" {
				local cond "if `type' ==1" 
				local scalar_label "Rev Loans"
			}
			if "`type'" == "other_loan" {
				local cond "if `type' ==1" 
				local scalar_label "Other Loans"
			}
			
			reghdfe hire `rhs' `cond', absorb(`absorb') vce(cl cusip_6)
			estadd local fe = "`fe_local'"
			estadd local sample = "`type'"
			estimates store est`i'
			local ++i
		}
		
		esttab est* using "$regression_output_path/regressions_inten_ds_chars_bins`table_suffix_add'_`table'_slides.tex", ///
		replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
		title("Likelihood of hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
		addnotes("Table suppresses past relationship indicators and Other Loan characteristics"  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" ///
		"Hire indicator either 0 or 100 for readability" "SEs clustered at firm level" )

		/*
		esttab est* using "$regression_output_path/regressions_inten_ds_chars_bins_rev_disp`table_suffix_add'_`table_type'_slides.tex", ///
		replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons *_b_term `drop_add') ///
		title("Likelihood of hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
		addnotes("Table suppresses past relationship indicators and Other Loan characteristics"  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" ///
		"Hire indicator either 0 or 100 for readability" "SEs clustered at firm level" )

		esttab est* using "$regression_output_path/regressions_inten_ds_chars_bins_term_disp`table_suffix_add'_`table_type'_slides.tex", ///
		replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons *_rev `drop_add') ///
		title("Likelihood of hiring after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
		addnotes("Table suppresses past relationship indicators and Other Loan characteristics"  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" ///
		"Hire indicator either 0 or 100 for readability" "SEs clustered at firm level" )
		*/
	}
}

*Look at pricing after previous relationship (sprd and SDC fee) 
local drop_add 
estimates clear
local i = 1

foreach type in all_sdc all_ds equity debt b_term rev {

	if "`type'" == "all_sdc" {
		local cond "if sdc_obs==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "equity" {
		local cond "if `type'_base ==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "debt" {
		local cond "if `type'_base ==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "all_ds" {
		local cond "if ds_obs==1" 
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	if "`type'" == "b_term" {
		local cond "if `type'_loan_base ==1" 
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	if "`type'" == "rev" {
		local cond "if `type'_loan_base ==1"
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	
	reghdfe `lhs' rel_* `rhs_add' `cond' & hire !=0, absorb(date_quarterly cusip_6) vce(cl cusip_6)
	estadd local fe = "Firm,Time"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}


esttab est* using "$regression_output_path/regressions_exten_pricing_rel_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Pricing/Discounts after relationships") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Observation is DS loan x lender or SDC deal x lender" "Sample is DS loans/SDC deal x lender on loan/deal" "SEs clustered at firm level" )


*Look at price recouping (look at previous discounts and fees charged)
local rhs rel_* i_discount_1_simple* mi_discount_1_simple* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* 
local drop_add mi_* rel_* *_other
local absorb constant
local fe_local "None"

estimates clear
local i = 1

foreach type in all_sdc all_ds equity debt b_term rev {

	if "`type'" == "all_sdc" {
		local cond "if sdc_obs==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "equity" {
		local cond "if `type'_base ==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "debt" {
		local cond "if `type'_base ==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "all_ds" {
		local cond "if ds_obs==1" 
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	if "`type'" == "b_term" {
		local cond "if `type'_loan_base ==1" 
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	if "`type'" == "rev" {
		local cond "if `type'_loan_base ==1"
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	
	reghdfe `lhs' `rhs' `rhs_add' `cond' & hire !=0, absorb(date_quarterly) vce(cl cusip_6)
	estadd local fe = "Time"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}


esttab est* using "$regression_output_path/regressions_exten_pricing_ds_chars_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons `drop_add') ///
title("Pricing After Previous Loan Characteristics") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Table suppresses past relationship indicators and Other Loan characteristics" ///
  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" "SEs clustered at firm level" )

*Look at price recouping (look at previous discounts and fees charged) - using bins for discount
local rhs rel_* mi_discount_1_simple* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* ///
i_d_1_simple_le_0* i_d_1_simple_0_25* i_d_1_simple_25_50* i_d_1_simple_50_100* i_d_1_simple_100_200* i_d_1_simple_ge_200* 
local drop_add mi_* rel_* *_other i_maturity_* i_log_facilityamt_* i_spread_*
local absorb constant
local fe_local "None"

estimates clear
local i = 1

foreach type in all_sdc all_ds equity debt b_term rev {

	if "`type'" == "all_sdc" {
		local cond "if sdc_obs==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "equity" {
		local cond "if `type'_base ==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "debt" {
		local cond "if `type'_base ==1" 
		local lhs gross_spread_perc_base
		local rhs_add log_proceeds_base
	}
	if "`type'" == "all_ds" {
		local cond "if ds_obs==1" 
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	if "`type'" == "b_term" {
		local cond "if `type'_loan_base ==1" 
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	if "`type'" == "rev" {
		local cond "if `type'_loan_base ==1"
		local lhs spread_base 
		local rhs_add maturity_base log_facilityamt_base
	}
	
	reghdfe `lhs' `rhs' `rhs_add' `cond' & hire !=0, absorb(date_quarterly cusip_6) vce(cl cusip_6)
	estadd local fe = "Firm,Time"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}


esttab est* using "$regression_output_path/regressions_exten_pricing_ds_chars_bins_rev_disp_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons *_b_term `drop_add') ///
title("Pricing After Previous Loan Characteristics") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Table suppresses past relationship indicators and Other Loan characteristics" ///
  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" "SEs clustered at firm level" )

esttab est* using "$regression_output_path/regressions_exten_pricing_ds_chars_bins_term_disp_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons *_rev `drop_add') ///
title("Pricing After Previous Loan Characteristics") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Table suppresses past relationship indicators and Other Loan characteristics" ///
  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" "SEs clustered at firm level" )

*Look at amt raised (look at previous discounts and amount raised) - using bins for discount
local rhs rel_* mi_discount_1_simple* i_maturity_* i_log_facilityamt_* i_spread_* mi_spread_* ///
i_d_1_simple_le_0* i_d_1_simple_0_25* i_d_1_simple_25_50* i_d_1_simple_50_100* i_d_1_simple_100_200* i_d_1_simple_ge_200* 
local drop_add mi_* rel_* *_other i_maturity_* i_log_facilityamt_* i_spread_*
local absorb constant
local fe_local "None"

estimates clear
local i = 1

foreach type in all_sdc all_ds equity debt b_term rev {

	if "`type'" == "all_sdc" {
		local cond "if sdc_obs==1" 
		local lhs log_proceeds_base
		local rhs_add 
	}
	if "`type'" == "equity" {
		local cond "if `type'_base ==1" 
		local lhs log_proceeds_base
		local rhs_add 
	}
	if "`type'" == "debt" {
		local cond "if `type'_base ==1" 
		local lhs log_proceeds_base
		local rhs_add 
	}
	if "`type'" == "all_ds" {
		local cond "if ds_obs==1" 
		local lhs log_facilityamt_base
		local rhs_add maturity_base 
	}
	if "`type'" == "b_term" {
		local cond "if `type'_loan_base ==1" 
		local lhs log_facilityamt_base
		local rhs_add maturity_base 
	}
	if "`type'" == "rev" {
		local cond "if `type'_loan_base ==1"
		local lhs log_facilityamt_base
		local rhs_add maturity_base
	}
	
	reghdfe `lhs' `rhs' `rhs_add' `cond' & hire !=0, absorb(date_quarterly cusip_6) vce(cl cusip_6)
	estadd local fe = "Firm,Time"
	estadd local sample = "`type'"
	estimates store est`i'
	local ++i
}


esttab est* using "$regression_output_path/regressions_exten_amt_ds_chars_bins_rev_disp_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons *_b_term `drop_add') ///
title("Pricing After Previous Loan Characteristics") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Table suppresses past relationship indicators and Other Loan characteristics" ///
  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" "SEs clustered at firm level" )

esttab est* using "$regression_output_path/regressions_exten_amt_ds_chars_bins_term_disp_slides.tex", ///
replace  b(%9.3f) se(%9.3f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) drop(_cons *_rev `drop_add') ///
title("Pricing After Previous Loan Characteristics") scalars("fe Fixed Effects" "sample Sample" ) ///
addnotes("Table suppresses past relationship indicators and Other Loan characteristics" ///
  "Observation is SDC deal x lender or DS loan x lender" "Sample is 20 largest lenders x each deal/loan" "SEs clustered at firm level" )

*Correlations between Firm Characteristics and Discount
use "$data_path/dealscan_compustat_loan_level", clear
keep if category == "Revolver" | category == "Bank Term"
keep if !mi(discount_1_simple) & merge_compustat ==1
label var discount_1_simple "Disc"

local firm_chars L1_market_to_book L1_ppe_assets L1_current_assets L1_log_assets L1_leverage ///
L1_roa L1_sales_growth L1_ebitda_int_exp L1_sga_assets ///
L1_working_cap_assets L1_capex_assets L1_firm_age

winsor2 `firm_chars', cuts(.5 99.5) replace

*Deal with missing vars so we don't lose so much data
foreach var in `firm_chars' {
	gen `var'_mi = mi(`var')
	replace `var' = -99 if `var'_mi ==1
	local firm_char_add `firm_char_add' `var'_mi
}

local firm_chars `firm_chars' `firm_char_add'

foreach lhs in discount_1_simple discount_1_controls {

	foreach discount_type in rev  {

		if "`discount_type'" == "rev" {
			local cond `"if category =="Revolver""'
			local sample_add "Rev"
		}
		if "`discount_type'" == "b_term" {
			local cond `"if category =="Bank Term""'
			local sample_add "Term"
		}
		if "`discount_type'" == "all" {
			local cond `"if 1==1"'
			local sample_add "All"
		}
		
		estimates clear
		local i =1
		
		foreach chars in firm_chars {
		
			if "`chars'" == "firm_chars" {
				local rhs `firm_chars'
			}
		
			foreach fe_type in  none  time time_sic_2 time_firm {
			
				if "`fe_type'" == "none" {
					local fe "constant"
					local fe_add "None"
				}
				if "`fe_type'" == "time" {
					local fe "date_quarterly"
					local fe_add "Time"
				}
				if "`fe_type'" == "time_sic_2" {
					local fe "date_quarterly sic_2"
					local fe_add "Time,SIC2"
				}
				if "`fe_type'" == "time_firm" {
					local fe "date_quarterly cusip_6"
					local fe_add "Time,Firm"
				}				
				reghdfe `lhs' `rhs' `cond', a(`fe') vce(cl cusip_6)
				estadd local fe = "`fe_add'"
				estadd local sample = "`sample_add'"
				estimates store est`i'
				local ++i
			}
			
		}

		esttab est* using "$regression_output_path/discount_chars_`lhs'_`discount_type'_slides.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons *_mi) star(* 0.1 ** 0.05 *** 0.01) ///
		title("Discounts and Characteristics") scalars("fe Fixed Effects" "sample Sample") ///
		addnotes("SEs clustered at firm level" "Sample are all compustat firms with dealscan discounts from 2000Q1-2020Q4")	

	}

}

*** Discounts and differences in loan characteristics
use "$data_path/dealscan_compustat_loan_level", clear

label var discount_1_simple "Disc"
label var discount_1_controls "Di-controls"

foreach discount_type in rev {
	
	estimates clear
	local i =1
	
	foreach lhs in discount_1_simple /* discount_1_controls */ {
		if "`discount_type'" == "rev" {
			local cond `"if category =="Revolver""'
			local sample_add "Rev"
		}
		if "`discount_type'" == "b_term" {
			local cond `"if category =="Bank Term""'
			local sample_add "Term"
		}
		if "`discount_type'" == "all" {
			local cond `"if 1==1"'
			local sample_add "All"
		}

			local rhs diff_*
			*Make the first specification just regress on the constant			
			reg `lhs' `cond', vce(cl borrowercompanyid)
			estadd local fe = "None"
			estadd local sample = "`sample_add'"
			estimates store est`i'
			local ++i
			*Do the normal regression w/out FE
			reg `lhs' `rhs' `cond', vce(cl borrowercompanyid)
			estadd local fe = "None"
			estadd local sample = "`sample_add'"
			estimates store est`i'
			local ++i
/*	
			*Do the regression w/ FE
			reghdfe `lhs' `rhs' `cond', a(date_quarterly) vce(cl borrowercompanyid)
			estadd local fe = "Time"
			estadd local sample = "`sample_add'"
			estimates store est`i'
			local ++i
*/			
		}
	
	esttab est* using "$regression_output_path/discount_loan_chars_diff_`discount_type'_slides.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress star(* 0.1 ** 0.05 *** 0.01) ///
	title("Discounts and Differences in non-price characteristics") scalars("fe Fixed Effects" "sample Sample") ///
	addnotes("SEs clustered at firm level" "Sample are all compustat firms with dealscan discounts from 2000Q1-2020Q4")	

}

*See how compustat with ratings vs compustat w/out ratings, vs  non compustat compare
use "$data_path/dealscan_compustat_loan_level", clear
foreach lhs in  discount_1_simple discount_1_controls {

	local cond `"if category =="Revolver""'
	local disc_add "Rev"

	label var discount_1_simple "Disc"		
	estimates clear
	local i =1
		
	*Regression 1 Regress discount on constant and
	reghdfe `lhs' merge_compustat_no_ratings merge_ratings `cond', absorb(constant) nocons  vce(cl borrowercompanyid)
	estadd local fe = "None"
	estadd local disc = "`disc_add'"
	estadd local sample = "All"
	estimates store est`i'
	local ++i
	/*
	*Regression 5 - Add pooled prev_rel and switcher_loan (Time FE)
	reghdfe `lhs' no_prev_lender switcher_loan  `cond' , a(date_quarterly) vce(cl borrowercompanyid)
	estadd local fe = "Time"
	estadd local disc = "`disc_add'"
	estadd local sample = "All"
	estimates store est`i'
	local ++i
	*/
	*Regression 6 - Add interaction to prev_rel and switcher (Time FE)
	reghdfe `lhs' first_no_merge_compustat switc_no_merge_compustat ///
	merge_compustat_no_ratings merge_ratings first_merge_compustat_no_ratings switc_merge_compustat_no_ratings prev_merge_ratings ///
	  switc_merge_ratings `cond' , a(date_quarterly) vce(cl borrowercompanyid)
	estadd local fe = "Time"
	estadd local disc = "`disc_add'"
	estadd local sample = "All"
	estimates store est`i'
	local ++i

	esttab est* using "$regression_output_path/discount_prev_lend_`lhs'_all_rating_cat_slides.tex", replace b(%9.2f) se(%9.2f) r2 label nogaps compress drop(_cons) star(* 0.1 ** 0.05 *** 0.01) ///
	title("Discounts and Previous Lenders") scalars("fe Fixed Effects" "disc Discount" "sample Sample") ///
	addnotes("SEs clustered at firm level" "Sample are all dealscan discounts from 2005Q1-2020Q4" "Dropping 2001Q1-2004Q4 as burnout period")	
}
