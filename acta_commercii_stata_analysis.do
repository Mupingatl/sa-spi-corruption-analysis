/*=======================================================================
  STATA DO-FILE: Political Corruption and Multidimensional Social Progress
  in Post-Apartheid South Africa, 2011–2021
  
  TARGET JOURNAL: Acta Commercii (ISSN: 1684-1999)
  Publisher: AOSIS (Pty) Ltd. | DHET Accredited | SCOPUS | SciELO SA
  DOI prefix: 10.4102/ac
  
  Authors:
    Tumba Dieudonné
    TM-School, University of South Africa (UNISA)
    
    Tafadzwa Luke Mupingashato (Corresponding Author)
    TM-School, University of South Africa (UNISA)
    mupintl@unisa.ac.za | ORCID: 0000-0001-6119-9234
  
  Data Sources:
    [PRIMARY] Social Progress Imperative (2021)
      Harmacek, J. & Htitich, M.: 2021 Social Progress Index Data.
      Social Progress Imperative, Washington, DC.
      www.socialprogress.org | CC BY 4.0
    
    [SUPPLEMENTARY] World Bank World Governance Indicators (WGI)
      https://info.worldbank.org/governance/wgi
    
    [SUPPLEMENTARY] World Bank Open Data (GDP, GFCF, Trade)
      https://data.worldbank.org
    
    [SUPPLEMENTARY] Transparency International CPI
      (Embedded in SPI dataset as perception_of_corruption variable)
  
  GitHub Repository:
    https://github.com/Mupingatl/sa-spi-corruption-analysis
  
  Data Period: South Africa, annual, 2011–2021 (N=11)
  Comparative Panel: 13 Sub-Saharan African countries × 11 years (N=143)
  
  ACTA COMMERCII SUBMISSION REQUIREMENTS (verified March 2026):
    Word limit:     7,000 words (excl. abstract, tables, refs)
    Abstract:       250 words max, 7 structured headings (Harvard style)
    References:     60 max, Harvard referencing style
    Tables/figures: 7 max (we use 4 figures + 2 tables = 6 total)
    Title:          Max 95 characters (incl. spaces)
    APC:            ZAR 1,352/page × avg 12 pages ≈ ZAR 16,224
    Turnaround:     ~30 weeks (DOAJ reported)
    Review:         Double-blind, iThenticate plagiarism check
    Submission:     https://actacommercii.co.za/index.php/acta/author
=======================================================================*/

*-----------------------------------------------------------------------
* 0. SETUP
*-----------------------------------------------------------------------
clear all
set more off
set linesize 140
cap log close
log using "output/acta_commercii_analysis_log.txt", replace text

* Required packages (install once)
* ssc install estout,   replace
* ssc install newey2,   replace
* ssc install actest,   replace   // Cumby-Huizinga autocorrelation test
* ssc install xtabond2, replace   // Arellano-Bond GMM (supplementary)

* Set working directory
* cd "/path/to/sa-spi-corruption-analysis"

*-----------------------------------------------------------------------
* 1. LOAD SA NATIONAL DATA (2011–2021)
*-----------------------------------------------------------------------
import delimited "data/sa_spi_national_stata_ready.csv", clear varnames(1)

* Rename key variables
rename social_progress_index          spi
rename basic_human_needs              bhn
rename foundations_of_wellbeing       fow
rename opportunity                    opp
rename nutrition_and_basic_medical_care comp_nutrition
rename water_and_sanitation           comp_wash
rename shelter                        comp_shelter
rename personal_safety                comp_safety
rename access_to_basic_knowledge      comp_know
rename access_to_information_and_commun comp_ict
rename health_and_wellness            comp_health
rename environmental_quality          comp_enviro
rename personal_rights                comp_rights
rename personal_freedom_and_choice    comp_freedom
rename inclusiveness                  comp_incl
rename access_to_advanced_education   comp_advEdu
rename perception_of_corruption_0_high_ corr_percep
rename child_mortality_rate_deaths_1000 child_mort
rename life_expectancy_at_60_years    life_exp60
rename young_people_not_in_education_em youth_neet
rename vulnerable_employment_of_total_e vuln_empl
rename internet_users_of_population   internet
rename equality_of_political_power_by_g gender_polpow

* Labels
label var spi         "Social Progress Index (0–100)"
label var bhn         "Basic Human Needs Dimension (0–100)"
label var fow         "Foundations of Wellbeing Dimension (0–100)"
label var opp         "Opportunity Dimension (0–100)"
label var corr_percep "Corruption Perception (0=highest corrupt; 100=lowest)"
label var child_mort  "Child mortality rate (per 1,000 live births)"
label var youth_neet  "Youth NEET rate (%)"

