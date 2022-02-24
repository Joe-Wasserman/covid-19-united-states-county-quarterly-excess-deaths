# define functions to
# 1. train a model to estimate expected deaths
# 2. estimate excess deaths from model predictions
# adapted from The Economist's excess deaths model
# see https://github.com/TheEconomist/covid-19-excess-deaths-tracker

train_expected_deaths_model <- function(df, expected_deaths_formula = NULL, period = "month", training_end_date = "2020-01-01", model_type = "lmer") {
  if (is.null(expected_deaths_formula)) {
    stop("Must supply a model formula")
  }

  year_min <- min(df$year, na.rm = TRUE)

  df_model <- df %>%
    mutate(
      year_zero = year - year_min
    )

  if (period %in% c("month", "quarter")) {

    # Train a monthly or quarterly model
    train_df <- df_model %>%
      filter(end_date < ymd(training_end_date))

    if (model_type == "lmer") {
      # estimate linear mixed effects regression (LMER)
      # NOTE: if this model fails, use allFit to compare values from multiple
      # optimizers
      expected_deaths_model <- lmerTest::lmer(
        expected_deaths_formula,
        train_df,
        REML = FALSE,
        control = strictControl
      )

      # return fitted values from training data for model evaluation and diagnostics
      df_fit <- broom.mixed::augment(expected_deaths_model)
    }
    if (model_type == "spaMM") {

      # estimate linear mixed effects regression with temporal autocorrelation
      # note: ML is the default estimator in spaMM
      expected_deaths_model <- spaMM::fitme(
        expected_deaths_formula,
        train_df
      )

      # TODO create function to tidy output with https://easystats.github.io/insight/
      df_fit <- NULL
    }
    if (model_type == "glmmTMB") {

      # estimate linear mixed effects regression with temporal autocorrelation
      # note: ML is the default estimator in glmmTMB
      expected_deaths_model <- glmmTMB::glmmTMB(
        expected_deaths_formula,
        train_df,
        dispformula = ~ 1 + population_z
      )

      # return fitted values from training data for model evaluation and diagnostics
      df_fit <- broom.mixed::augment(expected_deaths_model)
    }
  }
  list(expected_deaths_model, df_fit)
}

estimate_excess_deaths <- function(df, expected_deaths_model = NULL, period = "month") {
  if (is.null(expected_deaths_model)) {
    stop(glue::glue("expected_deaths_model must be a model object to use to estimate expected deaths."))
  }

  year_min <- min(df$year, na.rm = TRUE)

  df_model <- df %>%
    mutate(
      year_zero = year - year_min
    )

  # predict expected deaths for all observations, including historical
  # using previously trained model
  expected_deaths <- df_model %>%
    mutate(
      expected_deaths = predict(
        expected_deaths_model,
        newdata = .,
        type = "response",
        allow.new.levels = TRUE
      ) * days
    )

  # Calculate excess deaths
  # Replace negative expected deaths (impossible) with 0
  excess_deaths <- expected_deaths %>%
    mutate(
      expected_deaths = pmax(expected_deaths, 0),
      excess_deaths = total_deaths - expected_deaths,
      # non_covid_deaths = total_deaths - covid_deaths,
      region_code = as.character(region_code),
      # covid_deaths_per_100k = covid_deaths / population * 100000,
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
  if (period %in% c("month", "quarter")) {
    excess_deaths <- excess_deaths %>%
      mutate(
        total_deaths_per_7_days = total_deaths / days * 7,
        # covid_deaths_per_7_days = covid_deaths / days * 7,
        expected_deaths_per_7_days = expected_deaths / days * 7,
        excess_deaths_per_7_days = excess_deaths / days * 7,
        # non_covid_deaths_per_7_days = non_covid_deaths / days * 7,
        # covid_deaths_per_100k_per_7_days = covid_deaths_per_100k / days * 7,
        excess_deaths_per_100k_per_7_days = excess_deaths_per_100k / days * 7
      )
  }

  excess_deaths
}
