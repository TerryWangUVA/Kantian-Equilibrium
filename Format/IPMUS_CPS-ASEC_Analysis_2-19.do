/*--------------------------------------------------
For analyzing IPMUS ACS Data (2019 - 2024)

					Edit history

	01-13-2026: Started.
	01-23-2026: Removed legacy code. 
	02-06-2026: Added unemployment regs
	03-13-2026: fixed merging issue
----------------------------------------------------*/

//================== Set Direcotry =======================//
global folder "C:\Projects\DMP"
cd "$folder"
global raw "$folder/raw"
global output "$folder/output"

/*
cap mkdir "$folder/output"
cap mkdir "$folder/output/tables"
cap mkdir "$folder/output/graphs"
cap mkdir "$folder/output/cleandata"
*/

global tables "$output/tables"
global graphs "$output/graphs"
global data "$output/data"


set more off
///////////////////////////////////////////////////////////



*************************************
**# Prepare dataset
*************************************

use "$data/CPS-ASEC_analysis_Dec01", clear


// drop highschool dropouts and below

keep if educ >= 73

// keep those in job mkt:
keep if labforce == 2

// calculate lnwage and years of work experience
gen real_wage = incwage * 100 / cpiaucsl
gen lnwage = ln(real_wage)
gen educyrs = .

// 12-02 note: CPS use a different coding system for degrees
replace educyrs = 12 if inlist(educ, 73) // Highschool 
replace educyrs = 16 if inlist(educ, 111) // BA              
replace educyrs = 18 if inlist(educ, 123) // MA 
replace educyrs = 19 if inlist(educ, 124) // Professional 
replace educyrs = 20 if inlist(educ, 125) // PhD



gen exp = age - educyrs - 6


replace exp = max(exp,0) 
gen exp2 = exp^2

// merge m:1 soc_gr using "$data/interim/ACS_Rating_Gr"

replace occsoc = strtrim(occsoc)
rename occsoc occsoc_2010



local ratings ///
	dv_rating_alpha dv_rating_beta dv_rating_gamma ///
	human_rating_alpha human_rating_beta human_rating_gamma ///

merge m:1 occsoc_2010 using "$data/Eloundou_updated_crosswalk"

ren _merge _merge1


preserve 
	
	keep if _merge1 == 3
	tempfile Mer1
	save `Mer1', replace
	
restore

keep if _merge1 == 1
replace occsoc_2010 = substr(occsoc_2010,1,6) + "X"

drop `ratings'

merge m:1 occsoc_2010 using "$data/Eloundou_updated_crosswalk"
rename _merge _merge2


preserve 
	
	keep if _merge2 == 1 
	drop `ratings'
	replace occsoc_2010 = substr(occsoc_2010,1,5) + "XX" 
	merge m:1 occsoc_2010 using "$data/Eloundou_updated_crosswalk"
	rename _merge _merge3 
	keep if _merge3 == 3 
	tempfile Mer3 
	save `Mer3', replace

restore

 
keep if _merge2 == 3
tempfile Mer2
save `Mer2', replace



use `Mer1', clear
append using `Mer2'
append using `Mer3'




gen compmath = inlist(soc_gr, 21)
gen post2023 = (year > 2023)

gen is_college = educ > 110



preserve

	collapse (mean) `ratings', by(soc_gr)

	keep soc_gr `ratings'

	tempfile crosswalk
	save `crosswalk', replace
 
restore






**************************************************
**# Setup
**************************************************


gen unemployed = inlist(empstat, 21, 22)


tempfile analysis
save `analysis', replace

eststo clear






**************************************************
**# Log wage regressions
**************************************************

* Set omitted year to 2022
fvset base 2022 year

*------------------*
* Table A: simple
*------------------*

reghdfe lnwage i.year##c.dv_rating_beta, ///
    noabsorb cluster(occsoc)
estadd scalar obs = e(N)
estadd local sex_FE "No"
estadd local educ_FE "No"
estadd local se_cluster "Occupation"
sum lnwage if e(sample)
estadd scalar depvar_mean = r(mean)
eststo lw_A1

reghdfe lnwage i.year##c.dv_rating_beta, ///
    absorb(sex) cluster(occsoc)
estadd scalar obs = e(N)
estadd local sex_FE "Yes"
estadd local educ_FE "No"
estadd local se_cluster "Occupation"
sum lnwage if e(sample)
estadd scalar depvar_mean = r(mean)
eststo lw_A2

reghdfe lnwage i.year##c.dv_rating_beta, ///
    absorb(sex educ) cluster(occsoc)
estadd scalar obs = e(N)
estadd local sex_FE "Yes"
estadd local educ_FE "Yes"
estadd local se_cluster "Occupation"
sum lnwage if e(sample)
estadd scalar depvar_mean = r(mean)
eststo lw_A3


