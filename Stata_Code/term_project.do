*-------------------------------------------- FIRST PART: Settings --------------------------------------------* 

* Ignore this step, it is just my Stata that does not let me install packages if I do not do that for some reason:
sysdir set PLUS "C:/Users/João Reis/Desktop" 

* Install package outreg2:
ssc install outreg2

* Creating a global to the directory:
global datadir "C:/Users/João Reis/Desktop/Term_Project"

* Creating a new directory to save the raw .csv data as .dta data:
capture mkdir "$datadir/Datasets_Stata"
global datasets "$datadir/Datasets_Stata"

* Creating a new directory to save the outputs from the analysis:
capture mkdir "$datadir/Output"
global output "$datadir/Output"

*-------------------------------------------- SECOND PART: Convert data from .csv to .dta --------------------------------------------* 

* Importing the files as .csv and saving them as .dta
import delimited "${datadir}/Datasets/worldbankdata", clear varnames(1) bindquotes(strict) encoding("utf-8")
save "${datasets}/worldbankdata.dta", replace

*-------------------------------------------- THIRD PART: Importing and cleaning each dataset --------------------------------------------* 

use "${datasets}/worldbankdata.dta", clear

* Dropping extra information not needed:
drop timecode
drop if missing(countrycode)

* Renaming variables to easier coding:
rename time year
rename maternalmortalityratiomodeledest maternalmortality
rename proportionofseatsheldbywomeninna womenseats
rename gdppercapitapppconstant2017inter gdppercapita
rename birthratecrudeper1000peoplespdyn birthrate
rename unemploymentfemaleoffemalelaborf unemploymentfemale
rename populationfemalesppoptotlfein populationfemale


* Destring the variables:
generate maternal_mortality = real(maternalmortality)
generate maternal_mortality_percentage = maternal_mortality / 10
drop maternalmortality
drop maternal_mortality
generate women_seats = real(womenseats)
drop womenseats
generate female_unemployment = real(unemploymentfemale)
drop unemploymentfemale
generate birth_rate = real(birthrate)
generate birth_rate_percentage = birth_rate / 10
drop birthrate
drop birth_rate
generate gdp_per_capita = real(gdppercapita)
drop gdppercapita
generate female_population = real(populationfemale)
drop populationfemale
format female_population %12.0f

sort countrycode countryname year

* Labeling Variables:
label variable year "Year of observation"
label var maternal_mortality_percentage "Maternal Mortality ratio (%)"
label variable female_unemployment "Unemployment, female (% of female labor force) (modeled ILO estimate)"
label variable women_seats "Proportion of seats held by women in national parliaments (%)"
label variable birth_rate_percentage "Birth rate, crude (%)"
label variable gdp_per_capita "GDP per capita, PPP (constant 2017 international $)"
label variable female_population "Total Female Population"

* Balancing the panel on the key variables:
egen n_maternal_mortality_percentage = count(maternal_mortality_percentage), by(countrycode)
egen n_women_seats = count(women_seats), by(countrycode)


tab countryname if n_women_seats < 18, sum(n_women_seats)
tab countryname if n_maternal_mortality_percentage < 18, sum(n_maternal_mortality_percentage)

* All countries with less than 24 observations for maternal mortality has 0 observations, so let's drop them. Let's also drop countries that have less than 16 observations for women seats:
drop if n_maternal_mortality_percentage < 16
drop if n_women_seats < 16

* The observations missing in the countries that are left seem reasonable random (and it is normal such missing observations since we are talking about women seats, and due to some political friccion some years might not have observations). We are going to compute the average of the year before and after as proxy to the missing value: 
replace women_seats = (women_seats[_n-1]+women_seats[_n+1])/2 if missing(women_seats)

* See the countries that still missing observations
drop n_women_seats
egen n_women_seats = count(women_seats), by(countrycode)
tab countryname if n_women_seats < 18, sum(n_women_seats)

* All the countries with missing observations have 2 years in a row with missing data. We opted by dropping them since there are only 3 observations:
drop if n_women_seats < 18
drop n_women_seats
drop n_maternal_mortality_percentage

* Balancing the panel on the confounders:
egen n_birth_rate = count(birth_rate_percentage), by(countrycode)
egen n_female_unemployment = count(female_unemployment), by(countrycode)
egen n_gdp_per_capita = count(gdp_per_capita), by(countrycode)
egen n_female_population = count(female_population), by(countrycode)

