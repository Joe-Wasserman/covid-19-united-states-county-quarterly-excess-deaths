# This script conforms historical and recent US mortality data
# Estimates 2020 expected and excess mortality by county and quarter

# libraries necessary for analyses
library(tidyverse)
library(furrr)
library(tidycensus)
library(data.table)
library(lubridate)
library(aweek)
library(lme4)
library(glmmTMB)

## ---- import ----

# Import historical county-monthly data downloaded from CDC WONDER
# https://wonder.cdc.gov/ucd-icd10.html
# NOTE: County-quarters with < 10 deaths are censored in these data
united_states_county_monthly_total_deaths <- list.files(
  file.path(here::here(), "data"),
  pattern = "^All.*",
  full.names = TRUE
) %>%
  map_dfr(
    ~ data.table::fread(
      .x,
      header = FALSE,
      skip = 1,
      col.names = c(
        "Notes", "Year", "Year Code", "Month", "Month Code",
        "State", "State Code", "County", "County Code",
        "Deaths", "Population", "Crude Rate"
      ),
      na.strings = c("Missing", "Suppressed", "Not Applicable"),
      keepLeadingZeros = TRUE,
      colClasses = c("character")
    )
  )

# Import NCHS Provisional COVID-19 Deaths by Quarter and County for 2020-2021
# https://data.cdc.gov/NCHS/AH-Provisional-COVID-19-Death-Counts-by-Quarter-an/dnhi-s2bf
# NOTE: County-quarters with < 10 deaths are censored in these data
# NOTE: Dataset should have only one row per FIPS, but has duplicates for
# 5 NY FIPS as of 2021-11-05: 36005, 26047, 36061, 36081, 36085
try(
  united_states_county_quarterly_covid_deaths <- data.table::fread(
    "https://data.cdc.gov/api/views/dnhi-s2bf/rows.csv",
    keepLeadingZeros = TRUE
  )
)

# If the above CDC data are unavailabe, retrieve the local version instead
if (!exists("united_states_county_quarterly_covid_deaths")) {
  united_states_county_quarterly_covid_deaths <- data.table::fread(
    file.path(
      here::here(),
      "data/united_states_county_quarterly_covid_deaths.csv"
    ),
    keepLeadingZeros = TRUE
  )
}

data.table::fwrite(
  united_states_county_quarterly_covid_deaths,
  file.path(
    here::here(),
    "data/united_states_county_quarterly_covid_deaths.csv"
  )
)

# Import 2010 US Census County Sets
# See https://www.census.gov/geographies/reference-files/2000/demo/eeo/county-sets.html
try(
  county_sets <- data.table::fread(
    file.path(
      here::here(),
      "data/county_sets.csv"
    ),
    keepLeadingZeros = TRUE
  )
)

# if local version is unavailable, download and save a copy locally
if (!exists("county_sets")) {
  httr::GET(
    "https://www2.census.gov/programs-surveys/demo/reference-files/eeo/time-series/eeo-county-sets-2010.xls",
    httr::write_disk(tf <- tempfile(fileext = ".xls"))
  )

  county_sets <- readxl::read_xls(
    tf,
    sheet = 1,
    skip = 3
  )
}

data.table::fwrite(
  county_sets,
  file.path(
    here::here(),
    "data/county_sets.csv"
  )
)

# Construct data frame of state abbreviations + divisions, plus DC
census_division <- tibble(
  state = state.abb,
  census_division = state.division,
  census_region = state.region
) %>%
  add_row(
    state = "DC",
    census_division = "South Atlantic",
    census_region = "South"
  )

# Import vintage 2020 2010-2020 county population estimates from US census
# See https://www.census.gov/programs-surveys/popest/technical-documentation/research/evaluation-estimates/2020-evaluation-estimates/2010s-counties-total.html
# NOTE: As of 2021-10-09 vintage 2020 population estimates for 2010-2020 have not been added to the Census API
try(
  united_states_county_yearly_population_2020 <- data.table::fread(
    file.path(
      here::here(),
      "data/united_states_county_yearly_population_2020.csv"
    ),
    keepLeadingZeros = TRUE
  )
)

