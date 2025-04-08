Here is the documentation for the code:  
  
Python Code: 
•	Relationship_main: everything goes through this file, and it calls all of the other programs.  
•	Pull_raw_wrds:  This file downloads all WRDS files and gets all of the tables ready in the relational database  
o	Pull_raw: This program downloads all of the relevant WRDS tables and then uploads them to my own relational database  
o	Clean_link_table: This file reads in the Chava and Roberts Link Table and uploads to the database. This link table is how you merge compustat to dealscan  
•	Merge_data: This file joins together all of the dealscan tables into one, the capital IQ tables into one, and all of the compustat tables into one. The output will be three CSV files that will be able to be merged with each other later one (in Stata)  
o	Merge_dealscan: This merges together 9 tables from Dealscan into one table using IBIS. Will merge onto compustat using  “borrowercompanyid  
o	Merge_compustat: This merges together 3 tables from Compustat and the Chava Roberts crosswalk into one table using IBIS. Will merge onto dealscan using using “bcoid” (borrowercompanyid)  
o	Merge_capiq: This merges three capital IQ tables into one, where this contains ratings. Will merge onto compustat using “gvkey”  
o	Export_sdc: This queries the relational database exports the SDC files that are read in by “read_in_sdc”  
•	Read_in_sdc: This reads in the debt and equity issuance files from SDC platinum and uploads them to the relational database. Will merge with compustat using the six digit cusip.  
Stata Code:  
Everything goes through master.do, which will take your from beginning to end of our analysis  
Stata code to generate datasets_for_analysis:  
•	settings.do  
o	This file sets some globals and paths that are used  
•	Clean_capiq: This file cleans the capital IQ file and prepares it for merging  
•	Clean_compustat: This file prepares the compustat dataset for merge and generates various variables  
•	Clean_fred: This file imports some rates from FRED  
•	Clean_dealscan: Prepares dealscan dataset for merge and makes various variables, including the measures of discount.  
•	Clean_sdc: Prepares the SDC debt and equity datasets  
•	Make_ds_lender_data_with_comp: This file merges together Dealscan loan dat  a with compustat (using borrowercompanyid)  
•	Make_sdc_data_with_comp: This file merges SDC data to compustat (using Cusip6)  
•	Make sdc_dealscan_stacked_data: Appends the dealscan and SDC data. Then creates variables of future business relationships between firms and banks. At this point, we have a dataset that is by public borrower, each syndicated loan (with who was the lead arranger) and each debt issuance (and who was the bookrunner) and each equity issuance (and who was the bookrunner).  
Stata Analysis  
•	Analysis_sdc_issuance_relationship: Performs regressions of whether a bank is chosen for debt/equity deals on whether there is a bank-firm relationship. And then see if there is any impact on the fee charged.  
•	Analysis_ds_lending_relationship: Performs regressions of whether a bank is chosen as a lead arranger for loans deals on whether there is a bank-firm relationship. And then see if there is any impact on the fee charged.  
•	Analysis_loan_char_diff: Make figures that show whether the discounts look different after including loan characteristics   
•	Analysis_relationship_quid_pro_quo: See how discounts change from the first loan package to future ones.   
•	Analysis_information: Look at how ratings are correlated with discounts  
•	Analysis_reselling: See how discounts related to the number of institutional investors on the institutional term loans  
•	Analysis_supply_curve: See how discounts related to the proportion of the loan package that is a revolving line of credit.  
•	Figures_paper_slides: Make figures for the paper and slides  
•	Simple_tables_paper_slides: Make simple tables, such as summary stats  
•	Regressions_tables_paper_slides: Have all of the regressions that are used in the paper  
•	Calculations_for_paper_slides: Any random calculation used in the paper is done here.  