tab countryname if n_birth_rate < 18, sum(n_birth_rate)
tab countryname if n_female_unemployment < 18, sum(n_female_unemployment)
tab countryname if n_gdp_per_capita < 18, sum(n_gdp_per_capita)
tab countryname if n_female_population < 18, sum(n_female_population)

* Only São Tomé e Principe has 1 missing value, 2000 (all the other countries has a lot of missing observations). So we will cover that value in São Tomé by the value of 2001 and drop the other observations:
drop if n_female_unemployment < 18
drop if n_female_population < 18
drop if n_gdp_per_capita < 17
replace gdp_per_capita = gdp_per_capita[_N+1] if missing(gdp_per_capita)

drop n_birth_rate
drop n_female_unemployment
drop n_gdp_per_capita
drop n_female_population

save "${datasets}/final_dataset", replace

*-------------------------------------------- FIFTH PART: Analyzing and preparing the data for regressions --------------------------------------------* 

use "${datasets}/final_dataset", replace

* Transforming the countrycode into a numeric variable so I can set a panel data in Stata. I am not going to drop countrycode since it is not possible to do conditions based on countryid - it is numeric - and sometimes to know the countrycode is easier than to know the country name:
encode countrycode, gen(countryid)
order countryid, after(countrycode)

* Transforming the dataset into a panel data:
xtset countryid year
xtdes

twoway (tsline women_seats , yaxis(1)) || (tsline maternal_mortality_percentage , yaxis(2)) || if countryname == "United States", xsize(100) ysize(45) title("United States of America")
graph export "$output\twoway_us.png",replace

twoway (tsline women_seats , yaxis(1)) || (tsline maternal_mortality_percentage , yaxis(2)) || if countryname == "Austria", xsize(100) ysize(45) title("Austria")
graph export "$output\twoway_austria.png",replace

twoway (tsline women_seats , yaxis(1)) || (tsline maternal_mortality_percentage , yaxis(2)) || if countryname == "Portugal", xsize(100) ysize(45) title("Portugal")
graph export "$output\twoway_portugal.png",replace

twoway (tsline women_seats , yaxis(1)) || (tsline maternal_mortality_percentage , yaxis(2)) || if countryname == "Mozambique", xsize(100) ysize(45) title("Mozambique")
graph export "$output\twoway_mozambique.png",replace

twoway (tsline women_seats , yaxis(1)) || (tsline maternal_mortality_percentage , yaxis(2)) || if countryname == "Angola", xsize(100) ysize(45) title("Angola")
graph export "$output\twoway_angola.png",replace

twoway (tsline women_seats , yaxis(1)) || (tsline maternal_mortality_percentage , yaxis(2)) || if countryname == "Brazil", xsize(100) ysize(45) title("Brazil")
graph export "$output\twoway_brazil.png",replace

twoway (tsline women_seats , yaxis(1)) || (tsline maternal_mortality_percentage , yaxis(2)) || if countryname == "China", xsize(100) ysize(45) title("China")
graph export "$output\twoway_china.png",replace

twoway (tsline women_seats , yaxis(1)) || (tsline maternal_mortality_percentage , yaxis(2)) || if countryname == "India", xsize(100) ysize(45) title("India")
graph export "$output\twoway_india.png",replace

* Generating the Natural Logarithms of the variables:
gen ln_maternal_mortality_percentage = ln(maternal_mortality_percentage)
gen ln_women_seats = ln(women_seats)
gen ln_birth_rate_percentage = ln(birth_rate)
gen ln_female_unemployment = ln(female_unemployment)
gen ln_gdp_per_capita = ln(gdp_per_capita)
gen ln_female_population = ln(female_population)

label var ln_maternal_mortality_percentage "Natural logarithm of Maternal Mortality ratio (%)"
label var ln_women_seats "Natural logarithm of Proportion of sets heald by women in national parliaments (%)"
label var ln_birth_rate_percentage "Natural logarithm of Birth rate, crude (%)"
label var ln_female_unemployment "Natural logarithm of Unemployment, female (% of female labor force) (modeled ILO estimate)"
label var ln_gdp_per_capita "Natural logarithm of GDP per capita, PPP (constant 2017 international $)"
label var ln_female_population "Natural logarithm of Female population"

