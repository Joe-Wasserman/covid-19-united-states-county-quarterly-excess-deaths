# This script conforms historical and recent US mortality data
# Estimates 2020 expected and excess mortality by county and quarter

# Load libraries and functions ####
library(tidyverse)
library(tidycensus)
library(data.table)
library(lubridate)
library(aweek)
library(lme4)
options(scipen=999)

source(
  file.path(here::here(), "code/estimate_excess_deaths.R")
)

# Import data ####

# NOTE: Obtaining US census data via tidycensus requires a Census API key
# Obtain a key here http://api.census.gov/data/key_signup.html
# Store key in .Renviron with: census_api_key("YOUR KEY", install = TRUE)

# Import historical county-monthly data downloaded from CDC WONDER
# https://wonder.cdc.gov/ucd-icd10.html
# NOTE: County-quarters with < 10 deaths are censored in these data
united_states_county_monthly_total_deaths <- list.files(
  file.path(here::here(), "data"),
  pattern = "*.txt",
  full.names = TRUE
) %>%
  map_dfr(
    ~ data.table::fread(
      .x,
      na.strings = c("Missing", "Suppressed", "Not Applicable"),
      keepLeadingZeros = TRUE,
      colClasses = c("character")
    )
  )

# Import NCHS Provisional COVID-19 Deaths by Quarter, County and Age for 2020 data
# https://data.cdc.gov/NCHS/AH-Provisional-COVID-19-Deaths-by-Quarter-County-a/ypxr-mz8e
# NOTE: County-quarter-agebands with < 10 deaths are censored in these data
united_states_county_quarterly_covid_deaths <- data.table::fread(
  "https://data.cdc.gov/api/views/ypxr-mz8e/rows.csv",
  keepLeadingZeros = TRUE
)

# If the above CDC data no longer exists, retrieve the local version instead
if(!exists("united_states_county_quarterly_covid_deaths")){
  united_states_county_quarterly_covid_deaths <- data.table::fread(
    file.path(
      here::here(),
      "data/united_states_county_quarterly_covid_deaths.csv"
    ),
    keepLeadingZeros = TRUE
  )
}

# Import yearly county population estimates from US census
# https://www.census.gov/programs-surveys/popest.html
united_states_county_yearly_population <- tidycensus::get_estimates(
  geography = "county",
  product = "population",
  year = 2019,
  time_series = TRUE,
  key = Sys.getenv("CENSUS_API_KEY")
)

# Import FIPS code details table
data(fips_codes)

states_50 <- (fips_codes %>% distinct(state, state_code))[1:51,]

county_names <- fips_codes %>%
  transmute(
    region_code = paste0(state_code, county_code),
    region = paste(county, state, sep = ", "),
    state
  )

# Format and conform data ####

# Format yearly county population data
# Conform county FIPS codes to match other datasets
# For details on county FIPS code changes, see:
# https://www.ddorn.net/data/FIPS_County_Code_Changes.pdf
# For details on mapping DATE to years see:
# https://www.census.gov/data/developers/data-sets/popest-popproj/popest/popest-vars/2019.html
united_states_county_yearly_population_formatted <- united_states_county_yearly_population %>%
  filter(
    variable == "POP",
    DATE >= 3
  ) %>%
  transmute(
    country = "United States",
    region_code = case_when(
      GEOID == "02158" ~ "02270",
      GEOID == "46102" ~ "46113",
      TRUE ~ GEOID),
    year = as.integer(DATE) + 2007L,
    population = as.integer(value)
  )

# pretend 2020 pop is the same as 2019
united_states_county_yearly_population_complete <- united_states_county_yearly_population_formatted %>%
  filter(year == 2019L) %>%
  mutate(year = 2020L) %>%
  bind_rows(united_states_county_yearly_population_formatted)

