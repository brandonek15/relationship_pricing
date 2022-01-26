
cap program drop cleanNames

program define cleanNames

	replace lender = strtrim(lender)
	replace lender = regexr(lender, "\((.)+\)", "")
	replace lender = regexr(lender, "\[(.)+\]", "")
	replace lender = itrim(lender)

	replace lender = subinstr(lender,"*","",.)
	replace lender = subinstr(lender,"LP","",.)
	replace lender = subinstr(lender,"LTD","",.)
	replace lender = subinstr(lender,"Ltd","",.)
	replace lender = subinstr(lender,"LLC","",.)
	replace lender = subinstr(lender,"Plc","",.)
	replace lender = subinstr(lender,"plc","",.)
	replace lender = subinstr(lender,"PLC","",.)
	replace lender = subinstr(lender,"Inc","",.) if substr(lender,-4,.) == " Inc"
	replace lender = subinstr(lender,"BIBF","",.) if substr(lender,-5,.) == " BIBF"
	replace lender = subinstr(lender," Co","",.) if substr(lender,-3,.) == " Co"
	replace lender = subinstr(lender," Pvt","",.) if substr(lender,-4,.) == " Pvt"
	replace lender = subinstr(lender," NV","",.) if substr(lender,-3,.) == " NV"
	replace lender = subinstr(lender,"/NV","",.) if substr(lender,-3,.) == "/NV"
	replace lender = subinstr(lender," NA","",.) if substr(lender,-3,.) == " NA"
	replace lender = subinstr(lender,"/NA","",.) if substr(lender,-3,.) == "/NA"
	replace lender = subinstr(lender," SA","",.) if substr(lender,-3,.) == " SA"
	replace lender = subinstr(lender," AS","",.) if substr(lender,-3,.) == " AS"
	replace lender = subinstr(lender," A/S","",.) if substr(lender,-4,.) == " A/S"
	replace lender = subinstr(lender," S/A","",.) if substr(lender,-4,.) == " S/A"
	replace lender = subinstr(lender," as","",.) if substr(lender,-3,.) == " as"
	replace lender = subinstr(lender," ASA","",.) if substr(lender,-4,.) == " ASA"
	replace lender = subinstr(lender," AG","",.) if substr(lender,-3,.) == " AG"
	replace lender = subinstr(lender," BA","",.) if substr(lender,-3,.) == " BA"
	replace lender = subinstr(lender," AB","",.) if substr(lender,-3,.) == " AB"
	replace lender = subinstr(lender," FD","",.) if substr(lender,-3,.) == " FD"
	replace lender = subinstr(lender," BV","",.) if substr(lender,-3,.) == " BV"
	replace lender = subinstr(lender," SpA","",.) if substr(lender,-4,.) == " SpA"
	replace lender = subinstr(lender," Clo","",.) if substr(lender,-4,.) == " Clo"
	replace lender = subinstr(lender," CLO","",.) if substr(lender,-4,.) == " CLO"
	replace lender = subinstr(lender," CDO","",.) if substr(lender,-4,.) == " CDO"
	replace lender = subinstr(lender," ACA","",.) if substr(lender,-4,.) == " ACA"
	replace lender = subinstr(lender," PCA","",.) if substr(lender,-4,.) == " PCA"
	replace lender = subinstr(lender," FLCA","",.) if substr(lender,-5,.) == " FLCA"
	replace lender = subinstr(lender," FSB","",.) if substr(lender,-4,.) == " FSB"
	replace lender = subinstr(lender," IX","",.) if substr(lender,-3,.) == " IX"
	replace lender = subinstr(lender," 2","",.) if substr(lender,-2,.) == " 2"
	replace lender = subinstr(lender," AG","",.) if substr(lender,-3,.) == " AG"
	replace lender = subinstr(lender," GZ","",.) if substr(lender,-3,.) == " GZ"
	replace lender = subinstr(lender," &","",.) if substr(lender,-2,.) == " &"
	replace lender = subinstr(lender," -","",.) if substr(lender,-2,.) == " -"
	replace lender = subinstr(lender,"-A","",.) if substr(lender,-2,.) == "-A"
	replace lender = subinstr(lender," & Trust","",.) if substr(lender,-8,.) == " & Trust"


	foreach i in "Taipei" "London" "Tokyo" "Texas" "New York" "Hong Kong" ///
	 "North America" "Canada" "Limited" {
		local x = -1*(length("`i'")+1)
		replace lender = subinstr(lender, " `i'","",.) if substr(lender,`x',.) == " `i'"  & ///
							!regexm(lender,"of `i'")	
	}

	forval i = 1/9 {
		replace lender = subinstr(lender," `i'","",.) if substr(lender,-2,.) == " `i'"
		replace lender = subinstr(lender,"-`i'","",.) if substr(lender,-2,.) == "-`i'"
	}

	foreach i in "I" "II" "III" "IIII" "IV" "V" "VI" "VII" "VIII" "IX" "X" "XI" {
		local x = -1*(length("`i'")+1)
		replace lender = subinstr(lender, " `i'","",.) if substr(lender,`x',.) == " `i'"
		replace lender = subinstr(lender, "-`i'","",.) if substr(lender,`x',.) == "-`i'"
	}

	forval i = 1990/2020 {
		replace lender = subinstr(lender," `i'","",.) if substr(lender,-5,.) == " `i'"
	}

	replace lender = strtrim(lender)

end

cap program drop standardize_ds

program define standardize_ds


	forval k = 1/5  {
		cleanNames
	}


	replace lender = "1st Farm Credit" if regexm(lender,"1st Farm Credit")
	replace lender = "ABN AMRO" if regexm(lender,"ABN AMRO")
	replace lender = "ABB" if regexm(lender,"ABB ")
	replace lender = "ABC" if regexm(lender,"ABC ")
	replace lender = "ABSA" if regexm(lender,"ABSA ")
	replace lender = "ACA" if substr(lender,1,4)=="ACA "
	replace lender = "ACE" if substr(lender,1,4)=="ACE "
	replace lender = "ACL" if substr(lender,1,4)=="ACL "
	replace lender = "AG" if substr(lender,1,3)=="AG "
	replace lender = "AIB" if substr(lender,1,4)=="AIB "
	replace lender = "AIG" if substr(lender,1,4)=="AIG " | substr(lender,1,4)=="AIG-"
	replace lender = "AMMC" if substr(lender,1,4)=="AMMC"
	replace lender = "AMP" if substr(lender,1,4)=="AMP "
	replace lender = "ANZ" if substr(lender,1,4)=="ANZ "
	replace lender = "APEX" if substr(lender,1,5)=="APEX "
	replace lender = "AS" if substr(lender,1,3)=="AS "
	replace lender = "ASB" if substr(lender,1,4)=="ASB "
	replace lender = "AXA" if substr(lender,1,4)=="AXA "
	replace lender = "AZB" if substr(lender,1,4)=="AZB "
	replace lender = "Abanca" if regexm(lender,"Abanca")
	replace lender = "Ableco" if regexm(lender,"Ableco")
	replace lender = "Aeon" if regexm(lender,"Aeon")
	replace lender = "Affin" if substr(lender,1,6)=="Affin "
	replace lender = "Agricultural Bank of China" if regexm(lender,"Agricultural Bank of China")
	replace lender = "Ahli" if substr(lender,1,5)=="Ahli "
	replace lender = "Aichi" if substr(lender,1,6)=="Aichi "
	replace lender = "Aimco" if regexm(lender,"Aimco")
	replace lender = "Airbus" if regexm(lender,"Airbus")
	replace lender = "Airlie" if regexm(lender,"Airlie")
	replace lender = "Akita" if regexm(lender,"Akita")
	replace lender = "Alcatel-Lucent" if regexm(lender,"Alcatel-Lucent")
	replace lender = "Alcentra" if regexm(lender,"Alcentra")
	replace lender = "Alfa Bank" if regexm(lender,"Alfa Bank")
	replace lender = "Allen & Overy" if regexm(lender,"Allen & Overy")
	replace lender = "Alliance & Leicester" if regexm(lender,"Alliance & Leicester")
	replace lender = "Alliance Bank" if regexm(lender,"Alliance Bank")
	replace lender = "Allianz" if regexm(lender,"Allianz")
	replace lender = "Allstate" if regexm(lender,"Allstate")
	replace lender = "Ally" if substr(lender,1,5)=="Ally "
	replace lender = "Alostar" if regexm(lender,"Alostar")
	replace lender = "Alpha Bank" if regexm(lender,"Alpha Bank")
	replace lender = "AmSouth" if regexm(lender,"AmSouth")
	replace lender = "American Bank" if regexm(lender,"American Bank")
	replace lender = "American Express" if regexm(lender,"American Express")
	replace lender = "AIG" if regexm(lender,"American International Group")
	replace lender = "American National Bank" if regexm(lender,"American National Bank")
	replace lender = "Anhui" if regexm(lender,"Anhui")
	replace lender = "Apollo" if regexm(lender,"Apollo")
	replace lender = "Arab Bank" if regexm(lender,"Arab Bank")
	replace lender = "Ares" if substr(lender,1,5) == "Ares "
	replace lender = "Atrium" if regexm(lender,"Atrium")
	replace lender = "Audax" if regexm(lender,"Audax")
	replace lender = "Australia & New Zealand Banking Group" if regexm(lender,"Australia & New Zealand")
	replace lender = "Aviva" if regexm(lender,"Aviva")
	replace lender = "Axis Bank" if regexm(lender,"Axis Bank")
	replace lender = "BBVA" if regexm(lender,"BBVA")
	replace lender = "BNP Paribas" if regexm(lender,"BNP Paribas")
	replace lender = "BMCE Bank" if regexm(lender,"BMCE Bank")
	replace lender = "BMO" if substr(lender,1,4)=="BMO "
	replace lender = "BPD" if substr(lender,1,4)=="BPD "
	replace lender = "RBC" if substr(lender,1,4)=="RBC "
	replace lender = "TD " if substr(lender,1,3)=="TD "
	replace lender = "UBS" if substr(lender,1,4)=="UBS "
	replace lender = "UFJ" if substr(lender,1,4)=="UFJ "
	replace lender = "CIBC" if substr(lender,1,5)=="CIBC "
	replace lender = "DBS" if substr(lender,1,4)=="DBS "
	replace lender = "ING" if substr(lender,1,4)=="ING "
	replace lender = "RBS" if substr(lender,1,4)=="RBS "
	replace lender = "GSO" if substr(lender,1,4)=="GSO "
	replace lender = "IBJ" if substr(lender,1,4)=="IBJ "
	replace lender = "HSH" if substr(lender,1,4)=="HSH "
	replace lender = "OCM" if substr(lender,1,4)=="OCM "
	replace lender = "RHB" if substr(lender,1,4)=="RHB "
	replace lender = "ICBC" if substr(lender,1,5)=="ICBC "
	replace lender = "ICICI" if substr(lender,1,6)=="ICICI "
	replace lender = "Fidelity" if substr(lender,1,9)=="Fidelity "
	replace lender = "Fortress" if substr(lender,1,9)=="Fortress "


	replace lender = "CIT" if substr(lender,1,4)=="CIT "
	replace lender = "KZH" if substr(lender,1,3)=="KZH"
	replace lender = "PNC" if substr(lender,1,4)=="PNC "

	replace lender = "Banca Popolare" if regexm(lender, "Banca Popolare")
	replace lender = "Bank One" if regexm(lender, "Bank One")
	replace lender = "Bank of Tokyo" if regexm(lender, "Bank of Tokyo")
	replace lender = "Barclays" if regexm(lender,"Barclays")
	replace lender = "Black Diamond" if regexm(lender, "Black Diamond")
	replace lender = "BlackRock" if regexm(lender, "Blackrock") | regexm(lender,"BlackRock") | ///
									regexm(lender,"Black rock") | regexm(lender,"Black Rock")
	replace lender = "Carlyle" if regexm(lender, "Carlyle") 
	replace lender = "Caspian" if regexm(lender, "Caspian")
	replace lender = "Citibank" if regexm(lender, "Citibank")
	replace lender = "Citigroup" if regexm(lender, "Citigroup")
	replace lender = "Commerzbank" if regexm(lender, "Commerzbank") | regexm(lender, "Comerzbank")
	replace lender = "Chase Manhattan" if regexm(lender, "Chase Manhattan")
	replace lender = "Chang Hwa Commerican Bank" if regexm(lender, "Chan") & regexm(lender,"wa")
	replace lender = "China Construction Bank" if regexm(lender, "China Construction Bank")
	replace lender = "Citizens Bank" if regexm(lender, "Citizens Bank")
	replace lender = "Credit Agricole" if regexm(lender, "Credit Agricole")
	replace lender = "Credit Industriel et Commercial" if regexm(lender, "Credit Industriel")
	replace lender = "Credit Lyonnais" if regexm(lender, "Credit Lyonnais")
	replace lender = "Credit Suisse" if regexm(lender, "Credit Suisse")
	replace lender = "CypressTree" if regexm(lender, "Cypress") & regexm(lender,"ree")
	replace lender = "Eaton Vance" if regexm(lender, "Eaton Vance") | regexm(lender,"Eatonvance")
	replace lender = "Farm Credit" if regexm(lender, "Farm Credit")
	replace lender = "First Commercial Bank" if regexm(lender, "First Commercial")
	replace lender = "First Union" if regexm(lender, "First Union")
	replace lender = "First National Bank" if regexm(lender, "First National Bank")
	replace lender = "Fortis" if regexm(lender, "Fortis")
	replace lender = "GE" if substr(lender,1,3) == "GE "
	replace lender = "General Electric" if regexm(lender, "General Electric")
	replace lender = "GoldenTree" if regexm(lender, "Golden") & (regexm(lender,"tree") | regexm(lender,"Tree"))
	replace lender = "Golub Capital" if regexm(lender, "Golub Capital")
	replace lender = "Goldman Sachs" if regexm(lender,"Goldman Sachs")
	replace lender = "Guggenheim" if regexm(lender,"Guggenheim")
	replace lender = "Highland" if regexm(lender,"Highland")
	replace lender = "Highbridge" if regexm(lender,"Highbridge")
	replace lender = "HSBC" if regexm(lender, "HSBC")
	replace lender = "Hua Nan Commercial Bank" if regexm(lender, "Hua Nan Commercial Bank")
	replace lender = "Industrial & Commercial Bank of China" if regexm(lender,"Industrial & Commercial Bank of China")
	replace lender = "Intesa Sanpaolo" if regexm(lender,"Intesa")
	replace lender = "Jefferies" if regexm(lender,"Jefferies")
	replace lender = "JP Morgan" if regexm(lender, "JP Morgan") | regexm(lender,"JPM")
	replace lender = "KKR" if regexm(lender, "KKR")
	replace lender = "Lehman" if regexm(lender, "Lehman")
	replace lender = "John Hancock" if regexm(lender, "John Hancock")
	replace lender = "Lloyds" if regexm(lender, "Lloyds")
	replace lender = "Mass Mutual" if regexm(lender, "Mass") & regexm(lender,"utual")
	replace lender = "Macquarie" if regexm(lender, "Macquarie")
	replace lender = "Maybank" if regexm(lender, "Maybank")
	replace lender = "Mega International Commercial Bank" if regexm(lender,"Mega International")
	replace lender = "Merrill Lynch" if regexm(lender,"Merrill Lynch")
	replace lender = "Monroe Capital" if regexm(lender,"Monroe Capital")
	replace lender = "Morgan Stanley" if regexm(lender,"Morgan Stanley")
	replace lender = "MetLife" if regexm(lender,"Metlife") | regexm(lender,"MetLife") ///
					| (regexm(lender,"Metropolitan") & regexm(lender,"ife"))
					
	replace lender = "Mitsubishi" if regexm(lender,"Mitsubishi")
	replace lender = "Mizuho" if regexm(lender,"Mizuho")
	replace lender = "Nomura" if regexm(lender,"Nomura")
	replace lender = "Oak Hill" if regexm(lender,"Oak Hill")
	replace lender = "PIMCO" if regexm(lender,"PIMCO") | regexm(lender,"Pimco")
	replace lender = "Pilgrim" if substr(lender,1,8) == "Pilgrim "
	replace lender = "Provident" if regexm(lender,"Provident ")
	replace lender = "Prudential" if regexm(lender,"Prudential")
	replace lender = "Putnam" if regexm(lender,"Putnam")
	replace lender = "PT Bank" if regexm(lender,"PT Bank")
	replace lender = "Rabobank" if regexm(lender,"Rabobank")
	replace lender = "Raymond James" if regexm(lender,"Raymond James")
	replace lender = "Santander" if regexm(lender,"Santander")
	replace lender = "Scotiabank" if regexm(lender,"Scotiabank")
	replace lender = "Societe Generale" if regexm(lender,"Societe Generale")
	replace lender = "State Bank of India" if regexm(lender,"State Bank of India")
	replace lender = "Sumitomo Mitsui" if regexm(lender,"Sumitomo Mitsui")
	replace lender = "SunTrust" if regexm(lender,"SunTrust") | regexm(lender,"Suntrust")
	replace lender = "Transamerica" if regexm(lender,"Transamerica") | regexm(lender,"TransAmerica")
	replace lender = "UniCredit" if regexm(lender,"UniCredit")
	replace lender = "Union Bank" if regexm(lender,"Union Bank")
	replace lender = "Wachovia" if regexm(lender,"Wachovia")
	replace lender = "Washington Mutual" if regexm(lender,"Washington Mutual")
	replace lender = "Wells Fargo" if regexm(lender,"Wells Fargo")
	replace lender = "Monroe Capital" if regexm(lender,"Monroe")
	replace lender = "Monroe Capital" if regexm(lender,"MC Financing")


	foreach i in "Royal Bank of Canada" "Royal Bank of Scotland" "SBI" "SMBC" ///
		"Sankaty" "Salomon Smith Barney" "Scottrade" "Shanghai Commercial" ///
		"Southwest Bank" "Standard Chartered Bank" "Stanfield" "Svenska Handelsbanken" ///
		"TIAA" "Taipei Fubon Commercial Bank" "Tennenbaum" "Toronto Dominion" "Travelers" ///
		"Van Kampen" "Whippoorwill" "Whitehall" "William Street" "Bayerische Landesbank" ///
		"Bear Stearns" "Capital One" "Captiva" "Citicorp" "City National Bank" "Clydesdale" ///
		"Comerica Bank" "DE Shaw" "Daiwa Securities" "Denali" "Dryden" "Farallon"  ///
		"Foothill" "Franklin" "Gallatin" "General Motors" "Gulf Stream" "Indosuez Capital" ///
		"International Commercial Bank of China" "Laurentian" "Lazard" "Liberty Mutual" ///
		"LightPoint" "MUFG" "Magnetite" "Mainstay" "Malayan Banking" "Mellon Bank" ///
		"NatWest" "National Australia Bank" "National City Bank" "National Westminster Bank" ///
		"Nationwide" "Nedbank" "Nordea Bank" "Northern Trust" "Nuveen" "Oaktree" "Bain Capital" ///
		"Bank of America" "BB&T" "B Riley" "Cantor Fitzgerald" "Comerica" "Countrywide" ///
		"Daiwa" "Deutsche Bank"  "Fifth Third" "First Horizon" "La Salle" "Loop" "Mesirow" ///
		"Natixis" "Oppenheimer" "Stifel" "Truist" ///
		{
			
			replace lender = "`i'" if regexm(lender,"`i'")
		
		}
		
		
		
	foreach i in "Sanpaolo" "Sao Paolo" "TCW" "TRS" "VTB" "CIC" "CIMB" "CITIC" "CRG" "CSAM" ///
					"Canyon" "DB" "DMG" "DNB" "DVB" "DZ" "ELT" "FCS" "GMAC" "GSC" ///
					"Guaranty" "HVB" "Halcyon" "Halifax" "Hyundai" "IXIS" "Invesco" ///
					"KBC" "KDB" "KfW" "M&I" "M&T" "MCG" "MCS" "Mariner" "NYLIM" "ORIX" ///
					"BNY" "BNZ" "Scotia" ///
					{
		local x = length("`i'")+1
		replace lender = "`i'" if substr(lender,1,`x') == "`i' "
	}


	* Standardize Names to match ZBO:

	* check on abn amro

	replace lender = "Academy" if lender == "Academy Securities"
	replace lender = "AIG" if lender == "American International Group"
	replace lender = "Banco Santander" if lender == "Santander"
	replace lender = "BBVA" if lender == "Banco Bilbao Vizcaya Argentaria"
	replace lender = "CITI" if inlist(lender,"Citibank","Citigroup","Citicorp")
	replace lender = "JP Morgan" if regexm(lender,"Chase Manhattan")
	replace lender = "Bank of America" if regexm(lender,"Merrill Lynch")
	replace lender = "CIBC" if regexm(lender,"Canadian Imperial Bank of Commerce")
	replace lender = "Fleet Boston" if regexm(lender, "Fleet")
	replace lender = "Greenwich" if regexm(lender, "Greenwich Capital")
	replace lender = "Keybanc" if regexm(lender,"Keybank") | regexm(lender,"KeyBank") | regexm(lender,"Key Bank")
	replace lender = "RBC" if regexm(lender,"Royal Bank of Canada")
	replace lender = "RBS" if regexm(lender,"Royal Bank of Scotland")
	replace lender = "Toronto Dom" if regexm(lender,"Toronto") & regexm(lender,"Dominion")
	replace lender = "Wells Fargo" if lender == "Wachovia"

	replace lender = subinstr(lender," Bank","",.) if substr(lender,-5,.) == " Bank"

	replace lender = upper(lender)

end
