# define function to estimate excess deaths
# adapted from The Economist's excess deaths model
# see https://github.com/TheEconomist/covid-19-excess-deaths-tracker

estimate_excess_deaths <- function(df, expected_deaths_model = NULL, period = "quarter", calculate = TRUE, train_model = TRUE){

  year_min <- min(df$year, na.rm = TRUE)

  df_model <- df %>%
    mutate(
      year_zero = year - year_min
    )

  # Define quarterly (or monthly) model to estimate expected deaths
  # Outcome: total deaths per day
  # population (centered and standardized) linear term
  # year linear term
  # period (ie, quarter or month) fixed effects
  # region (ie, county) random grouping factor
  expected_deaths_formula <- as.formula(
    glue::glue(
    "total_deaths_per_day ~ 1 +
      population_z +
      year_zero +
      {period} +
      (1 | region)"
    )
  )

  # set LMM control options
  strictControl <- lmerControl(optCtrl = list(
    algorithm = "NLOPT_LN_NELDERMEAD",
    xtol_abs = 1e-12,
    ftol_abs = 1e-12
    )
    )

  # Calculate expected deaths
  if(calculate == FALSE) {

    # Use pre-existing official model results
    expected_deaths <- df %>%
      filter(year >= 2020)

  } else if(train_model == FALSE) {

    # Use previously trained model
    expected_deaths <- df_model %>%
      filter(year >= 2020) %>%
      mutate(
        expected_deaths = predict(expected_deaths_model, .) * days
      )

  } else if(period %in% c("month", "quarter")) {

    # Train a monthly or quarterly model

    train_df <- df_model %>%
      filter(end_date < ymd("2020-03-01")) %>%
      mutate(
        total_deaths_per_day = total_deaths / days
      )

    # estimate linear mixed effects regression (LMER)
    # NOTE: if this model fails, use allFit to compare values from multiple
    # optimizers
    expected_deaths_model <- lmer(
      expected_deaths_formula,
      train_df,
      REML = FALSE,
      control = strictControl
    )

    expected_deaths <- df_model %>%
      filter(year >= 2020) %>%
      mutate(
        expected_deaths = predict(
          expected_deaths_model,
          newdata = .,
          type = "response",
          allow.new.levels = TRUE
          ) * days
      )

  }

  # Calculate excess deaths
  # Replace negative expected deaths (impossible) with 0
  excess_deaths <- expected_deaths %>%
    mutate(
      expected_deaths = pmax(expected_deaths, 0),
      excess_deaths = total_deaths - expected_deaths,
      non_covid_deaths = total_deaths - covid_deaths,
      region_code = as.character(region_code),
      covid_deaths_per_100k = covid_deaths / population * 100000,
      excess_deaths_per_100k = excess_deaths / population * 100000,
      excess_deaths_pct_change =
        ((expected_deaths + excess_deaths) / expected_deaths) - 1
    )

  # Message when negative estimates replaced with zero, as negative deaths are impossible
  if (any(expected_deaths$expected_deaths < 0)) {

    predicted_zeroes <- sum(expected_deaths$expected_deaths < 0, na.rm = TRUE)

    message(
      glue::glue(
        "{predicted_zeroes} estimated excess deaths < 0 were replaced with 0"
      )
    )
  }

  # Calculate weekly rates for monthly and quarterly data
  if(period %in% c("month", "quarter")) {

    excess_deaths <- excess_deaths %>%
      mutate(
        total_deaths_per_7_days = total_deaths / days * 7,
        covid_deaths_per_7_days = covid_deaths / days * 7,
        expected_deaths_per_7_days = expected_deaths / days * 7,
        excess_deaths_per_7_days = excess_deaths / days * 7,
        non_covid_deaths_per_7_days = non_covid_deaths / days * 7,
        covid_deaths_per_100k_per_7_days = covid_deaths_per_100k / days * 7,
        excess_deaths_per_100k_per_7_days = excess_deaths_per_100k / days * 7
      )

  }

  list(expected_deaths_model, excess_deaths)

}
