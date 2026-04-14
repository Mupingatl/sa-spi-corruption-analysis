/*=======================================================================
  STATA DO-FILE: Papers 2-6 — Social Progress Index Research Programme
  
  Authors: Tumba Dieudonné & Tafadzwa Luke Mupingashato
  Institution: TM-School, University of South Africa (UNISA)
  GitHub: https://github.com/Mupingatl/sa-spi-corruption-analysis
  Contact: mupintl@unisa.ac.za | ORCID: 0000-0001-6119-9234
  
  DATA: Social Progress Imperative (2021), CC BY 4.0
  
  ─────────────────────────────────────────────────────────────────────
  PAPER 2: The Inclusiveness Trap (Development Southern Africa)
  PAPER 3: African Convergence Panel Analysis (AREF)
  PAPER 4: Foundations of Wellbeing / ICT decomposition (Acta Commercii)
  PAPER 5: SPI as welfare measure — methodology (JSES)
  PAPER 6: Personal Safety and governance (SA Crime Quarterly)
  ─────────────────────────────────────────────────────────────────────
  
  REQUIRED FILES IN data/ FOLDER:
    sa_spi_national_stata_ready.csv      (South Africa, 2011-2021, N=11)
    sa_africa_spi_panel_stata_ready.csv  (13 countries × 11 years, N=143)
=======================================================================*/

clear all
set more off
set linesize 140
cap log close
log using "output/papers_2_to_6_log.txt", replace text

*-----------------------------------------------------------------------
* LOAD AND PREPARE SA NATIONAL DATA
*-----------------------------------------------------------------------
import delimited "data/sa_spi_national_stata_ready.csv", clear varnames(1)

* Rename core variables
rename social_progress_index      spi
rename basic_human_needs          bhn
rename foundations_of_wellbeing   fow
rename opportunity                opp
rename personal_safety            comp_safety
rename inclusiveness              comp_incl
rename access_to_advanced_education comp_advEdu
rename personal_rights            comp_rights
rename personal_freedom_and_choice comp_freedom
rename access_to_basic_knowledge  comp_know
rename access_to_information_and_commun comp_ict
rename health_and_wellness        comp_health
rename environmental_quality      comp_enviro
rename perception_of_corruption_0_high_ corr_percep
rename young_people_not_in_education_em youth_neet
rename deaths_from_interpersonal_violen violence_deaths
rename transportation_related_fatalitie transport_deaths
rename perceived_criminality_1_low_5_hi perceived_crime
rename premature_deaths_from_non_commun ncd_deaths
rename access_to_essential_health_servi health_services
rename child_mortality_rate_deaths_1000 child_mort
rename life_expectancy_at_60_years life_exp60
rename internet_users_of_population internet_pct
rename vulnerable_employment_of_total_e vuln_employ
rename political_rights_0_and_lower_no_ political_rights
rename access_to_justice_0_non_existent justice_access
rename freedom_of_expression_0_no_freed freedom_expr

gen trend = year - 2011
gen covid = (year >= 2020)
gen trend_covid = trend * covid

tsset year
save "data/sa_clean.dta", replace

*=======================================================================
* PAPER 2: THE INCLUSIVENESS TRAP
* Target: Development Southern Africa (Taylor & Francis)
* Word count: ~7,400 | APA 7th | No APC | Bimonthly
*=======================================================================

use "data/sa_clean.dta", clear

* Descriptive: Inclusiveness and NEET over time
list year comp_incl youth_neet internet_pct comp_rights comp_freedom comp_advEdu, sep(0) noobs

* Main regression: Inclusiveness ~ corruption + trend
newey comp_incl corr_percep trend, lag(2)
estimates store p2_incl

* Youth NEET regression
newey youth_neet corr_percep trend, lag(2)
estimates store p2_neet

* All 4 Opportunity components
foreach v of varlist comp_rights comp_freedom comp_incl comp_advEdu {
    newey `v' corr_percep trend, lag(2)
    estimates store p2_`v'
}

esttab p2_comp_rights p2_comp_freedom p2_comp_incl p2_comp_advEdu p2_neet ///
    using "output/p2_opportunity_components.rtf", replace ///
    b(%9.3f) se(%9.3f) star(* 0.1 ** 0.05 *** 0.01) r2 N ///
    mtitles("Rights" "Freedom" "Inclusiveness" "Adv.Edu" "NEET") ///
    title("Paper 2: Opportunity Components and NEET Rate Regressions, SA 2011-2021") ///
    note("HAC SEs, lag=2. *** p<0.01, ** p<0.05, * p<0.1. N=11.")