*------------------*
* Table B: exp interaction
*------------------*

reghdfe lnwage c.exp##i.year##c.dv_rating_beta, ///
    noabsorb cluster(occsoc)
estadd scalar obs = e(N)
testparm 2024.year#c.exp#c.dv_rating_beta ///
         2025.year#c.exp#c.dv_rating_beta
estadd scalar Ftest_p = r(p)
estadd local sex_FE "No"
estadd local educ_FE "No"
estadd local se_cluster "Occupation"
sum lnwage if e(sample)
estadd scalar depvar_mean = r(mean)
eststo lw_B1

reghdfe lnwage c.exp##i.year##c.dv_rating_beta, ///
    absorb(sex) cluster(occsoc)
estadd scalar obs = e(N)
testparm 2024.year#c.exp#c.dv_rating_beta ///
         2025.year#c.exp#c.dv_rating_beta
estadd scalar Ftest_p = r(p)
estadd local sex_FE "Yes"
estadd local educ_FE "No"
estadd local se_cluster "Occupation"
sum lnwage if e(sample)
estadd scalar depvar_mean = r(mean)
eststo lw_B2

reghdfe lnwage c.exp##i.year##c.dv_rating_beta, ///
    absorb(sex educ) cluster(occsoc)
estadd scalar obs = e(N)
testparm 2024.year#c.exp#c.dv_rating_beta ///
         2025.year#c.exp#c.dv_rating_beta
estadd scalar Ftest_p = r(p)
estadd local sex_FE "Yes"
estadd local educ_FE "Yes"
estadd local se_cluster "Occupation"
sum lnwage if e(sample)
estadd scalar depvar_mean = r(mean)
eststo lw_B3


**************************************************
**# Unemployment regressions 
**************************************************

*------------------*
* Table A: simple
*------------------*

reghdfe unemployed i.year##c.dv_rating_beta, ///
    noabsorb cluster(occsoc)
estadd scalar obs = e(N)
estadd local sex_FE "No"
estadd local educ_FE "No"
estadd local se_cluster "Occupation"
sum unemployed if e(sample)
estadd scalar depvar_mean = r(mean)
eststo un_A1

reghdfe unemployed i.year##c.dv_rating_beta, ///
    absorb(sex) cluster(occsoc)
estadd scalar obs = e(N)
estadd local sex_FE "Yes"
estadd local educ_FE "No"
estadd local se_cluster "Occupation"
sum unemployed if e(sample)
estadd scalar depvar_mean = r(mean)
eststo un_A2

reghdfe unemployed i.year##c.dv_rating_beta, ///
    absorb(sex educ) cluster(occsoc)
estadd scalar obs = e(N)
estadd local sex_FE "Yes"
estadd local educ_FE "Yes"
estadd local se_cluster "Occupation"
sum unemployed if e(sample)
estadd scalar depvar_mean = r(mean)
eststo un_A3


*------------------*
* Table B: exp interaction
*------------------*

reghdfe unemployed c.exp##i.year##c.dv_rating_beta, ///
    noabsorb cluster(occsoc)
estadd scalar obs = e(N)
testparm 2024.year#c.exp#c.dv_rating_beta ///
         2025.year#c.exp#c.dv_rating_beta
estadd scalar Ftest_p = r(p)
estadd local sex_FE "No"
estadd local educ_FE "No"
estadd local se_cluster "Occupation"
sum unemployed if e(sample)
estadd scalar depvar_mean = r(mean)
eststo un_B1

reghdfe unemployed c.exp##i.year##c.dv_rating_beta, ///
    absorb(sex) cluster(occsoc)
estadd scalar obs = e(N)
testparm 2024.year#c.exp#c.dv_rating_beta ///
         2025.year#c.exp#c.dv_rating_beta
estadd scalar Ftest_p = r(p)
estadd local sex_FE "Yes"
estadd local educ_FE "No"
estadd local se_cluster "Occupation"
sum unemployed if e(sample)
estadd scalar depvar_mean = r(mean)
eststo un_B2

reghdfe unemployed c.exp##i.year##c.dv_rating_beta, ///
    absorb(sex educ) cluster(occsoc)
estadd scalar obs = e(N)
testparm 2024.year#c.exp#c.dv_rating_beta ///
         2025.year#c.exp#c.dv_rating_beta
estadd scalar Ftest_p = r(p)
estadd local sex_FE "Yes"
estadd local educ_FE "Yes"
estadd local se_cluster "Occupation"
sum unemployed if e(sample)
estadd scalar depvar_mean = r(mean)
eststo un_B3