* Creating first diferences of the variables:
gen d_maternal_mortality_percentage = d.maternal_mortality_percentage
gen d_ln_maternalmortalitypercentage = d.ln_maternal_mortality_percentage
gen d_women_seats = d.women_seats
gen d_ln_women_seats = d.ln_women_seats
gen d_birth_rate_percentage = d.birth_rate
gen d_ln_birth_rate_percentage = d.ln_birth_rate
gen d_female_unemployment = d.female_unemployment
gen d_ln_female_unemployment = d.ln_female_unemployment
gen d_gdp_per_capita = d.gdp_per_capita
gen d_ln_gdp_per_capita = d.ln_gdp_per_capita
gen d_female_population = d.female_population
gen d_ln_female_population = d.ln_female_population

label var d_maternal_mortality_percentage "First Differences of Maternal Mortality ratio (%)"
label var d_ln_maternalmortalitypercentage "First Differences of Natural logarithm of Maternal Mortality ratio (%)"
label var d_women_seats "First Differences of Proportion of sets heald by women in national parliaments (%)"
label var d_ln_women_seats "First Differences of Natural logarithm of Proportion of sets heald by women in national parliaments (%)"
label var d_birth_rate_percentage "First Differences of Birth rate, crude (%)"
label var d_ln_birth_rate_percentage "First Differences of Natural logarithm of Birth rate, crude (%)"
label var d_female_unemployment "First Differences of Unemployment, female (% of female labor force) (modeled ILO estimate)"
label var d_ln_female_unemployment "First Differences of Natural logarithm of Unemployment, femmale (% of female labor force) (modeled ILO estimate)"
label var d_gdp_per_capita "First Differences GDP per capita, PPP (constant 2017 international $)"
label var d_ln_gdp_per_capita "First Differences Natural logarithm of GDP per capita, PPP (constant 2017 international $)"
label var d_female_population "First Differences of Total Population"
label var d_ln_female_population "First Differences of Natural logarithm of Female population"

* Some summaries of the variables: not all are important, but I am letting it in the code in case one wants to check something in particular:
sum maternal_mortality_percentage, detail 
sum women_seats, detail
sum birth_rate_percentage, detail 
sum female_unemployment, detail
sum gdp_per_capita, detail
sum female_population, detail

sum ln_maternal_mortality_percentage, detail
sum ln_women_seats, detail
sum ln_birth_rate_percentage, detail
sum ln_female_unemployment, detail
sum ln_gdp_per_capita, detail
sum ln_female_population, detail

sum d_maternal_mortality_percentage, detail
sum d_women_seats, detail
sum d_birth_rate_percentage, detail
sum d_female_unemployment, detail
sum d_gdp_per_capita, detail
sum d_female_population, detail

sum d_ln_maternalmortalitypercentage, detail
sum d_ln_women_seats, detail
sum d_ln_birth_rate_percentage, detail
sum d_ln_female_unemployment, detail
sum d_ln_gdp_per_capita, detail
sum d_ln_female_population, detail

*-------------------------------------------- SIXTH PART: Regressions --------------------------------------------* 

*------------------ OLS Regressions ------------------*

* 1)
reg maternal_mortality_percentage women_seats if year == 2000
outreg2 using "$output\ols_maternalmortality_womenseats", bdec(3) 2aster tex(fragment) stat(coef se pval) replace ctitle("Year = 2000, Maternal Mortality ratio (%)")

reg maternal_mortality_percentage ln_women_seats if year == 2000
outreg2 using "$output\ols_maternalmortality_lnwomenseats", bdec(3) 2aster tex(fragment) stat(coef se pval) replace ctitle("Year = 2000, Maternal Mortality ratio (%)")

reg ln_maternal_mortality_percentage women_seats if year == 2000
outreg2 using "$output\ols_lnmaternalmortality_womenseats", bdec(3) 2aster tex(fragment) stat(coef se pval) replace ctitle("Year = 2000, Natural Logarithm of Maternal Mortality ratio (%)")

reg ln_maternal_mortality_percentage ln_women_seats if year == 2000
outreg2 using "$output\ols_lnmaternalmortality_lnwomenseats", bdec(3) 2aster tex(fragment) stat(coef se pval) replace ctitle("Year = 2000, Natural Logarithm of Maternal Mortality ratio (%)")


*2)
reg maternal_mortality_percentage women_seats if year == 2017
outreg2 using "$output\ols_maternalmortality_womenseats", bdec(3) 2aster tex(fragment) stat(coef se pval) append ctitle("Year = 2017, Maternal Mortality ratio (%)")

