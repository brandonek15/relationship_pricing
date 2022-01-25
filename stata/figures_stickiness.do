*Make figures for stickiness 
*Specifically meaning the fraction of deal type X to have the same lender in deal type Y, t years ago.

foreach type in equity_to_equity equity_to_debt debt_to_equity  debt_to_debt  {
	if "`type'" == "equity_to_equity" {
		local data_to_use "$data_path/sdc_`type'_match"
		local title "Fraction of equity deals with same lender in most recent equity deal"
	}
	if "`type'" == "equity_to_debt" {
		local data_to_use "$data_path/sdc_`type'_match"
		local title "Fraction of debt deals with same lender in most recent equity deal"
	}
	if "`type'" == "debt_to_equity" {
		local data_to_use "$data_path/sdc_`type'_match"
		local title "Fraction of equity deals with same lender in most recent debt deal"
	}
	if "`type'" == "debt_to_debt" {
		local data_to_use "$data_path/sdc_`type'_match"
		local title "Fraction of debt deals with same lender in most recent debt deal"
	}

	use `data_to_use', clear
	*Drop if it is within six months it is likely the same issuance
	drop if days_between_match <=180
	*We only want to keep the most recent match
	sort sdc_deal_id days_between_match
	egen min_days_between_match = min(days_between_match), by(sdc_deal_id) 
	keep if days_between_match == min_days_between_match
	gen years_between_match = floor(days_between_match/365.25)
	
	
	*For each deal, see if there was another deal within x years to the same lender
	collapse (max) same_lender, by(sdc_deal_id years_between_match)
	*Now get the average by years out to see the average stickiness
	gen count = 1
	collapse (sum) count (mean) same_lender, by(years_between_match)

	local frac_same (line same_lender years_between_match, col(blue) lpattern(solid) lwidth(medthin) yaxis(1))
	local num_obs (line count years_between_match, col(black) lpattern(solid) lwidth(medthin) yaxis(2))
			
	twoway `frac_same' `num_obs' ///
	, ytitle("Fraction with Same Lender", axis(1)) ytitle("Number of Observations", axis(2)) ///
	 title("`title'", size(medium))  ///
	graphregion(color(white))  xtitle("Number of Years Prior to Deal") ///
	legend(order(1 "Fraction with Same Lender" 2 "Number of Obs")) note("Drop deals within six months of loan/issuance")
	graph export "$figures_output_path/stickiness_`type'.png", replace

}

*Do this for SDC to DS and DS to SDC
*First from DS to SDC
foreach type in ds_to_sdc sdc_to_ds {
	use "$data_path/sdc_dealscan_pairwise_combinations_matched_unmatched", clear
	rename days_from_ds_to_sdc days_between_match
	gen same_lender = (lender == lender_sdc)


	if "`type'" == "ds_to_sdc" {
		local title "Fraction of equity/debt deals with same lender in most recent dealscan loan"
		*This is our unit of observation
		local collapse_var sdc_deal_id
	}
	if "`type'" == "sdc_to_ds" {
		local title "Fraction dealscan loans of with same lender in most recent equity/debt deal"
		*If I am going from sdc_to_ds, need to make the days negative sign
		replace days_between_match = -days_between_match
		local collapse_var facilityid
	}

	*Drop if it is within six months it is likely the same issuance
	drop if days_between_match <=180
	*We only want to keep the most recent match
	sort sdc_deal_id days_between_match
	egen min_days_between_match = min(days_between_match), by(`collapse_var') 
	keep if days_between_match == min_days_between_match
	gen years_between_match = floor(days_between_match/365.25)
	
	
	*For each deal, see if there was another deal within x years to the same lender
	collapse (max) same_lender, by(`collapse_var' years_between_match)
	*Now get the average by years out to see the average stickiness
	gen count = 1
	collapse (sum) count (mean) same_lender, by(years_between_match)

	local frac_same (line same_lender years_between_match, col(blue) lpattern(solid) lwidth(medthin) yaxis(1))
	local num_obs (line count years_between_match, col(black) lpattern(solid) lwidth(medthin) yaxis(2))
			
	twoway `frac_same' `num_obs' ///
	, ytitle("Fraction with Same Lender", axis(1)) ytitle("Number of Observations", axis(2)) ///
	 title("`title'", size(medium))  ///
	graphregion(color(white))  xtitle("Number of Years Prior to Deal") ///
	legend(order(1 "Fraction with Same Lender" 2 "Number of Obs")) note("Drop deals within six months of loan/issuance")
	graph export "$figures_output_path/stickiness_`type'.png", replace
}