* Visualisation check
twoway (line comp_incl year, lcolor(red) lw(thick)) ///
       (line youth_neet year, lcolor(orange) lw(medthick) lp(dash)) ///
       (line internet_pct year, yaxis(2) lcolor(teal) lw(medthick) lp(dash_dot)), ///
    title("The Inclusiveness Trap: SA 2011-2021") ///
    legend(label(1 "Inclusiveness") label(2 "NEET %") label(3 "Internet %")) ///
    scheme(s2color)
graph export "output/p2_inclusiveness_trap.png", replace

*=======================================================================
* PAPER 3: AFRICAN CONVERGENCE PANEL
* Target: African Review of Economics and Finance (AREF)
* Free | Biannual | WoS indexed | DHET accredited
*=======================================================================

import delimited "data/sa_africa_spi_panel_stata_ready.csv", clear varnames(1)
rename social_progress_index spi
rename basic_human_needs bhn
rename foundations_of_wellbeing fow
rename opportunity opp
rename perception_of_corruption_0_high_ corr_percep

encode country, gen(country_id)
xtset country_id year
xtdescribe

* ── Sigma Convergence ──────────────────────────────────────────────
bysort year: egen spi_sd    = sd(spi)
bysort year: egen spi_mean  = mean(spi)
bysort year: egen bhn_sd    = sd(bhn)
bysort year: egen fow_sd    = sd(fow)
bysort year: egen opp_sd    = sd(opp)

* Test: is SD declining over time? (sigma convergence)
collapse (mean) spi_sd spi_mean bhn_sd fow_sd opp_sd, by(year)
reg spi_sd year, robust
display "Sigma test: coefficient on year = " _b[year] " (p=" %5.3f r(p) ")"
* p > 0.05 → no sigma convergence

twoway (line spi_sd year, lcolor(navy) lw(thick)) ///
       (line bhn_sd year, lcolor(blue) lw(medthick)) ///
       (line opp_sd year, lcolor(red) lw(medthick)), ///
    title("Sigma Convergence: SD of SPI Across 13 African Countries") ///
    legend(label(1 "SPI SD") label(2 "BHN SD") label(3 "OPP SD")) ///
    note("Declining SD = convergence. Flat SD = no convergence.") ///
    scheme(s2color)
graph export "output/p3_sigma_convergence.png", replace

* ── Beta Convergence ───────────────────────────────────────────────
import delimited "data/sa_africa_spi_panel_stata_ready.csv", clear varnames(1)
rename social_progress_index spi
encode country, gen(country_id)
xtset country_id year

bysort country_id (year): gen spi_2011 = spi[1]
bysort country_id: gen g_spi = (spi - L.spi)/L.spi * 100  // annual growth %
bysort country_id (year): keep if _n > 1

* Beta convergence: negative coeff on spi_2011 = convergence
reg g_spi spi_2011, robust
display "Beta convergence: β = " %8.4f _b[spi_2011]
display "Implied half-life (years): " %6.1f ln(2)/abs(_b[spi_2011])

* ── Panel FE ────────────────────────────────────────────────────────
import delimited "data/sa_africa_spi_panel_stata_ready.csv", clear varnames(1)
rename social_progress_index spi
rename opportunity opp
rename perception_of_corruption_0_high_ corr_percep
encode country, gen(country_id)
xtset country_id year
gen trend = year - 2011

xtreg spi  corr_percep trend, fe robust
estimates store p3_fe_spi

xtreg opp corr_percep trend, fe robust
estimates store p3_fe_opp

esttab p3_fe_spi p3_fe_opp ///
    using "output/p3_panel_fe.rtf", replace ///
    b(%9.3f) se star(* 0.1 ** 0.05 *** 0.01) r2 N ///
    mtitles("SPI: Panel FE" "OPP: Panel FE") ///
    title("Paper 3: Panel FE — Corruption and Social Progress, 13 African Countries") ///
    note("Country FE. Robust SEs. N=143 (13 countries × 11 years).")

*=======================================================================
* PAPER 4: FOUNDATIONS OF WELLBEING / ICT DECOMPOSITION
* Target: Acta Commercii (AOSIS)
* DHET | SCOPUS | SciELO SA | CC BY 4.0 | ~30 weeks | APC ~ZAR16k
*=======================================================================

use "data/sa_clean.dta", clear

* Decompose FOW
list year fow comp_know comp_ict comp_health comp_enviro, sep(0) noobs