# if local version is unavailable, download and save a copy locally
if (!exists("united_states_county_yearly_population_2020")) {
  united_states_county_yearly_population_2020 <- data.table::fread(
    "https://www2.census.gov/programs-surveys/popest/datasets/2010-2020/counties/totals/co-est2020.csv",
    keepLeadingZeros = TRUE
  )
}

data.table::fwrite(
  united_states_county_yearly_population_2020,
  file.path(
    here::here(),
    "data/united_states_county_yearly_population_2020.csv"
  )
)

# Import FIPS code details table
data(fips_codes)

states_50 <- (fips_codes %>% distinct(state, state_code))[1:51, ]

county_names <- fips_codes %>%
  transmute(
    region_code = paste0(state_code, county_code),
    region = paste(county, state, sep = ", "),
    state
  )

## ---- conform-data ----

# Format yearly county population data
# Conform county FIPS codes to match other datasets
# Fill forward 2020 values for 2021, 2021 county pop estimates unavailable
# For details on county FIPS code changes, see:
# https://www.ddorn.net/data/FIPS_County_Code_Changes.pdf
united_states_county_yearly_population_interim <- united_states_county_yearly_population_2020 %>%
  filter(COUNTY != "000") %>%
  pivot_longer(
    cols = starts_with("POPESTIMATE"),
    names_to = "year",
    names_prefix = "POPESTIMATE",
    values_to = "population"
  ) %>%
  transmute(
    country = "United States",
    region_code = paste0(STATE, COUNTY),
    region_code = case_when(
      region_code == "02063" ~ "02261",
      region_code == "02066" ~ "02261",
      region_code == "02158" ~ "02270",
      region_code == "46102" ~ "46113",
      TRUE ~ region_code
    ),
    state_code = STATE,
    year = as.integer(year),
    population
  ) %>%
  filter(year != 42020) %>%
  group_by(country, region_code, state_code, year) %>%
  summarise(population = sum(population), .groups = "drop")

united_states_county_yearly_population_complete <- united_states_county_yearly_population_interim %>%
  filter(year == 2020L) %>%
  mutate(year = 2021L) %>%
  bind_rows(united_states_county_yearly_population_interim)

# clean up county sets data
# NOTE: County sets include all US counties in NCHS deaths data
county_sets_clean <- county_sets %>%
  select(-1) %>%
  mutate(across(where(is.character), ~ na_if(., ""))) %>%
  filter(!is.na(`FIPS County Code`)) %>%
  transmute(
    county_set_code = `2010 CS Code`,
    region_code = paste0(`FIPS State Code`, `FIPS County Code`)
  ) %>%
  tidyr::fill(county_set_code, .direction = "down")

# Format and create additional variables for county-monthly dataset
# NOTE: Missing and censored values are not replaced
united_states_county_monthly_total_deaths_clean <- united_states_county_monthly_total_deaths %>%
  transmute(
    country = "United States",
    region_code = `County Code`,
    year = as.integer(`Year Code`),
    quarter = quarter(ym(`Month Code`)),
    month = month(ym(`Month Code`)),
    start_date = ym(paste(year, month, sep = "-")),
    end_date = ceiling_date(start_date, unit = "month") - 1,
    days = as.integer(end_date - start_date + 1),
    total_deaths = as.integer(Deaths)
  ) %>%
  dplyr::select(
    country, region_code, start_date, end_date, days, year,
    quarter, month, total_deaths
  )