# Summarize historical county-month deaths by county-quarter
# NOTE: Missing and censored values are treated as 0s
united_states_county_quarterly_total_deaths <- united_states_county_monthly_total_deaths %>%
  transmute(
    country = "United States",
    region_code = `County Code`,
    year = as.integer(Year),
    quarter = quarter(ym(`Month Code`)),
    start_date = yq(paste(year, quarter, sep = "-")),
    end_date = ceiling_date(start_date + months(2), unit="month") - 1,
    days = as.integer(end_date - start_date + 1),
    total_deaths = as.integer(Deaths),
    total_deaths = replace_na(total_deaths, 0L)
  ) %>%
  group_by(
    country, region_code, year, quarter, start_date, end_date, days
  ) %>%
  summarise(
    total_deaths = sum(total_deaths, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::select(country, region_code, start_date, end_date, days, year,
                quarter, total_deaths)

# Summarize 2020 county-quarter-ageband total and COVID deaths by county-quarter
# NOTE: Missing and censored values are treated as 0s
united_states_county_quarterly_covid_deaths_clean <- united_states_county_quarterly_covid_deaths %>%
  filter(`Age Group` %in% c("65 years and over", "<65 years")) %>%
  transmute(
    country = "United States",
    region_code = `FIPS Code`,
    year = Year,
    quarter = Quarter,
    start_date = mdy(`Start Date`),
    end_date = mdy(`End Date`),
    days = as.integer(end_date - start_date + 1L),
    total_deaths = as.integer(`Total Deaths`),
    covid_deaths = as.integer(`COVID-19 Deaths`),
    across(c(total_deaths, covid_deaths), replace_na, 0L)
  ) %>%
  group_by(country, region_code, year, quarter, start_date, end_date,
           days) %>%
  summarise(
    across(c(total_deaths, covid_deaths), sum, na.rm = TRUE),
    .groups = "drop"
    )

# Union historical county-quarterly total deaths and
# 2020 county-quarterly total and covid deaths
# Limits data to 50 states + Washington DC
# Consider omitting counties that had zero (or completely censored) deaths in all quarters
united_states_county_quarterly_deaths <- united_states_county_quarterly_total_deaths %>%
  bind_rows(united_states_county_quarterly_covid_deaths_clean) %>%
  mutate(state_code = str_sub(region_code, end = 2)) %>%
  semi_join(states_50, by = "state_code") %>%
  left_join(
    united_states_county_yearly_population_complete,
    by = c("country", "region_code", "year")
  ) %>%
  left_join(
    county_names,
    by = "region_code"
  ) %>%
  mutate(
    expected_deaths = "TBC", # To be calculated
    quarter = as_factor(quarter),
    population_z = (population - mean(population, na.rm = TRUE)) /
      sd(population, na.rm = (TRUE))
  ) %>%
  # group_by(region) %>%
  # mutate(total_deaths_max = max(total_deaths)) %>%
  # ungroup() %>%
  # filter(total_deaths_max != 0) %>%
  # ungroup() %>%
  dplyr::select(country, state, region, region_code, start_date, end_date, days,
                year, quarter, population, population_z, total_deaths,
                covid_deaths, expected_deaths)

# Estimate expected and excess deaths for 2020 ####

united_states_county_quarterly_results <- estimate_excess_deaths(
  df = united_states_county_quarterly_deaths,
  period = "quarter",
  calculate = TRUE,
  train_model = TRUE
)

saveRDS(
  united_states_county_quarterly_results[[1]],
  file.path(
    here::here(),
    "results/united_states_county_quarterly_model.RDS"
  )
)

data.table::fwrite(
  united_states_county_quarterly_results[[2]],
  file.path(
    here::here(),
    "results/united_states_county_quarterly_excess_deaths_estimates.csv"
  )
)

data.table::fwrite(
  united_states_county_quarterly_covid_deaths,
  file.path(
    here::here(),
    "data/united_states_county_quarterly_covid_deaths.csv"
  )
)