tsset year

* Forward-fill internet for 2020–2021 (data freeze at 2019 value in SPI)
* Note: The SPI dataset uses 56.17 for 2019, 2020, 2021 — flag this
gen internet_flag = (year >= 2020)
label var internet_flag "=1 if internet data is carry-forward from 2019"

save "data/sa_clean.dta", replace
display "SA data loaded and saved: N=`=_N' observations"

*-----------------------------------------------------------------------
* 2. SUPPLEMENTARY DATA — JOIN WGI AND WORLD BANK VARIABLES
*    Download from:
*    WGI:        https://info.worldbank.org/governance/wgi  (1996–2021)
*    World Bank: https://data.worldbank.org  (GDP, GFCF, trade)
*
*    Expected variable names after download and reshape:
*    wgi_cc:     Control of Corruption (percentile, 0–100)
*    wgi_ge:     Government Effectiveness (percentile, 0–100)
*    wgi_rl:     Rule of Law (percentile, 0–100)
*    wgi_ps:     Political Stability (percentile, 0–100)
*    gdp_pc:     Real GDP per capita, constant 2015 USD
*    gdp_grw:    GDP growth rate (% annual)
*    gfcf_gdp:   Gross fixed capital formation (% of GDP)
*    trade_open: Trade openness (exports+imports / GDP %)
*    fsd:        IMF Financial Development Index (0–1)
*-----------------------------------------------------------------------

* Check if WGI data exists
cap confirm file "data/wgi_sa_2011_2021.dta"
if _rc {
    display "WGI data not found. Run data download script: scripts/download_wgi.do"
    display "Proceeding with SPI-only analysis (full results require WGI join)"
}
else {
    use "data/sa_clean.dta", clear
    merge 1:1 year using "data/wgi_sa_2011_2021.dta", nogenerate
    merge 1:1 year using "data/wb_sa_macros_2011_2021.dta", nogenerate
    gen ln_gdp_pc = ln(gdp_pc)
    label var ln_gdp_pc "Log real GDP per capita (constant 2015 USD)"
    save "data/sa_merged.dta", replace
    display "Merged dataset saved"
}

* Use SA clean data for SPI-only analysis
use "data/sa_clean.dta", clear

*-----------------------------------------------------------------------
* 3. SECTION 3: DESCRIPTIVE STATISTICS
*    Table 1 in paper: Summary statistics of key variables
*-----------------------------------------------------------------------

* Table 1: SPI scores and corruption perception across 2011–2021
tabstat spi bhn fow opp corr_percep comp_safety comp_incl ///
        child_mort life_exp60 youth_neet internet, ///
        stat(mean sd min max) format(%7.2f) col(stat)

* Year-by-year scores (insert as Table 1 panel in paper)
list year spi bhn fow opp corr_percep comp_safety comp_incl, sep(0) noobs

* Change calculations
gen d_spi  = spi  - L10.spi  if year==2021
gen d_bhn  = bhn  - L10.bhn  if year==2021
gen d_fow  = fow  - L10.fow  if year==2021
gen d_opp  = opp  - L10.opp  if year==2021
list year d_spi d_bhn d_fow d_opp if year==2021, noobs

* Pairwise correlations
correlate spi bhn fow opp corr_percep comp_safety comp_incl
correlate opp comp_incl comp_rights comp_freedom comp_advEdu corr_percep

*-----------------------------------------------------------------------
* 4. SECTION 4: REGRESSION ANALYSIS
*    Using only SPI-embedded corruption variable (base model)
*    Full model adds WGI from supplementary data join
*-----------------------------------------------------------------------

* ── Model 1: SPI Overall ~ Corruption Perception ───────────────────
* Newey-West HAC SEs: appropriate for small-N time series
newey spi corr_percep, lag(2)
estimates store m1_spi

* ── Model 2: Each Dimension ~ Corruption Perception ────────────────
foreach v of varlist bhn fow opp {
    newey `v' corr_percep, lag(2)
    estimates store m1_`v'
}

* ── Model 3: Opportunity ~ Components (mediation structure) ─────────
newey opp comp_incl comp_rights comp_freedom comp_advEdu, lag(1)
estimates store m3_opp_comp

* ── Model 4: Full model with trend control ──────────────────────────
gen trend = year - 2011
label var trend "Time trend (0=2011, 10=2021)"

foreach v of varlist spi bhn fow opp {
    newey `v' corr_percep trend, lag(2)
    estimates store m2_`v'
}