# Summarize historical county-month deaths by county-quarter
# NOTE: Missing and censored values are not replaced
# Quarters that include months with missing values are treated as missing
united_states_county_quarterly_total_deaths <- united_states_county_monthly_total_deaths_clean %>%
  mutate(
    start_date = yq(paste(year, quarter, sep = "-")),
    end_date = ceiling_date(start_date + months(2), unit = "month") - 1
  ) %>%
  group_by(
    country, region_code, year, quarter, start_date, end_date
  ) %>%
  summarise(
    across(c(total_deaths, days), sum),
    .groups = "drop"
  ) %>%
  dplyr::select(
    country, region_code, start_date, end_date, days, year,
    quarter, total_deaths
  )

# Conform 2020-2021 county-quarter total and COVID deaths to data model
# NOTE: Missing and censored values are treated as 0s
# NOTE: Dataset should have only one row per FIPS, but has duplicates for
# 5 NY FIPS as of 2021-11-05: 36005, 26047, 36061, 36081, 36085
united_states_county_quarterly_covid_deaths_clean <- united_states_county_quarterly_covid_deaths %>%
  transmute(
    country = "United States",
    region_code = `FIPS Code`,
    year = Year,
    quarter = Quarter,
    start_date = yq(paste(year, quarter, sep = "-")),
    end_date = ceiling_date(start_date + months(2), unit = "month") - 1,
    days = as.integer(end_date - start_date + 1L),
    total_deaths = as.integer(`Total Deaths`),
    covid_deaths = as.integer(`COVID-19 Deaths`)
  ) %>%
  group_by(
    country, region_code, year, quarter, start_date, end_date, days
  ) %>%
  summarise(
    across(c(total_deaths, covid_deaths), sum),
    .groups = "drop"
  )

# Limit county-monthly total deaths to 50 states + Washington DC
# Adds geographic information
# Prepares variables for modeling
# NOTE: monthly deaths data includes records for counties that no longer exist and their replacements
united_states_county_monthly_deaths <- united_states_county_monthly_total_deaths_clean %>%
  mutate(state_code = str_sub(region_code, end = 2)) %>%
  semi_join(states_50, by = "state_code") %>%
  inner_join(
    united_states_county_yearly_population_complete,
    by = c("country", "region_code", "year")
  ) %>%
  left_join(
    county_names,
    by = "region_code"
  ) %>%
  left_join(
    county_sets_clean,
    by = "region_code"
  ) %>%
  left_join(
    census_division,
    by = "state"
  ) %>%
  arrange(region_code, county_set_code, census_division, census_region) %>%
  mutate(
    total_deaths_per_day = total_deaths / days,
    population_z = (population - mean(population, na.rm = TRUE)) /
      sd(population, na.rm = (TRUE)),
    across(
      c(region_code, county_set_code, census_division, census_region),
      as_factor
    )
  ) %>%
  arrange(month) %>%
  mutate(
    across(
      c(quarter, month),
      as_factor
    )
  ) %>%
  arrange(start_date) %>%
  mutate(
    time = as_factor(frank(start_date, ties.method = "dense"))
  ) %>%
  dplyr::select(
    country, state, region, region_code,
    county_set_code, census_division, census_region,
    start_date, end_date, days, year, quarter, month, time,
    population, population_z,
    total_deaths, total_deaths_per_day
  )

# Union historical county-quarterly total deaths and
# 2020-2021 county-quarterly total and covid deaths
# Limits data to 50 states + Washington DC
# Adds geographic information
# Prepares variables for modeling
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
  left_join(
    county_sets_clean,
    by = "region_code"
  ) %>%
  left_join(
    census_division,
    by = "state"
  ) %>%
  mutate(
    total_deaths_per_day = total_deaths / days,
    quarter = as_factor(quarter),
    population_z = (population - mean(population, na.rm = TRUE)) /
      sd(population, na.rm = (TRUE)),
    across(
      c(region_code, county_set_code, census_division, census_region),
      as_factor
    )
  ) %>%
  dplyr::select(
    country, state, region, region_code,
    county_set_code, census_division, census_region,
    start_date, end_date, days, year, quarter,
    population, population_z,
    total_deaths, covid_deaths, total_deaths_per_day
  )