reg maternal_mortality_percentage ln_women_seats if year == 2017
outreg2 using "$output\ols_maternalmortality_lnwomenseats", bdec(3) 2aster tex(fragment) stat(coef se pval) append ctitle("Year = 2017, Maternal Mortality ratio (%)")

reg ln_maternal_mortality_percentage women_seats if year == 2017
outreg2 using "$output\ols_lnmaternalmortality_womenseats", bdec(3) 2aster tex(fragment) stat(coef se pval) append ctitle("Year = 2017, Natural Logarithm of Maternal Mortality ratio (%)")

reg ln_maternal_mortality_percentage ln_women_seats if year == 2017
outreg2 using "$output\ols_lnmaternalmortality_lnwomenseats", bdec(3) 2aster tex(fragment) stat(coef se pval) append ctitle("Year = 2017, Natural Logarithm of Maternal Mortality ratio (%)")

*------------------ FD REGRESSIONS ------------------ *

* Basic FD:
reg d_maternal_mortality_percentage d_women_seats [w=female_population], cluster(countryid)
outreg2 using "$output\fd_maternalmortality_womenseats_weighted", bdec(3) 2aster tex(fragment) keep(d_women_seats) stat(coef se pval) replace ctitle("FD With No Lags, FD Maternal Mortality ratio (%)")

* FD with 2 lags:
reg d_maternal_mortality_percentage L(0/2).d_women_seats [w=female_population], cluster(countryid)
outreg2 using "$output\fd_maternalmortality_womenseats_weighted", bdec(3) 2aster tex(fragment) keep(L(0/2).d_women_seats) stat(coef se pval) append ctitle("FD With 2 Lags, FD Maternal Mortality ratio (%)")

* FD with 4 lags:
reg d_maternal_mortality_percentage L(0/4).d_women_seats [w=female_population], cluster(countryid)
outreg2 using "$output\fd_maternalmortality_womenseats_weighted", bdec(3) 2aster tex(fragment) keep(L(0/4).d_women_seats) stat(coef se pval) append ctitle("FD With 4 Lags, FD Maternal Mortality ratio (%)")

* Testing if the cumulative coefficient is significant:
test d_women_seats + L.d_women_seats + L2.d_women_seats + L3.d_women_seats + L4.d_women_seats = 0

*------------------ FE Regressions ------------------*
egen average_female_population = mean(female_population), by(countryid) /* For Weights */
format average_female_population %12.0f

xtreg maternal_mortality_percentage women_seats i.year [w=average_female_population], fe cluster(countryid)
outreg2 using "$output\fe_maternalmortality_womenseats_weighted", bdec(3) 2aster tex(fragment) keep(women_seats i.year) stat(coef se pval) replace ctitle("Fixed Effects, Maternal Mortality ratio (%)") 

*------------------ Long Difference Model------------------*
bysort countryid : gen ld_maternal_mortality_percentage = maternal_mortality_percentage[_N] - maternal_mortality_percentage[1] /*Generating the difference between the last and the first observation*/
bysort countryid : gen ld_women_seats = women_seats[_N] - women_seats[1] 

reg ld_maternal_mortality_percentage ld_women_seats [w=average_female_population], cluster(countryid)
outreg2 using "$output\ld_maternalmortality_womenseats_weighted", bdec(3) 2aster tex(fragment) stat(coef se pval) replace ctitle("Long Difference Model, LD Maternal Mortality ratio (%)") 

*------------------ Extra: Confounders ------------------ *

* In OLS Regressions *

reg maternal_mortality_percentage women_seats birth_rate_percentage female_unemployment ln_gdp_per_capita ln_female_population if year == 2000
outreg2 using "$output\ols_maternalmortality_womenseats", bdec(3) 2aster tex(fragment) stat(coef se pval) append ctitle("Year = 2000, Maternal Mortality ratio (%)") 

reg maternal_mortality_percentage women_seats birth_rate_percentage female_unemployment ln_gdp_per_capita ln_female_population if year == 2017
outreg2 using "$output\ols_maternalmortality_womenseats", bdec(3) 2aster tex(fragment) stat(coef se pval) append ctitle("Year = 2017, Maternal Mortality ratio (%)") 

* In FD Regressions *