////////////////////////////////////////////////////////////////////////////////
local keepA ///
    2018.year#c.dv_rating_beta ///
    2019.year#c.dv_rating_beta ///
    2020.year#c.dv_rating_beta ///
    2021.year#c.dv_rating_beta ///
    2023.year#c.dv_rating_beta ///
    2024.year#c.dv_rating_beta ///
    2025.year#c.dv_rating_beta

local keepB ///
    2018.year#c.exp#c.dv_rating_beta ///
    2019.year#c.exp#c.dv_rating_beta ///
    2020.year#c.exp#c.dv_rating_beta ///
    2021.year#c.exp#c.dv_rating_beta ///
    2023.year#c.exp#c.dv_rating_beta ///
    2024.year#c.exp#c.dv_rating_beta ///
    2025.year#c.exp#c.dv_rating_beta

**************************************************
** Table: logwage A
**************************************************

esttab lw_A1 lw_A2 lw_A3 ///
    using "$tables/logwage_tableA.tex", replace ///
    cells(b(star fmt(a3)) se(fmt(a3) par)) ///
    style(tex) se starlevels(* 0.10 ** 0.05 *** 0.01) ///
    keep(`keepA') ///
    varlabels( ///
        2018.year#c.dv_rating_beta "2018 $\times$ AI exposure" ///
        2019.year#c.dv_rating_beta "2019 $\times$ AI exposure" ///
        2020.year#c.dv_rating_beta "2020 $\times$ AI exposure" ///
        2021.year#c.dv_rating_beta "2021 $\times$ AI exposure" ///
        2023.year#c.dv_rating_beta "2023 $\times$ AI exposure" ///
        2024.year#c.dv_rating_beta "2024 $\times$ AI exposure" ///
        2025.year#c.dv_rating_beta "2025 $\times$ AI exposure" ///
    ) ///
    stats(depvar_mean sex_FE educ_FE se_cluster obs, ///
          fmt(3 0 0 0 %12.0gc) ///
          labels("Mean of dependent variable" ///
                 "Sex FE" ///
                 "Education FE" ///
                 "SE clustered at" ///
                 "Observations")) ///
    booktabs collabels(none) mlabels(none) nonumbers nomtitles gaps nonotes ///
    prehead( ///
        "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
        "\begin{tabular}{l*{3}{c}}" ///
        "\toprule" ///
        "Dependent Variable: & \multicolumn{3}{c}{Log Wage} \\" ///
        "\cmidrule(lr){2-4}" ///
        " & (1) & (2) & (3) \\" ///
    ) ///
    postfoot( ///
        "\bottomrule" ///
        "\end{tabular}" )


**************************************************
** Table: logwage B
**************************************************

esttab lw_B1 lw_B2 lw_B3 ///
    using "$tables/logwage_tableB.tex", replace ///
    cells(b(star fmt(a3)) se(fmt(a3) par)) ///
    style(tex) se starlevels(* 0.10 ** 0.05 *** 0.01) ///
    keep(`keepB') ///
    varlabels( ///
        2018.year#c.exp#c.dv_rating_beta "2018 $\times$ Experience $\times$ AI exposure" ///
        2019.year#c.exp#c.dv_rating_beta "2019 $\times$ Experience $\times$ AI exposure" ///
        2020.year#c.exp#c.dv_rating_beta "2020 $\times$ Experience $\times$ AI exposure" ///
        2021.year#c.exp#c.dv_rating_beta "2021 $\times$ Experience $\times$ AI exposure" ///
        2023.year#c.exp#c.dv_rating_beta "2023 $\times$ Experience $\times$ AI exposure" ///
        2024.year#c.exp#c.dv_rating_beta "2024 $\times$ Experience $\times$ AI exposure" ///
        2025.year#c.exp#c.dv_rating_beta "2025 $\times$ Experience $\times$ AI exposure" ///
    ) ///
    stats(depvar_mean sex_FE educ_FE se_cluster obs, ///
          fmt(3 0 0 0 %12.0gc) ///
          labels("Mean of dependent variable" ///
                 "Sex FE" ///
                 "Education FE" ///
                 "SE clustered at" ///
                 "Observations")) ///
    booktabs collabels(none) mlabels(none) nonumbers nomtitles gaps nonotes ///
    prehead( ///
        "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
        "\begin{tabular}{l*{3}{c}}" ///
        "\toprule" ///
        "Dependent Variable: & \multicolumn{3}{c}{Log Wage} \\" ///
        "\cmidrule(lr){2-4}" ///
        " & (1) & (2) & (3) \\" ///
    ) ///
    postfoot( ///
        "\bottomrule" ///
        "\end{tabular}" )


**************************************************
** Table: unemployment A
**************************************************

esttab un_A1 un_A2 un_A3 ///
    using "$tables/unemployment_tableA.tex", replace ///
    cells(b(star fmt(a3)) se(fmt(a3) par)) ///
    style(tex) se starlevels(* 0.10 ** 0.05 *** 0.01) ///
    keep(`keepA') ///
    varlabels( ///
        2018.year#c.dv_rating_beta "2018 $\times$ AI exposure" ///
        2019.year#c.dv_rating_beta "2019 $\times$ AI exposure" ///
        2020.year#c.dv_rating_beta "2020 $\times$ AI exposure" ///
        2021.year#c.dv_rating_beta "2021 $\times$ AI exposure" ///
        2023.year#c.dv_rating_beta "2023 $\times$ AI exposure" ///
        2024.year#c.dv_rating_beta "2024 $\times$ AI exposure" ///
        2025.year#c.dv_rating_beta "2025 $\times$ AI exposure" ///
    ) ///
    stats(depvar_mean sex_FE educ_FE se_cluster obs, ///
          fmt(3 0 0 0 %12.0gc) ///
          labels("Mean of dependent variable" ///
                 "Sex FE" ///
                 "Education FE" ///
                 "SE clustered at" ///
                 "Observations")) ///
    booktabs collabels(none) mlabels(none) nonumbers nomtitles gaps nonotes ///
    prehead( ///
        "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
        "\begin{tabular}{l*{3}{c}}" ///
        "\toprule" ///
        "Dependent Variable: & \multicolumn{3}{c}{Unemployment} \\" ///
        "\cmidrule(lr){2-4}" ///
        " & (1) & (2) & (3) \\" ///
    ) ///
    postfoot( ///
        "\bottomrule" ///
        "\end{tabular}" )


**************************************************
** Table: unemployment B
**************************************************

esttab un_B1 un_B2 un_B3 ///
    using "$tables/unemployment_tableB.tex", replace ///
    cells(b(star fmt(a3)) se(fmt(a3) par)) ///
    style(tex) se starlevels(* 0.10 ** 0.05 *** 0.01) ///
    keep(`keepB') ///
    varlabels( ///
        2018.year#c.exp#c.dv_rating_beta "2018 $\times$ Experience $\times$ AI exposure" ///
        2019.year#c.exp#c.dv_rating_beta "2019 $\times$ Experience $\times$ AI exposure" ///
        2020.year#c.exp#c.dv_rating_beta "2020 $\times$ Experience $\times$ AI exposure" ///
        2021.year#c.exp#c.dv_rating_beta "2021 $\times$ Experience $\times$ AI exposure" ///
        2023.year#c.exp#c.dv_rating_beta "2023 $\times$ Experience $\times$ AI exposure" ///
        2024.year#c.exp#c.dv_rating_beta "2024 $\times$ Experience $\times$ AI exposure" ///
        2025.year#c.exp#c.dv_rating_beta "2025 $\times$ Experience $\times$ AI exposure" ///
    ) ///
    stats(depvar_mean sex_FE educ_FE se_cluster obs, ///
          fmt(3 0 0 0 %12.0gc) ///
          labels("Mean of dependent variable" ///
                 "Sex FE" ///
                 "Education FE" ///
                 "SE clustered at" ///
                 "Observations")) ///
    booktabs collabels(none) mlabels(none) nonumbers nomtitles gaps nonotes ///
    prehead( ///
        "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
        "\begin{tabular}{l*{3}{c}}" ///
        "\toprule" ///
        "Dependent Variable: & \multicolumn{3}{c}{Unemployment} \\" ///
        "\cmidrule(lr){2-4}" ///
        " & (1) & (2) & (3) \\" ///
    ) ///
    postfoot( ///
        "\bottomrule" ///
        "\end{tabular}" )

**************************************************
** 6 coef plots: only double interactions
** year x dv_rating_beta, baseline year = 2022
**************************************************

cap ssc install parmest, replace

**************************************************
** coefficient names to keep
**************************************************
local keepA ///
    2018.year#c.dv_rating_beta ///
    2019.year#c.dv_rating_beta ///
    2020.year#c.dv_rating_beta ///
    2021.year#c.dv_rating_beta ///
    2023.year#c.dv_rating_beta ///
    2024.year#c.dv_rating_beta ///
    2025.year#c.dv_rating_beta

**************************************************
** helper program: extract one stored estimate
**************************************************
cap program drop make_coef_file
program define make_coef_file
    syntax, ESTname(name) SPECname(string) OUTcome(string) OUTfile(string)

    est restore `estname'
    parmest, norestore

    keep if inlist(parm, ///
        "2018.year#c.dv_rating_beta", ///
        "2019.year#c.dv_rating_beta", ///
        "2020.year#c.dv_rating_beta", ///
        "2021.year#c.dv_rating_beta", ///
        "2023.year#c.dv_rating_beta", ///
        "2024.year#c.dv_rating_beta", ///
        "2025.year#c.dv_rating_beta")

    gen year = .
    replace year = 2018 if parm == "2018.year#c.dv_rating_beta"
    replace year = 2019 if parm == "2019.year#c.dv_rating_beta"
    replace year = 2020 if parm == "2020.year#c.dv_rating_beta"
    replace year = 2021 if parm == "2021.year#c.dv_rating_beta"
    replace year = 2023 if parm == "2023.year#c.dv_rating_beta"
    replace year = 2024 if parm == "2024.year#c.dv_rating_beta"
    replace year = 2025 if parm == "2025.year#c.dv_rating_beta"

    gen spec = "`specname'"
    gen outcome = "`outcome'"

    keep year estimate min95 max95 spec outcome
    sort year
    save "`outfile'", replace
end

**************************************************
** extract coefficient datasets
**************************************************

tempfile lw_naive lw_sex lw_sexeduc un_naive un_sex un_sexeduc

make_coef_file, estname(lw_A1) specname("Naive") outcome("Log wage") outfile(`lw_naive')
make_coef_file, estname(lw_A2) specname("Sex FE") outcome("Log wage") outfile(`lw_sex')
make_coef_file, estname(lw_A3) specname("Sex + educ FE") outcome("Log wage") outfile(`lw_sexeduc')

make_coef_file, estname(un_A1) specname("Naive") outcome("Unemployment") outfile(`un_naive')
make_coef_file, estname(un_A2) specname("Sex FE") outcome("Unemployment") outfile(`un_sex')
make_coef_file, estname(un_A3) specname("Sex + educ FE") outcome("Unemployment") outfile(`un_sexeduc')

*------------------*
* Log wage: naive
*------------------*
use `lw_naive', clear
insobs 1
replace year = 2022 in L
replace estimate = 0 in L
replace min95 = . in L
replace max95 = . in L
sort year

twoway ///
    (rcap min95 max95 year if inlist(year,2018,2019,2020,2021,2023,2024,2025), ///
        lcolor(navy) lpattern(solid) lwidth(medthin)) ///
    (line estimate year, ///
        lcolor(maroon) lpattern(solid) lwidth(medium)) ///
    (scatter estimate year, ///
        mcolor(maroon) msymbol(O) msize(medlarge)), ///
    xline(2022.5, lcolor(gs8) lpattern(dash)) ///
    yline(0, lcolor(gs8) lpattern(solid)) ///
    xlabel(2018(1)2025) ///
    xtitle("Year") ///
    ytitle("Coefficient on year × AI exposure") ///
    title("Log Wage: Naive Specification") ///
    legend(order(3 "Coefficient" 1 "95% CI") rows(1) position(6) region(lstyle(none))) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(logwage_naive_plot, replace)
graph export "$graphs/logwage_naive_plot.pdf", replace


*------------------*
* Log wage: sex FE
*------------------*
use `lw_sex', clear
insobs 1
replace year = 2022 in L
replace estimate = 0 in L
replace min95 = . in L
replace max95 = . in L
sort year

twoway ///
    (rcap min95 max95 year if inlist(year,2018,2019,2020,2021,2023,2024,2025), ///
        lcolor(navy) lpattern(solid) lwidth(medthin)) ///
    (line estimate year, ///
        lcolor(maroon) lpattern(solid) lwidth(medium)) ///
    (scatter estimate year, ///
        mcolor(maroon) msymbol(O) msize(medlarge)), ///
    xline(2022.5, lcolor(gs8) lpattern(dash)) ///
    yline(0, lcolor(gs8) lpattern(solid)) ///
    xlabel(2018(1)2025) ///
    xtitle("Year") ///
    ytitle("Coefficient on year × AI exposure") ///
    title("Log Wage: Sex Fixed Effects") ///
    legend(order(3 "Coefficient" 1 "95% CI") rows(1) position(6) region(lstyle(none))) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(logwage_sexFE_plot, replace)
graph export "$graphs/logwage_sexFE_plot.pdf", replace


*------------------*
* Log wage: sex + educ FE
*------------------*
use `lw_sexeduc', clear
insobs 1
replace year = 2022 in L
replace estimate = 0 in L
replace min95 = . in L
replace max95 = . in L
sort year

twoway ///
    (rcap min95 max95 year if inlist(year,2018,2019,2020,2021,2023,2024,2025), ///
        lcolor(navy) lpattern(solid) lwidth(medthin)) ///
    (line estimate year, ///
        lcolor(maroon) lpattern(solid) lwidth(medium)) ///
    (scatter estimate year, ///
        mcolor(maroon) msymbol(O) msize(medlarge)), ///
    xline(2022.5, lcolor(gs8) lpattern(dash)) ///
    yline(0, lcolor(gs8) lpattern(solid)) ///
    xlabel(2018(1)2025) ///
    xtitle("Year") ///
    ytitle("Coefficient on year × AI exposure") ///
    title("Log Wage: Sex and Education Fixed Effects") ///
    legend(order(3 "Coefficient" 1 "95% CI") rows(1) position(6) region(lstyle(none))) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(logwage_sexeducFE_plot, replace)
graph export "$graphs/logwage_sexeducFE_plot.pdf", replace


**************************************************
** Unemployment plots
**************************************************

*------------------*
* Unemployment: naive
*------------------*
use `un_naive', clear
insobs 1
replace year = 2022 in L
replace estimate = 0 in L
replace min95 = . in L
replace max95 = . in L
sort year

twoway ///
    (rcap min95 max95 year if inlist(year,2018,2019,2020,2021,2023,2024,2025), ///
        lcolor(navy) lpattern(solid) lwidth(medthin)) ///
    (line estimate year, ///
        lcolor(maroon) lpattern(solid) lwidth(medium)) ///
    (scatter estimate year, ///
        mcolor(maroon) msymbol(O) msize(medlarge)), ///
    xline(2022.5, lcolor(gs8) lpattern(dash)) ///
    yline(0, lcolor(gs8) lpattern(solid)) ///
    xlabel(2018(1)2025) ///
    xtitle("Year") ///
    ytitle("Coefficient on year × AI exposure") ///
    title("Unemployment: Naive Specification") ///
    legend(order(3 "Coefficient" 1 "95% CI") rows(1) position(6) region(lstyle(none))) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(unemployment_naive_plot, replace)
graph export "$graphs/unemployment_naive_plot.pdf", replace


*------------------*
* Unemployment: sex FE
*------------------*
use `un_sex', clear
insobs 1
replace year = 2022 in L
replace estimate = 0 in L
replace min95 = . in L
replace max95 = . in L
sort year

twoway ///
    (rcap min95 max95 year if inlist(year,2018,2019,2020,2021,2023,2024,2025), ///
        lcolor(navy) lpattern(solid) lwidth(medthin)) ///
    (line estimate year, ///
        lcolor(maroon) lpattern(solid) lwidth(medium)) ///
    (scatter estimate year, ///
        mcolor(maroon) msymbol(O) msize(medlarge)), ///
    xline(2022.5, lcolor(gs8) lpattern(dash)) ///
    yline(0, lcolor(gs8) lpattern(solid)) ///
    xlabel(2018(1)2025) ///
    xtitle("Year") ///
    ytitle("Coefficient on year × AI exposure") ///
    title("Unemployment: Sex Fixed Effects") ///
    legend(order(3 "Coefficient" 1 "95% CI") rows(1) position(6) region(lstyle(none))) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(unemployment_sexFE_plot, replace)
graph export "$graphs/unemployment_sexFE_plot.pdf", replace


*------------------*
* Unemployment: sex + educ FE
*------------------*
use `un_sexeduc', clear
insobs 1
replace year = 2022 in L
replace estimate = 0 in L
replace min95 = . in L
replace max95 = . in L
sort year

twoway ///
    (rcap min95 max95 year if inlist(year,2018,2019,2020,2021,2023,2024,2025), ///
        lcolor(navy) lpattern(solid) lwidth(medthin)) ///
    (line estimate year, ///
        lcolor(maroon) lpattern(solid) lwidth(medium)) ///
    (scatter estimate year, ///
        mcolor(maroon) msymbol(O) msize(medlarge)), ///
    xline(2022.5, lcolor(gs8) lpattern(dash)) ///
    yline(0, lcolor(gs8) lpattern(solid)) ///
    xlabel(2018(1)2025) ///
    xtitle("Year") ///
    ytitle("Coefficient on year × AI exposure") ///
    title("Unemployment: Sex and Education Fixed Effects") ///
    legend(order(3 "Coefficient" 1 "95% CI") rows(1) position(6) region(lstyle(none))) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(unemployment_sexeducFE_plot, replace)
graph export "$graphs/unemployment_sexeducFE_plot.pdf", replace




*************************************
**# delta %unemployment, 2023-2025
*************************************

use `analysis', clear
eststo clear

collapse (mean) u_rate = unemployed, by(soc_gr year)

keep if inlist(year, 2023, 2025) 

reshape wide u_rate, i(soc_gr) j(year)

gen delta_unemp = u_rate2025 - u_rate2023

merge m:1 soc_gr using `crosswalk'
keep if _merge == 3
drop _merge

twoway ///
    (scatter delta_unemp dv_rating_beta, ///
        msize(small) ///
        mcolor("232 119 34")) ///
    (lfit delta_unemp dv_rating_beta, ///
        lwidth(medthick) ///
        lcolor("0 33 71")), ///
    yline(0) ///
    xscale(range(0 0.8)) ///
    xlabel(0(.2)0.8) ///
    title("Change in Unemployment vs AI Exposure") ///
    ytitle("Δ Unemployment (2025−2023)") ///
    xtitle("AI Exposure (Eloundou Beta)") ///
    legend(order(1 "Occupation" 2 "Linear fit") ///
           position(6) rows(1) region(lstyle(none)))

graph export "$graphs/delta_unemp_2023-2025.pdf", replace


use `analysis', clear



**************************************************
**# Recode education into 4 groups
**************************************************
gen educ4 = .

replace educ4 = 1 if educ == 73
replace educ4 = 2 if inlist(educ, 81, 91, 92)
replace educ4 = 3 if educ == 111
replace educ4 = 4 if inlist(educ, 123, 124, 125)

label define educ4lbl ///
    1 "High school" ///
    2 "Some college" ///
    3 "Bachelor's" ///
    4 "Master's+"
label values educ4 educ4lbl


eststo clear





* year baseline only matters for regression bookkeeping here
fvset base 2022 year
fvset base 1 educ4


local uva_orange "232 119 34"
local uva_navy   "35 45 75"
local uva_blue2  "91 110 140"
local uva_gray   "120 120 120"

**************************************************
** 1. Regressions
**************************************************

* log wage
reghdfe lnwage ib1.educ4##ib2022.year##c.dv_rating_beta, ///
    noabsorb cluster(occsoc)
eststo lw_naive

reghdfe lnwage ib1.educ4##ib2022.year##c.dv_rating_beta, ///
    absorb(sex) cluster(occsoc)
eststo lw_sexFE

* unemployment
reghdfe unemployed ib1.educ4##ib2022.year##c.dv_rating_beta, ///
    noabsorb cluster(occsoc)
eststo un_naive

reghdfe unemployed ib1.educ4##ib2022.year##c.dv_rating_beta, ///
    absorb(sex) cluster(occsoc)
eststo un_sexFE

**************************************************
** 2. Collect coefficients for plotting
**    Object plotted = AI-exposure coefficient
**    for each education-year cell relative to
**    High school in 2022
**************************************************

cap program drop collect_ai_path
program define collect_ai_path
    syntax, ESTNAME(name) SAVING(string)

    est restore `estname'

    tempfile tmp
    postfile handle str20 educgrp int year double b se p using `tmp', replace

    foreach y in 2018 2019 2020 2021 2022 2023 2024 2025 {

        *------------------------------*
        * High school
        *------------------------------*
        if `y' == 2022 {
            post handle ("High school") (`y') (0) (.) (.)
        }
        else {
            capture noisily lincom `y'.year#c.dv_rating_beta
            if _rc == 0 post handle ("High school") (`y') (r(estimate)) (r(se)) (r(p))
            else        post handle ("High school") (`y') (.) (.) (.)
        }

        *------------------------------*
        * Some college
        *------------------------------*
        if `y' == 2022 {
            capture noisily lincom 2.educ4#c.dv_rating_beta
        }
        else {
            capture noisily lincom ///
                2.educ4#c.dv_rating_beta + ///
                `y'.year#c.dv_rating_beta + ///
                2.educ4#`y'.year#c.dv_rating_beta
        }
        if _rc == 0 post handle ("Some college") (`y') (r(estimate)) (r(se)) (r(p))
        else        post handle ("Some college") (`y') (.) (.) (.)

        *------------------------------*
        * Bachelor's
        *------------------------------*
        if `y' == 2022 {
            capture noisily lincom 3.educ4#c.dv_rating_beta
        }
        else {
            capture noisily lincom ///
                3.educ4#c.dv_rating_beta + ///
                `y'.year#c.dv_rating_beta + ///
                3.educ4#`y'.year#c.dv_rating_beta
        }
        if _rc == 0 post handle ("Bachelor's") (`y') (r(estimate)) (r(se)) (r(p))
        else        post handle ("Bachelor's") (`y') (.) (.) (.)

        *------------------------------*
        * Master's+
        *------------------------------*
        if `y' == 2022 {
            capture noisily lincom 4.educ4#c.dv_rating_beta
        }
        else {
            capture noisily lincom ///
                4.educ4#c.dv_rating_beta + ///
                `y'.year#c.dv_rating_beta + ///
                4.educ4#`y'.year#c.dv_rating_beta
        }
        if _rc == 0 post handle ("Master's+") (`y') (r(estimate)) (r(se)) (r(p))
        else        post handle ("Master's+") (`y') (.) (.) (.)
    }

    postclose handle
    use `tmp', clear

    * 95% CI
    gen lb = b - 1.96*se
    gen ub = b + 1.96*se
    replace lb = . if missing(se)
    replace ub = . if missing(se)

    * x-offsets so CIs do not overlap
    gen x = year
    replace x = year - 0.18 if educgrp == "High school"
    replace x = year - 0.06 if educgrp == "Some college"
    replace x = year + 0.06 if educgrp == "Bachelor's"
    replace x = year + 0.18 if educgrp == "Master's+"

    save "`saving'", replace
end

tempfile lw_naive_c lw_sex_c un_naive_c un_sex_c

collect_ai_path, estname(lw_naive) saving(`lw_naive_c')
collect_ai_path, estname(lw_sexFE) saving(`lw_sex_c')
collect_ai_path, estname(un_naive) saving(`un_naive_c')
collect_ai_path, estname(un_sexFE) saving(`un_sex_c')

**************************************************
** 3. Plot helper
**************************************************

cap program drop plot_ai_path
program define plot_ai_path
    syntax using/, OUTFILE(string) TITLE(string) YTITLE(string) GNAME(name)

    use `using', clear
    sort educgrp year

twoway ///
    (rcap lb ub x if educgrp=="High school", ///
        lcolor(navy) lwidth(medthin)) ///
    (line b x if educgrp=="High school", ///
        lcolor(navy) lwidth(medium) sort) ///
    (scatter b x if educgrp=="High school", ///
        mcolor(navy) msymbol(O) msize(medsmall)) ///
    ///
    (rcap lb ub x if educgrp=="Some college", ///
        lcolor(forest_green) lwidth(medthin)) ///
    (line b x if educgrp=="Some college", ///
        lcolor(forest_green) lwidth(medium) sort) ///
    (scatter b x if educgrp=="Some college", ///
        mcolor(forest_green) msymbol(D) msize(medsmall)) ///
    ///
    (rcap lb ub x if educgrp=="Bachelor's", ///
        lcolor(maroon) lwidth(medthin)) ///
    (line b x if educgrp=="Bachelor's", ///
        lcolor(maroon) lwidth(medium) sort) ///
    (scatter b x if educgrp=="Bachelor's", ///
        mcolor(maroon) msymbol(T) msize(medsmall)) ///
    ///
    (rcap lb ub x if educgrp=="Master's+", ///
        lcolor(dkorange) lwidth(medthin)) ///
    (line b x if educgrp=="Master's+", ///
        lcolor(dkorange) lwidth(medium) sort) ///
    (scatter b x if educgrp=="Master's+", ///
        mcolor(dkorange) msymbol(S) msize(medsmall)), ///
    xline(2022.5, lpattern(dash) lcolor(gs8)) ///
    yline(0, lpattern(solid) lcolor(gs10)) ///
    xlabel(2018(1)2025) ///
    xtitle("Year") ///
    ytitle("`ytitle'") ///
    title("`title'") ///
    legend(order(3 "High school" 6 "Some college" 9 "Bachelor's" 12 "Master's+") ///
           rows(1) position(6) region(lstyle(none))) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(`gname', replace)

    graph export "`outfile'", replace
end

**************************************************
** 4. Export the 4 figures
**************************************************

plot_ai_path using `lw_naive_c', ///
    outfile("$graphs/logwage_ai_educ_naive.pdf") ///
    title("Log Wage: AI Exposure Coefficients by Education Group (Naive)") ///
    ytitle("Coefficient relative to High school in 2022") ///
    gname(logwage_ai_educ_naive)

plot_ai_path using `lw_sex_c', ///
    outfile("$graphs/logwage_ai_educ_sexFE.pdf") ///
    title("Log Wage: AI Exposure Coefficients by Education Group (Sex FE)") ///
    ytitle("Coefficient relative to High school in 2022") ///
    gname(logwage_ai_educ_sexFE)

plot_ai_path using `un_naive_c', ///
    outfile("$graphs/unemployment_ai_educ_naive.pdf") ///
    title("Unemployment: AI Exposure Coefficients by Education Group (Naive)") ///
    ytitle("Coefficient relative to High school in 2022") ///
    gname(unemployment_ai_educ_naive)

plot_ai_path using `un_sex_c', ///
    outfile("$graphs/unemployment_ai_educ_sexFE.pdf") ///
    title("Unemployment: AI Exposure Coefficients by Education Group (Sex FE)") ///
    ytitle("Coefficient relative to High school in 2022") ///
    gname(unemployment_ai_educ_sexFE)