# subset total data to pre-pandemic training dataset for icc
# NOTE: full dataset used for estimate_excess_deaths(): internally filters by date
training_data <- filter(
  united_states_county_monthly_deaths,
  end_date < ymd("2020-03-01")
)

## ---- icc ----
# Examine ICC 2015-2019 data for alternative nesting structures
icc <- list(
  # c("region_code", "month"),
  c("region_code", "county_set_code", "month"),
  # c("region_code", "census_division", "month"),
  # c("region_code", "census_region", "month"),
  c("region_code", "county_set_code", "census_division", "month"),
  c("region_code", "county_set_code", "census_region", "month"),
  # c("region_code", "state", "month"),
  c("region_code", "county_set_code", "state", "month"),
  c("region_code", "state", "census_division", "month"),
  c("region_code", "state", "census_region", "month"),
  c("region_code", "county_set_code", "state", "census_division", "month"),
  c("region_code", "county_set_code", "state", "census_region", "month")
) %>%
  furrr::future_map(
    .,
    ~ multilevelTools::iccMixed(
      dv = "total_deaths_per_day",
      id = .x,
      data = training_data
    )
  )

## ---- models ----

# set LMM control options
strictControl <- lmerControl(optCtrl = list(
  algorithm = "NLOPT_LN_NELDERMEAD",
  xtol_abs = 1e-12,
  ftol_abs = 1e-12
))

# Specify competing formulas for lmm with different nesting structures
# NOTE: lme4::lmer() does not require nested random grouping factor syntax
lmm_formulas <- list(
  # 1
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      month +
      (1 | region_code) +
      (1 | county_set_code)"
    )
  ),
  # 2
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      month +
      (1 | region_code) +
      (1 | county_set_code) +
      (1 | census_division)"
    )
  ),
  # 3
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      month +
      (1 | region_code) +
      (1 | county_set_code) +
      (1 | census_region)"
    )
  ),
  # 4
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      month +
      (1 | region_code) +
      (1 | state)"
    )
  ),
  # 5
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      month +
      (1 | region_code) +
      (1 | county_set_code) +
      (1 | state)"
    )
  ),
  # 6
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      month +
      (1 | region_code) +
      (1 | state) +
      (1 | census_division)"
    )
  ),
  # 7
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      month +
      (1 | region_code) +
      (1 | state) +
      (1 | census_region)"
    )
  ),
  # 8
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      month +
      (1 | region_code) +
      (1 | county_set_code) +
      (1 | state) +
      (1 | census_division)"
    )
  ),
  # 9
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      month +
      (1 | region_code) +
      (1 | county_set_code) +
      (1 | state) +
      (1 | census_region)"
    )
  ),
  # 5 ar1
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      month +
      ar1(time - 1 | region_code) +
      (1 | county_set_code) +
      (1 | state)"
    )
  ),
  # 9 ar1
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      month +
      ar1(time - 1 | region_code) +
      (1 | county_set_code) +
      (1 | state) +
      (1 | census_region)"
    )
  )
)

# set model type argument for running models

model_type_list <- c(
  rep("lmer", 9),
  rep("glmmTMB", 2)
)

# run all lmm models
model_out <- tibble(
   expected_deaths_formula = lmm_formulas,
   model_type = model_type_list
  ) %>%
  furrr::future_pmap(
    .,
    ~ train_expected_deaths_model(
      df = united_states_county_monthly_deaths,
      expected_deaths_formula = ..1,
      model_type = ..2,
      family = "gaussian",
      period = "month",
      training_end_date = "2020-01-01"
    )
  )


## ---- training-performance ----
# compare model performance metrics on training set
model_performance <- model_out %>%
  map(
    .,
    ~ .x[[1]]
  ) %>%
  performance::compare_performance()

expected_and_excess_deaths <- model_out %>%
  furrr::future_map(
    .,
    ~ estimate_excess_deaths(
      df = united_states_county_monthly_deaths,
      expected_deaths_model = .x[[1]],
      period = "month"
    )
  )