* Basic FD
reg d_maternal_mortality_percentage d_women_seats d_birth_rate_percentage d_female_unemployment d_ln_gdp_per_capita d_ln_female_population [w=female_population], cluster(countryid)
outreg2 using "$output\fd_maternalmortality_womenseats_weighted", bdec(3) 2aster tex(fragment) keep(d_women_seats d_birth_rate_percentage d_female_unemployment d_ln_gdp_per_capita d_ln_female_population) stat(coef se pval) append ctitle("FD With No Lags, FD Maternal Mortality ratio (%)") 

* FD with 4 Lags
reg d_maternal_mortality_percentage L(0/4).d_women_seats d_birth_rate_percentage d_female_unemployment d_ln_gdp_per_capita d_ln_female_population [w=female_population], cluster(countryid)
outreg2 using "$output\fd_maternalmortality_womenseats_weighted", bdec(3) 2aster tex(fragment) keep(L(0/4).d_women_seats d_birth_rate_percentage d_female_unemployment d_ln_gdp_per_capita d_ln_female_population) stat(coef se pval) append ctitle("FD With No Lags, FD Maternal Mortality ratio (%)") 

reg d_maternal_mortality_percentage L(0/4).d_women_seats L(0/4).d_birth_rate_percentage L(0/4).d_female_unemployment L(0/4).d_ln_gdp_per_capita L(0/4).d_ln_female_population [w=female_population], cluster(countryid)
outreg2 using "$output\fd_maternalmortality_womenseats_lags_weighted", bdec(3) 2aster tex(fragment) keep(L(0/4).d_women_seats L(0/4).d_birth_rate_percentage L(0/4).d_female_unemployment L(0/4).d_ln_gdp_per_capita L(0/4).d_ln_female_population) stat(coef se pval) replace ctitle("FD With No Lags, FD Maternal Mortality ratio (%)") 

* In FE Regressions *
xtreg maternal_mortality_percentage women_seats birth_rate_percentage female_unemployment ln_gdp_per_capita ln_female_population i.year [w=average_female_population], fe cluster(countryid)
outreg2 using "$output\fe_maternalmortality_womenseats_weighted", bdec(3) 2aster tex(fragment) keep(women_seats birth_rate_percentage female_unemployment ln_gdp_per_capita ln_female_population i.year) stat(coef se pval) append ctitle("Fixed Effects, Maternal Mortality ratio (%)") 

* Long Difference Model
bysort countryid : gen ld_birth_rate_percentage = birth_rate[_N] - birth_rate[1]
bysort countryid : gen ld_female_unemployment = female_unemployment[_N] - female_unemployment[1]
bysort countryid : gen ld_ln_gdp_per_capita = ln_gdp_per_capita[_N] - ln_gdp_per_capita[1]
bysort countryid : gen ld_ln_female_population = ln_female_population[_N] - ln_female_population[1]

reg ld_maternal_mortality_percentage ld_women_seats ld_birth_rate_percentage ld_female_unemployment ld_ln_gdp_per_capita ld_ln_female_population [w=average_female_population], cluster(countryid)
outreg2 using "$output\ld_maternalmortality_womenseats_weighted", bdec(3) 2aster tex(fragment) stat(coef se pval) append ctitle("Long Difference Model, LD Maternal Mortality ratio (%)")

*------------------ Robustness: Unweighted Regressions ------------------ *

* Basic FD
reg d_maternal_mortality_percentage d_women_seats, cluster(countryid)
outreg2 using "$output\fd_maternalmortality_womenseats_unweighted", bdec(3) 2aster tex(fragment) keep(d_women_seats) stat(coef se pval) replace ctitle("FD With No Lags, FD Maternal Mortality ratio (%)")

reg d_maternal_mortality_percentage d_women_seats d_birth_rate_percentage d_female_unemployment d_ln_gdp_per_capita d_ln_female_population, cluster(countryid)
outreg2 using "$output\fd_maternalmortality_womenseats_unweighted", bdec(3) 2aster tex(fragment) keep(d_women_seats d_birth_rate_percentage d_female_unemployment d_ln_gdp_per_capita d_ln_female_population) stat(coef se pval) append ctitle("FD With No Lags, FD Maternal Mortality ratio (%)") 

* FD with 2 lags
reg d_maternal_mortality_percentage L(0/2).d_women_seats, cluster(countryid)
outreg2 using "$output\fd_maternalmortality_womenseats__unweighted", bdec(3) 2aster tex(fragment) keep(L(0/2).d_women_seats) stat(coef se pval) append ctitle("FD With 2 Lags, FD Maternal Mortality ratio (%)")