* ── Model 5: WGI extended model (requires supplementary data) ───────
cap confirm file "data/sa_merged.dta"
if _rc == 0 {
    use "data/sa_merged.dta", clear
    tsset year
    foreach v of varlist spi bhn fow opp {
        newey `v' wgi_cc wgi_ge wgi_rl ln_gdp_pc gdp_grw gfcf_gdp trade_open, lag(2)
        estimates store wgi_`v'
    }
    use "data/sa_clean.dta", clear
    tsset year
}

* ── Results Table 2: Dimension-level OLS with Newey-West SEs ────────
esttab m1_spi m1_bhn m1_fow m1_opp ///
    using "output/table2_base_models.rtf", replace ///
    b(%9.3f) se(%9.3f) star(* 0.1 ** 0.05 *** 0.01) ///
    r2 aic bic N ///
    mtitles("SPI Overall" "BHN" "FOW" "Opportunity") ///
    title("Table 2. OLS Regression: Corruption Perception and SPI Dimensions, SA 2011–2021") ///
    note("HAC standard errors (Newey-West, lag=2) in parentheses. *** p<0.01, ** p<0.05, * p<0.1. N=11 annual obs. Dependent variables are SPI dimension scores (0–100).")

* ── Results Table with trend: ────────────────────────────────────────
esttab m2_spi m2_bhn m2_fow m2_opp ///
    using "output/table2b_trend_models.rtf", replace ///
    b(%9.3f) se(%9.3f) star(* 0.1 ** 0.05 *** 0.01) ///
    r2 aic bic N ///
    mtitles("SPI Overall" "BHN" "FOW" "Opportunity") ///
    title("Table 2b. OLS with Time Trend: Corruption and SPI Dimensions")

*-----------------------------------------------------------------------
* 5. SECTION 4: COMPONENT-LEVEL ANALYSIS
*    Identifies which welfare channels corruption affects most
*-----------------------------------------------------------------------
gen trend2 = trend^2
label var trend2 "Quadratic time trend"

* Regress each component on corruption + linear trend
foreach v of varlist comp_nutrition comp_wash comp_shelter comp_safety ///
                     comp_know comp_ict comp_health comp_enviro ///
                     comp_rights comp_freedom comp_incl comp_advEdu {
    quietly newey `v' corr_percep trend, lag(2)
    scalar b_corr_`v'  = _b[corr_percep]
    scalar se_corr_`v' = _se[corr_percep]
    scalar p_corr_`v'  = 2*ttail(e(df_r), abs(_b[corr_percep]/_se[corr_percep]))
    display "`v': β(corruption) = `=b_corr_`v'' (p=`=p_corr_`v'')"
}

*-----------------------------------------------------------------------
* 6. SECTION 5: TIME SERIES PROPERTIES
*    ADF unit root tests (small-N aware)
*-----------------------------------------------------------------------
foreach v of varlist spi bhn fow opp corr_percep {
    dfuller `v', lags(1) trend noprint
    display "ADF: `v' — stat=" %6.3f r(Zt) " p≈" %5.3f r(p)
}

* CUSUM stability test (using residuals from main OLS)
reg spi corr_percep trend, robust
predict resid_spi, resid
predict yhat_spi

* Manual CUSUM plot
gen cusum = sum(resid_spi) / sqrt(e(rss)/(e(df_r)))
twoway line cusum year, ///
    title("CUSUM Plot: SPI Overall Model") ///
    ytitle("Cumulative sum of recursive residuals") ///
    yline(0) scheme(s2color)
graph export "output/cusum_spi.png", replace

*-----------------------------------------------------------------------
* 7. SECTION 5: INTERRUPTED TIME SERIES — COVID-19 SHOCK
*-----------------------------------------------------------------------
gen covid = (year >= 2020)
gen trend_covid = trend * covid
label var covid        "COVID-19 period (=1 for 2020–2021)"
label var trend_covid  "Trend × COVID interaction"

foreach v of varlist spi bhn fow opp {
    newey `v' trend covid trend_covid, lag(1)
    estimates store its_`v'
    display _b[covid] " = COVID level shock for `v'"
    display _b[trend_covid] " = COVID slope change for `v'"
}

esttab its_spi its_bhn its_fow its_opp ///
    using "output/table3_covid_its.rtf", replace ///
    b(%9.3f) se(%9.3f) star(* 0.1 ** 0.05 *** 0.01) ///
    mtitles("SPI" "BHN" "FOW" "Opportunity") ///
    title("Table 3. Interrupted Time Series: COVID-19 Shock on Social Progress Dimensions") ///
    note("N=11. COVID=1 for 2020-2021. Trend_COVID = slope change. HAC SEs, lag=1.")

*-----------------------------------------------------------------------
* 8. SECTION 5: ROBUSTNESS CHECKS
*-----------------------------------------------------------------------