## ---- validation-performance ----
# compare model mean squared error on 2020-01 + 2020-02 validation set
model_mse <- expected_and_excess_deaths %>%
  imap_dfr(
    ~ .x %>%
      filter(year == 2020L, month %in% c("1", "2")) %>%
      summarise(
        model = .y,
        mse = mean(
          (expected_deaths - total_deaths)^2,
          na.rm = TRUE
        )
      )
  )

## ---- volatility ----
# evaluate prediction volatility by identifying outliers in time series

# identify outliers in fitted timeseries of data with forecast::tsoutliers
model_volatility <- expected_and_excess_deaths %>%
  furrr::future_map(
    ~ .x %>%
      select(region_code, expected_deaths) %>%
      group_by(region_code) %>%
      filter(sum(!is.na(expected_deaths)) > 2) %>%
      # forecast::tsoutliers requires > 2 non-missing values
      nest() %>%
      mutate(
        fitted_list = map(data, deframe),
        fitted_ts = map(
          fitted_list,
          ~ as.ts(.x, start = c(2011, 1), frequency = 12)
        ),
        fitted_outliers = map(
          fitted_ts,
          ~ forecast::tsoutliers(.x) %>% as.data.frame()
        ),
        fitted_clean = map(
          fitted_ts,
          ~ forecast::tsclean(.x)
        ),
        outlier_count = map_int(fitted_outliers, nrow)
      ) %>%
      ungroup()
  )

data_fitted_outliers_only <- model_volatility %>%
  map(~ .x %>%
    filter(outlier_count > 0))

model_volatility_summary <- data_fitted_outliers_only %>%
  imap_dfr(
    ~ .x %>%
      summarize(
        model = .y,
        outlier_regions = n(),
        outlier_total = sum(outlier_count)
      )
  )

## ---- plot-volatility ----
plot_ts_with_outliers <- function(region_code, fitted_ts, fitted_outliers) {
  plot_out <- autoplot(
    object = {{ fitted_ts }},
    series = "model-fitted",
    color = "gray",
    lwd = 1
  ) +
    geom_point(
      data = {{ fitted_outliers }},
      aes(x = index, y = replacements),
      col = "blue"
    ) +
    labs(x = NULL, y = NULL, title = {{ region_code }}) +
    theme_minimal() +
    theme(
      text = element_text(size = 8),
      panel.grid = element_blank()
    )
}

fitted_outlier_plots <- data_fitted_outliers_only %>%
  furrr::future_map(
    .,
    ~ if (nrow(.x) > 0) {
      .x %>%
        select(region_code, fitted_ts, fitted_outliers) %>%
        pmap(., plot_ts_with_outliers) %>%
        patchwork::wrap_plots()
    }
  )

## ---- final-model ----

final_model <- 10

united_states_county_monthly_model <- model_out[[final_model]]
united_states_county_monthly_results <- expected_and_excess_deaths[[final_model]]

# export the final selected model object
model_out_path <- file.path(here::here(), "results/united_states_county_monthly_model.RDS")

if (file.exists(model_out_path)) file.remove(model_out_path)

saveRDS(united_states_county_monthly_model[[1]], model_out_path)

# export expected deaths and estimated excess deaths
results_out_path <- file.path(here::here(), "results/united_states_county_monthly_excess_deaths_estimates.csv")

if (file.exists(results_out_path)) file.remove(results_out_path)

data.table::fwrite(
  united_states_county_monthly_results,
  results_out_path,
  append = FALSE
)

# export model-fitted values from trained model
fitted_out_path <- file.path(here::here(), "results/united_states_county_monthly_fitted_deaths_per_day_estimates.csv")

if (file.exists(fitted_out_path)) file.remove(fitted_out_path)

data.table::fwrite(
  united_states_county_monthly_model[[2]],
  fitted_out_path,
  append = FALSE
)