* FD with 4 lags:
reg d_maternal_mortality_percentage L(0/4).d_women_seats, cluster(countryid)
outreg2 using "$output\fd_maternalmortality_womenseats_unweighted", bdec(3) 2aster tex(fragment) keep(L(0/4).d_women_seats) stat(coef se pval) append ctitle("FD With 6 Lags, FD Maternal Mortality ratio (%)")

* Testing if the cumulative coefficient is significant
test d_women_seats + L.d_women_seats + L2.d_women_seats + L3.d_women_seats + L4.d_women_seats = 0

* FE Regressions *
xtreg maternal_mortality_percentage women_seats i.year, fe cluster(countryid)
outreg2 using "$output\fe_maternalmortality_womenseats_unweighted", bdec(3) 2aster tex(fragment) keep(women_seats i.year) stat(coef se pval) replace ctitle("Fixed Effects, Maternal Mortality ratio (%)") 

xtreg maternal_mortality_percentage women_seats birth_rate_percentage female_unemployment ln_gdp_per_capita ln_female_population i.year, fe cluster(countryid)
outreg2 using "$output\fe_maternalmortality_womenseats_unweighted", bdec(3) 2aster tex(fragment) keep(women_seats birth_rate_percentage female_unemployment ln_gdp_per_capita ln_female_population i.year) stat(coef se pval) append ctitle("Fixed Effects, Female Unemployment (% of female labor force)") 

* Cluestered vs Simple Standard Errors 
xtreg maternal_mortality_percentage women_seats i.year [w=average_female_population], fe cluster(countryid)
outreg2 using "$output\fe_maternalmortality_womenseats_se", bdec(3) 2aster tex(fragment) keep(women_seats i.year) stat(coef se pval) replace ctitle("Clustered SE, Maternal Mortality ratio (%)") 

xtreg maternal_mortality_percentage women_seats i.year [w=average_female_population], fe
outreg2 using "$output\fe_maternalmortality_womenseats_se", bdec(3) 2aster tex(fragment) keep(women_seats i.year) stat(coef se pval) append ctitle("Simple SE, Maternal Mortality ratio (%)") 
/* Idea of clustered errors: different countries have different unobservable variables that are affecting the female unemployment */

* Long Difference Model
reg ld_maternal_mortality_percentage ld_women_seats, cluster(countryid)
outreg2 using "$output\ld_maternalmortality_womenseats_unweighted", bdec(3) 2aster tex(fragment) stat(coef se pval) replace ctitle("Long Difference Model, LD Maternal mortality ratio (%)") 

reg ld_maternal_mortality_percentage ld_women_seats ld_birth_rate_percentage ld_female_unemployment ld_ln_gdp_per_capita ld_ln_female_population, cluster(countryid)
outreg2 using "$output\ld_maternalmortality_womenseats_unweighted", bdec(3) 2aster tex(fragment) stat(coef se pval) append ctitle("Long Difference Model, LD Maternal Mortality ratio (%)")

*------------------ Robustness: Logarithmic Regressions ------------------ *

* OLS 
reg ln_maternal_mortality_percentage ln_women_seats ln_birth_rate_percentage ln_female_unemployment ln_gdp_per_capita ln_female_population if year == 2000
outreg2 using "$output\ols_lnmaternalmortality_lnwomenseats", bdec(3) 2aster tex(fragment) stat(coef se pval) append ctitle("Year = 2000, Natural Logarithm of Maternal Mortality ratio (%)") 

reg ln_maternal_mortality_percentage ln_women_seats ln_birth_rate_percentage ln_female_unemployment ln_gdp_per_capita ln_female_population if year == 2017
outreg2 using "$output\ols_lnmaternalmortality_lnwomenseats", bdec(3) 2aster tex(fragment) stat(coef se pval) append ctitle("Year = 2017, Natural Logarithm of Maternal Mortality ratio (%)") 

* Basic FD:
reg d_ln_maternalmortalitypercentage d_ln_women_seats [w=female_population], cluster(countryid)
outreg2 using "$output\fd_lnmaternalmortality_lnwomenseats_weighted", bdec(3) 2aster tex(fragment) keep(d_ln_women_seats) stat(coef se pval) replace ctitle("FD With No Lags, FD Maternal Mortality ratio (%)")

