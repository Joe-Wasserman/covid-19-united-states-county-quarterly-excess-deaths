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

## ---- import ----

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
try(
  united_states_county_quarterly_covid_deaths <- data.table::fread(
    "https://data.cdc.gov/api/views/ypxr-mz8e/rows.csv",
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
# For details on county FIPS code changes, see:
# https://www.ddorn.net/data/FIPS_County_Code_Changes.pdf
united_states_county_yearly_population_complete <- united_states_county_yearly_population_2020 %>%
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

# Summarize historical county-month deaths by county-quarter
# NOTE: Missing and censored values are treated as 0s
united_states_county_quarterly_total_deaths <- united_states_county_monthly_total_deaths %>%
  transmute(
    country = "United States",
    region_code = `County Code`,
    year = as.integer(Year),
    quarter = quarter(ym(`Month Code`)),
    start_date = yq(paste(year, quarter, sep = "-")),
    end_date = ceiling_date(start_date + months(2), unit = "month") - 1,
    days = as.integer(end_date - start_date + 1),
    total_deaths = as.integer(Deaths)
  ) %>%
  group_by(
    country, region_code, year, quarter, start_date, end_date, days
  ) %>%
  summarise(
    total_deaths = sum(total_deaths),
    .groups = "drop"
  ) %>%
  dplyr::select(
    country, region_code, start_date, end_date, days, year,
    quarter, total_deaths
  )

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
    covid_deaths = as.integer(`COVID-19 Deaths`)
  ) %>%
  group_by(
    country, region_code, year, quarter, start_date, end_date,
    days
  ) %>%
  summarise(
    across(c(total_deaths, covid_deaths), sum),
    .groups = "drop"
  )

# Union historical county-quarterly total deaths and
# 2020 county-quarterly total and covid deaths
# Limits data to 50 states + Washington DC
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

## ---- icc ----
# Examine ICC for alternative nesting structures
icc <- list(
  c("region_code", "quarter"),
  c("region_code", "county_set_code", "quarter"),
  c("region_code", "census_division", "quarter"),
  c("region_code", "census_region", "quarter"),
  c("region_code", "county_set_code", "census_division", "quarter"),
  c("region_code", "county_set_code", "census_region", "quarter"),
  c("region_code", "state", "quarter"),
  c("region_code", "county_set_code", "state", "quarter"),
  c("region_code", "state", "census_division", "quarter"),
  c("region_code", "state", "census_region", "quarter"),
  c("region_code", "county_set_code", "state", "census_division", "quarter"),
  c("region_code", "county_set_code", "state", "census_region", "quarter")
) %>%
  furrr::future_map(
    .,
    ~ multilevelTools::iccMixed(
      dv = "total_deaths_per_day",
      id = .x,
      data = united_states_county_quarterly_deaths
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
      quarter +
      (1 | region_code)"
    )
  ),
  # 2
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      quarter +
      (1 | region_code) +
      (1 | county_set_code)"
    )
  ),
  # 3
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      quarter +
      (1 | region_code) +
      (1 | census_division)"
    )
  ),
  # 4
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      quarter +
      (1 | region_code) +
      (1 | census_region)"
    )
  ),
  # 5
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      quarter +
      (1 | region_code) +
      (1 | county_set_code) +
      (1 | census_division)"
    )
  ),
  # 6
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      quarter +
      (1 | region_code) +
      (1 | county_set_code) +
      (1 | census_region)"
    )
  ),
  # 7
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      quarter +
      (1 | region_code) +
      (1 | state)"
    )
  ),
  # 8
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      quarter +
      (1 | region_code) +
      (1 | county_set_code) +
      (1 | state)"
    )
  ),
  # 9
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      quarter +
      (1 | region_code) +
      (1 | state) +
      (1 | census_division)"
    )
  ),
  # 10
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      quarter +
      (1 | region_code) +
      (1 | state) +
      (1 | census_region)"
    )
  ),
  # 11
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      quarter +
      (1 | region_code) +
      (1 | county_set_code) +
      (1 | state) +
      (1 | census_division)"
    )
  ),
  # 12
  as.formula(
    glue::glue(
      "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      quarter +
      (1 | region_code) +
      (1 | county_set_code) +
      (1 | state) +
      (1 | census_region)"
    )
  )
)

# run all models
model_out <- lmm_formulas %>%
  furrr::future_map(
    .,
    ~ estimate_excess_deaths(
      df = united_states_county_quarterly_deaths,
      expected_deaths_formula = .x,
      period = "quarter",
      calculate = TRUE,
      train_model = TRUE
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

expected_deaths <- model_out %>%
  furrr::future_map(
    .,
    ~ united_states_county_quarterly_deaths %>%
      mutate(year_zero = year - 2015L) %>%
      mutate(
        expected_deaths = predict(
          object = .x[[1]],
          newdata = .,
          type = "response",
          allow.new.levels = TRUE
        ) * days
      )
  )

## ---- validation-performance ----
# compare model mean squared error on 2020 Q1 validation set
model_mse <- expected_deaths %>%
  imap_dfr(
    ~ .x %>%
      filter(year == 2020, quarter == "1") %>%
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
model_volatility <- expected_deaths %>%
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
          ~ as.ts(.x, start = c(2015, 1), frequency = 4)
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
    object = fitted_ts,
    series = "model-fitted",
    color = "gray",
    lwd = 1
  ) +
    geom_point(
      data = fitted_outliers,
      aes(x = index, y = replacements),
      col = "blue"
    ) +
    labs(x = NULL, y = NULL, title = region_code) +
    theme_minimal() +
    theme(
      text = element_text(size = 8),
      panel.grid = element_blank()
    )
}

fitted_outlier_plots <- data_fitted_outliers_only %>%
  furrr::future_map(
    .,
    ~ .x %>%
      select(region_code, fitted_ts, fitted_outliers) %>%
      pmap(., plot_ts_with_outliers) %>%
      patchwork::wrap_plots()
  )

## ---- final-model ----

# Estimate expected and excess deaths for 2020 using selected model

# run the final selected model
united_states_county_quarterly_results <- estimate_excess_deaths(
  df = united_states_county_quarterly_deaths,
  expected_deaths_formula = lmm_formulas[[8]],
  period = "quarter",
  calculate = TRUE,
  train_model = TRUE
)

# export model object
saveRDS(
  united_states_county_quarterly_results[[1]],
  file.path(
    here::here(),
    "results/united_states_county_quarterly_model.RDS"
  )
)

# export predicted values
data.table::fwrite(
  united_states_county_quarterly_results[[2]],
  file.path(
    here::here(),
    "results/united_states_county_quarterly_excess_deaths_estimates.csv"
  )
)

# export model-fitted values from training data
data.table::fwrite(
  united_states_county_quarterly_results[[3]],
  file.path(
    here::here(),
    "results/united_states_county_quarterly_fitted_deaths_per_day_estimates.csv"
  )
)