* Changes
foreach v of varlist fow comp_know comp_ict comp_health comp_enviro {
    gen d_`v' = `v' - `v'[1]  // change from 2011
}
list year d_fow d_comp_know d_comp_ict d_comp_health d_comp_enviro if year==2021, noobs

* Regression: each FOW component on corruption
foreach v of varlist comp_know comp_ict comp_health comp_enviro {
    newey `v' corr_percep trend, lag(2)
    estimates store p4_`v'
    display "`v': β(corr_percep)=" %8.3f _b[corr_percep] " p=" %5.3f 2*ttail(e(df_r),abs(_b[corr_percep]/_se[corr_percep]))
}

esttab p4_comp_know p4_comp_ict p4_comp_health p4_comp_enviro ///
    using "output/p4_fow_components.rtf", replace ///
    b(%9.3f) se star(* 0.1 ** 0.05 *** 0.01) r2 N ///
    mtitles("Basic Knowledge" "ICT" "Health & Wellness" "Environmental Q.") ///
    title("Paper 4: FOW Component Regressions — Corruption Sensitivity Test") ///
    note("HAC SEs lag=2. N=11. ICT = governance-insensitive channel.")

*=======================================================================
* PAPER 5: SPI AS WELFARE MEASURE — METHODOLOGY
* Target: Journal for Studies in Economics and Econometrics (JSES)
* DHET | SCOPUS | Free | Biannual
*=======================================================================

use "data/sa_clean.dta", clear

* Demonstrate within-sample variation across components
correlate spi bhn fow opp comp_safety comp_incl comp_ict comp_health corr_percep youth_neet
matrix C = r(C)
matrix rownames C = "SPI" "BHN" "FOW" "OPP" "Safety" "Incl" "ICT" "Health" "CorrPer" "NEET"
matrix colnames C = "SPI" "BHN" "FOW" "OPP" "Safety" "Incl" "ICT" "Health" "CorrPer" "NEET"
matrix list C

* Parallel regressions: SPI DV vs GDP DV (requires WB GDP per capita data)
* Assuming wdi_gdp_pc is available:
cap confirm variable wdi_gdp_pc
if _rc {
    display "Note: GDP per capita not in dataset — download from World Bank and merge"
    display "Running SPI-only specifications for Paper 5"
}

* SPI as DV: compare governance effects on SPI vs BHN vs OPP
newey spi corr_percep trend, lag(2)
estimates store p5_spi

newey opp corr_percep trend, lag(2)
estimates store p5_opp

esttab p5_spi p5_opp ///
    using "output/p5_spi_vs_dv.rtf", replace ///
    b(%9.3f) se star(* 0.1 ** 0.05 *** 0.01) r2 N ///
    title("Paper 5: Governance Effect on SPI — Core Specification")

*=======================================================================
* PAPER 6: PERSONAL SAFETY AND STATE CAPACITY
* Target: South African Crime Quarterly (SACQ)
* DHET | DOAJ | Free | Quarterly | CC BY 4.0
*=======================================================================

use "data/sa_clean.dta", clear

* Personal Safety evolution
list year comp_safety violence_deaths perceived_crime corr_percep, sep(0) noobs

* Safety below 50 benchmark
count if comp_safety < 50
display "Years below 50: `r(N)' out of 11"

* Main regression: Personal Safety ~ governance + trend
newey comp_safety corr_percep trend, lag(2)
estimates store p6_safety_base

* Extended model with WGI Rule of Law (if available)
* newey comp_safety wgi_rl corr_percep trend, lag(2)
* estimates store p6_safety_ext

* Interrupted time series: COVID effect on safety
newey comp_safety trend covid trend_covid, lag(1)
estimates store p6_its

* Violence deaths regression
newey violence_deaths corr_percep trend, lag(2)
estimates store p6_violence

esttab p6_safety_base p6_its p6_violence ///
    using "output/p6_personal_safety.rtf", replace ///
    b(%9.3f) se star(* 0.1 ** 0.05 *** 0.01) r2 N ///
    mtitles("Safety: Base" "Safety: ITS" "Violence Deaths") ///
    title("Paper 6: Personal Safety Regressions, SA 2011-2021") ///
    note("HAC SEs lag=2 (lag=1 for ITS). N=11. *** p<0.01, ** p<0.05, * p<0.1.")

* Safety comparison against African peers
import delimited "data/sa_africa_spi_panel_stata_ready.csv", clear varnames(1)
rename personal_safety comp_safety
keep if year == 2021
gsort -comp_safety
list country comp_safety, sep(0) noobs

display "Analysis complete. All tables saved in output/ folder."
log close