* FD with 4 lags:
reg d_ln_maternalmortalitypercentage L(0/4).d_ln_women_seats [w=female_population], cluster(countryid)
outreg2 using "$output\fd_lnmaternalmortality_lnwomenseats_weighted", bdec(3) 2aster tex(fragment) keep(L(0/4).d_ln_women_seats) stat(coef se pval) append ctitle("FD With 4 Lags, FD Natural Logarithm of Maternal Mortality ratio (%)")

* Basic FD with confounders:
reg d_ln_maternalmortalitypercentage d_ln_women_seats d_ln_birth_rate_percentage d_ln_female_unemployment d_ln_gdp_per_capita d_ln_female_population [w=female_population], cluster(countryid)
outreg2 using "$output\fd_lnmaternalmortality_lnwomenseats_weighted", bdec(3) 2aster tex(fragment) keep(d_ln_women_seats d_ln_birth_rate_percentage d_ln_female_unemployment d_ln_gdp_per_capita d_ln_female_population) stat(coef se pval) append ctitle("FD With No Lags, FD Natural Logarithm of Maternal Mortality ratio (%)") 

* FD with 4 lags with confounders:
reg d_ln_maternalmortalitypercentage L(0/4).d_ln_women_seats d_ln_birth_rate_percentage d_ln_female_unemployment d_ln_gdp_per_capita d_ln_female_population [w=female_population], cluster(countryid)
outreg2 using "$output\fd_lnmaternalmortality_lnwomenseats_weighted", bdec(3) 2aster tex(fragment) keep(L(0/4).d_ln_women_seats d_ln_birth_rate_percentage d_ln_female_unemployment d_ln_gdp_per_capita d_ln_female_population) stat(coef se pval) append ctitle("FD With 4 Lags, FD Natural Logarithm of Maternal Mortality ratio (%)")

* FE Regressions:
xtreg ln_maternal_mortality_percentage ln_women_seats i.year [w=average_female_population], fe cluster(countryid)
outreg2 using "$output\fe_lnmaternalmortality_lnwomenseats_weighted", bdec(3) 2aster tex(fragment) keep(ln_women_seats i.year) stat(coef se pval) replace ctitle("Fixed Effects, Natural Logarithm of Maternal Mortality ratio (%)") 

* FE Regressions with confounders:
xtreg ln_maternal_mortality_percentage ln_women_seats ln_birth_rate_percentage ln_female_unemployment ln_gdp_per_capita ln_female_population i.year [w=average_female_population], fe cluster(countryid)
outreg2 using "$output\fe_lnmaternalmortality_lnwomenseats_weighted", bdec(3) 2aster tex(fragment) keep(ln_women_seats ln_birth_rate_percentage ln_female_unemployment ln_gdp_per_capita ln_female_population i.year) stat(coef se pval) append ctitle("Fixed Effects, Natural Logarithm of Maternal Mortality ratio (%)") 

* Long Difference Model
bysort countryid : gen ld_lnmaternalmortalitypercentage = ln_maternal_mortality_percentage[_N] - ln_maternal_mortality_percentage[1]
bysort countryid : gen ld_ln_women_seats = ln_women_seats[_N] - ln_women_seats[1]
bysort countryid : gen ld_ln_birth_rate_percentage = ln_birth_rate[_N] - ln_birth_rate[1]
bysort countryid : gen ld_ln_female_unemployment = ln_female_unemployment[_N] - ln_female_unemployment[1]

reg ld_lnmaternalmortalitypercentage ld_ln_women_seats [w=average_female_population], cluster(countryid)
outreg2 using "$output\ld_lnmaternalmortality_lnwomenseats_weighted", bdec(3) 2aster tex(fragment) stat(coef se pval) replace ctitle("Long Difference Model, LD Maternal Mortality ratio (%)")

* Long Difference Model with confounders:
reg ld_lnmaternalmortalitypercentage ld_ln_women_seats ld_ln_birth_rate_percentage ld_ln_female_unemployment ld_ln_gdp_per_capita ld_ln_female_population [w=average_female_population], cluster(countryid)
outreg2 using "$output\ld_lnmaternalmortality_lnwomenseats_weighted", bdec(3) 2aster tex(fragment) stat(coef se pval) append ctitle("Long Difference Model, LD Maternal Mortality ratio (%)")