* R1: Exclude 2020–2021 (pre-COVID subsample)
foreach v of varlist spi bhn fow opp {
    newey `v' corr_percep trend if year <= 2019, lag(1)
    estimates store r1_`v'
}

* R2: Lagged corruption (one-year lag)
gen L_corr = L.corr_percep
label var L_corr "L1 Corruption Perception"
foreach v of varlist spi opp {
    newey `v' L_corr trend, lag(1)
    estimates store r2_`v'
}

* R3: Alternative corruption metric — Personal Safety as institutional proxy
foreach v of varlist bhn opp {
    newey `v' comp_safety corr_percep trend, lag(1)
    estimates store r3_`v'
}

esttab r1_spi r1_opp r2_spi r2_opp r3_bhn r3_opp ///
    using "output/table_robustness.rtf", replace ///
    b(%9.3f) se(%9.3f) star(* 0.1 ** 0.05 *** 0.01) ///
    mtitles("Pre-COVID SPI" "Pre-COVID OPP" "L1:SPI" "L1:OPP" "+Safety:BHN" "+Safety:OPP") ///
    title("Robustness Checks: Alternative Specifications")

*-----------------------------------------------------------------------
* 9. PANEL ANALYSIS: AFRICAN COMPARATORS
*-----------------------------------------------------------------------
import delimited "data/sa_africa_spi_panel_stata_ready.csv", clear varnames(1)
rename social_progress_index spi
rename basic_human_needs bhn
rename foundations_of_wellbeing fow
rename opportunity opp
rename perception_of_corruption_0_high_ corr_percep
encode country, gen(country_id)
xtset country_id year
xtdescribe

* Sigma convergence
bysort year: egen spi_sd = sd(spi)
bysort year: egen spi_mean = mean(spi)
gen cv = spi_sd / spi_mean
tabstat spi_sd spi_mean cv, by(year) stat(mean) format(%6.3f)

* Beta convergence
bysort country_id (year): gen spi_2011 = spi[1]
bysort country_id: gen g_spi = (spi - L.spi)/L.spi
reg g_spi spi_2011, robust
display "Beta convergence coefficient: " _b[spi_2011]
* Negative = conditional convergence; positive = divergence

* Panel FE
xtreg spi corr_percep, fe robust
estimates store fe_spi

xtreg opp corr_percep, fe robust
estimates store fe_opp

esttab fe_spi fe_opp, b(%9.3f) se star(* 0.1 ** 0.05 *** 0.01) ///
    title("African Panel FE: Corruption and SPI") ///
    note("N=143 (13 countries × 11 years). Province FE. Robust SEs.")

*-----------------------------------------------------------------------
* 10. FIGURES (Stata versions — supplement Python visualizations)
*-----------------------------------------------------------------------
use "data/sa_clean.dta", clear
tsset year

* Fig 1 equivalent: SPI dimension trends
twoway (line spi year, lcolor(gold) lw(thick) lp(dash)) ///
       (line bhn year, lcolor(navy) lw(medthick)) ///
       (line fow year, lcolor(green) lw(medthick)) ///
       (line opp year, lcolor(red) lw(medthick)), ///
    legend(order(1 "SPI Overall" 2 "Basic Human Needs" 3 "Foundations" 4 "Opportunity") ///
           rows(2) size(small)) ///
    title("Social Progress Dimensions, SA 2011–2021") ///
    xtitle("Year") ytitle("Score (0–100)") ///
    note("Source: Social Progress Imperative (2021).") scheme(s2color)
graph export "output/fig1_stata_dimensions.png", replace

* Fig 3 equivalent: Corruption vs Opportunity scatter
scatter opp corr_percep, ///
    mlabel(year) ///
    title("Corruption Perception vs Opportunity Dimension") ///
    xtitle("Corruption Perception (0=high corr; 100=low)") ///
    ytitle("Opportunity Score (0–100)") ///
    note("r = 0.60, N=11. Source: SPI 2021.") scheme(s2color)
graph export "output/fig3_stata_scatter.png", replace

*-----------------------------------------------------------------------
* 11. WORD COUNT CALCULATION
*-----------------------------------------------------------------------
* The final paper word count (main text only, excl abstract/tables/refs)
* should not exceed 7,000 words per Acta Commercii guidelines.
* To verify: paste manuscript into Word and use word count tool.
* Target section word budget:
*   Introduction:         ~800 words
*   Literature Review:    ~1,200 words
*   Methodology:          ~900 words
*   Results & Discussion: ~2,500 words
*   Conclusion:           ~600 words
*   TOTAL:                ~6,000 words (leaves 1,000 word buffer)

display "Analysis complete. Review output/ folder for all tables and figures."
log close
