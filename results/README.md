COVID-19 United States Excess Deaths by county and month: Model
comparison and selection
================

<!-- /results/README.md is generated from /results/README.Rmd. Please edit that file -->

# Model comparison strategy

Several models with alternate specifications of random grouping factors
were evaluated. To select a model, they were compared in terms of:

1.  Performance on January, 2011 - February, 2020 training data

2.  Performance on March, 2020 data

3.  Outlier estimates in training data

# Intraclass correlations

First, we examined the intraclass correlation coefficients for each
specification to evaluate their reasonableness.

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.006 | 0.027 |
| county_set_code | 70.706 | 0.966 |
| month           |  0.032 | 0.000 |
| Residual        |  0.477 | 0.007 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.007 | 0.027 |
| county_set_code | 66.883 | 0.890 |
| month           |  0.032 | 0.000 |
| census_division |  5.727 | 0.076 |
| Residual        |  0.477 | 0.006 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.007 | 0.027 |
| county_set_code | 68.333 | 0.910 |
| month           |  0.032 | 0.000 |
| census_region   |  4.254 | 0.057 |
| Residual        |  0.477 | 0.006 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.008 | 0.027 |
| county_set_code | 63.007 | 0.858 |
| state           |  7.879 | 0.107 |
| month           |  0.032 | 0.000 |
| Residual        |  0.477 | 0.006 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     | 36.509 | 0.813 |
| state           |  5.141 | 0.114 |
| month           |  0.032 | 0.001 |
| census_division |  2.767 | 0.062 |
| Residual        |  0.477 | 0.011 |

| Var           |  Sigma |   ICC |
|:--------------|-------:|------:|
| region_code   | 36.504 | 0.802 |
| state         |  5.668 | 0.125 |
| month         |  0.032 | 0.001 |
| census_region |  2.843 | 0.062 |
| Residual      |  0.477 | 0.010 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.008 | 0.027 |
| county_set_code | 63.038 | 0.854 |
| state           |  5.480 | 0.074 |
| month           |  0.032 | 0.000 |
| census_division |  2.820 | 0.038 |
| Residual        |  0.477 | 0.006 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.008 | 0.027 |
| county_set_code | 63.028 | 0.849 |
| state           |  6.128 | 0.083 |
| month           |  0.032 | 0.000 |
| census_region   |  2.558 | 0.034 |
| Residual        |  0.477 | 0.006 |

# Model specifications

``` r
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
  # as.formula(
  #   glue::glue(
  #     "total_deaths_per_day ~ 1 +
  #     population_z +
  #     year_zero +
  #     month +
  #     (1 | region_code)"
  #   )
  # ),
  # 2
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
  # 3
  # as.formula(
  #   glue::glue(
  #     "total_deaths_per_day ~ 1 +
  #     population_z +
  #     year_zero +
  #     month +
  #     (1 | region_code) +
  #     (1 | census_division)"
  #   )
  # ),
  # 4
  # as.formula(
  #   glue::glue(
  #     "total_deaths_per_day ~ 1 +
  #     population_z +
  #     year_zero +
  #     month +
  #     (1 | region_code) +
  #     (1 | census_region)"
  #   )
  # ),
  # 5
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
  # 6
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
  # 7
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
  # 8
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
  # 9
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
  # 10
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
  # 11
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
  # 12
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
  )
)

# run all models
model_out <- lmm_formulas %>%
  furrr::future_map(
    .,
    ~ estimate_excess_deaths(
      df = united_states_county_monthly_deaths,
      expected_deaths_formula = .x,
      period = "month",
      train_model = TRUE
    )
  )
```

# Performance on training data

Compare model performance indices for all five models. Although many
models perform similarly for these metrics, when taken together and with
a focus on AIC and BIC, model 5 (counties nested within county sets
nested within states) and model 9 (counties nested within county sets
nested within states nested within census regions) appear to be the top
two contenders.

| Name    | Model           |    AIC | AIC_wt |    BIC | BIC_wt | R2_conditional | R2_marginal |   ICC |  RMSE | Sigma |
|:--------|:----------------|-------:|-------:|-------:|-------:|---------------:|------------:|------:|------:|------:|
| Model 1 | lmerModLmerTest | 510963 |  0.000 | 511142 |  0.000 |          0.995 |       0.899 | 0.954 | 0.613 | 0.616 |
| Model 2 | lmerModLmerTest | 510917 |  0.000 | 511106 |  0.000 |          0.995 |       0.898 | 0.955 | 0.613 | 0.616 |
| Model 3 | lmerModLmerTest | 510931 |  0.000 | 511119 |  0.000 |          0.995 |       0.897 | 0.955 | 0.613 | 0.616 |
| Model 4 | lmerModLmerTest | 513598 |  0.000 | 513777 |  0.000 |          0.995 |       0.948 | 0.900 | 0.613 | 0.617 |
| Model 5 | lmerModLmerTest | 510877 |  0.299 | 511065 |  0.988 |          0.995 |       0.901 | 0.953 | 0.613 | 0.616 |
| Model 6 | lmerModLmerTest | 513599 |  0.000 | 513787 |  0.000 |          0.995 |       0.948 | 0.900 | 0.613 | 0.617 |
| Model 7 | lmerModLmerTest | 513597 |  0.000 | 513786 |  0.000 |          0.995 |       0.948 | 0.900 | 0.613 | 0.617 |
| Model 8 | lmerModLmerTest | 510878 |  0.189 | 511077 |  0.003 |          0.995 |       0.901 | 0.953 | 0.613 | 0.616 |
| Model 9 | lmerModLmerTest | 510876 |  0.511 | 511075 |  0.009 |          0.995 |       0.901 | 0.953 | 0.613 | 0.616 |

Model Performance

# Performance on March, 2020 data

Compare mean squared error (MSE) of model-predicted death rates against
observed death rates in March, 2020. Because the COVID-19 pandemic only
began partway through March, 2020, we can evaluate model performance by
examining concordance of predicted and observed deaths in March, 2020.
Models 4, 6, and 7 have the lowest MSE, but differences between models
are very small.

| model |  mse |
|------:|-----:|
|     1 | 3251 |
|     2 | 3251 |
|     3 | 3251 |
|     4 | 3251 |
|     5 | 3251 |
|     6 | 3251 |
|     7 | 3251 |
|     8 | 3251 |
|     9 | 3251 |

Mean Squared Error of Alternate Models

# Outlier estimates

To evaluate the extent of outlier model predictions, including
unexpectedly large changes month-to-month, time series outliers were
identified using `tsoutliers()` from the
{[forecast](https://cran.r-project.org/package=forecast)} R package.
Using this method, only models 2 and 3 had no outliers. Potential
outliers identified for other states were concentrated in several
Mountain West counties with zero non-censored values 2015-2019, and
therefore mostly predicted values of zero. In the following plots for
each model and county with outliers, grey lines are predicted values and
blue dots represent values that `tsoutliers()` suggests as replacements
for outliers.

| model | outlier_regions | outlier_total |
|------:|----------------:|--------------:|
|     1 |               5 |            70 |
|     2 |               5 |            65 |
|     3 |               5 |            63 |
|     4 |              64 |          1340 |
|     5 |               7 |            81 |
|     6 |              81 |          1579 |
|     7 |              80 |          1433 |
|     8 |               7 |            82 |
|     9 |               7 |            76 |

Summary of Model Outliers

    ## [[1]]

![](README_files/plot%20volatility%20output-1.png)<!-- -->

    ## 
    ## [[2]]

![](README_files/plot%20volatility%20output-2.png)<!-- -->

    ## 
    ## [[3]]

![](README_files/plot%20volatility%20output-3.png)<!-- -->

    ## 
    ## [[4]]

![](README_files/plot%20volatility%20output-4.png)<!-- -->

    ## 
    ## [[5]]

![](README_files/plot%20volatility%20output-5.png)<!-- -->

    ## 
    ## [[6]]

![](README_files/plot%20volatility%20output-6.png)<!-- -->

    ## 
    ## [[7]]

![](README_files/plot%20volatility%20output-7.png)<!-- -->

    ## 
    ## [[8]]

![](README_files/plot%20volatility%20output-8.png)<!-- -->

    ## 
    ## [[9]]

![](README_files/plot%20volatility%20output-9.png)<!-- -->

# Final model

Based on these results, model 5 was selected as the final model. In this
model, **total deaths per day** was regressed on:

-   county population (z-scored)

-   years since 2011

-   month of the year (fixed grouping factor)

-   county (random grouping factor nested within county set)

-   county set (random grouping factor nested within state)

-   state (random grouping factor)

## Model coefficients (fixed and random effects)

| effect   | group           | term              | estimate | std.error | statistic |       df | p.value |
|:---------|:----------------|:------------------|---------:|----------:|----------:|---------:|--------:|
| fixed    | n/a             | (Intercept)       |    2.410 |     0.137 |      17.6 |     57.2 |       0 |
| fixed    | n/a             | population_z      |    7.617 |     0.027 |     284.2 |   5435.0 |       0 |
| fixed    | n/a             | year_zero         |    0.031 |     0.000 |      67.4 | 264250.4 |       0 |
| fixed    | n/a             | month2            |   -0.085 |     0.006 |     -15.3 | 259216.6 |       0 |
| fixed    | n/a             | month3            |   -0.174 |     0.006 |     -30.6 | 259240.6 |       0 |
| fixed    | n/a             | month4            |   -0.295 |     0.006 |     -51.4 | 259231.9 |       0 |
| fixed    | n/a             | month5            |   -0.410 |     0.006 |     -71.4 | 259199.9 |       0 |
| fixed    | n/a             | month6            |   -0.461 |     0.006 |     -79.9 | 259197.1 |       0 |
| fixed    | n/a             | month7            |   -0.491 |     0.006 |     -85.2 | 259194.3 |       0 |
| fixed    | n/a             | month8            |   -0.502 |     0.006 |     -87.2 | 259221.9 |       0 |
| fixed    | n/a             | month9            |   -0.467 |     0.006 |     -81.0 | 259218.4 |       0 |
| fixed    | n/a             | month10           |   -0.382 |     0.006 |     -66.6 | 259221.8 |       0 |
| fixed    | n/a             | month11           |   -0.286 |     0.006 |     -49.9 | 259237.8 |       0 |
| fixed    | n/a             | month12           |   -0.141 |     0.006 |     -24.7 | 259248.9 |       0 |
| ran_pars | region_code     | sd\_\_(Intercept) |    0.421 |       n/a |       n/a |      n/a |     n/a |
| ran_pars | county_set_code | sd\_\_(Intercept) |    2.629 |       n/a |       n/a |      n/a |     n/a |
| ran_pars | state           | sd\_\_(Intercept) |    0.767 |       n/a |       n/a |      n/a |     n/a |
| ran_pars | Residual        | sd\_\_Observation |    0.616 |       n/a |       n/a |      n/a |     n/a |

``` r
sessionInfo()
## R version 4.0.4 (2021-02-15)
## Platform: x86_64-w64-mingw32/x64 (64-bit)
## Running under: Windows 10 x64 (build 19042)
## 
## Matrix products: default
## 
## locale:
## [1] LC_COLLATE=English_United States.1252 
## [2] LC_CTYPE=English_United States.1252   
## [3] LC_MONETARY=English_United States.1252
## [4] LC_NUMERIC=C                          
## [5] LC_TIME=English_United States.1252    
## 
## attached base packages:
## [1] stats     graphics  grDevices utils     datasets  methods   base     
## 
## other attached packages:
##  [1] knitr_1.31        lme4_1.1-27.1     Matrix_1.3-2      aweek_1.0.2      
##  [5] lubridate_1.7.10  data.table_1.14.2 tidycensus_0.11.4 furrr_0.2.2      
##  [9] future_1.21.0     forcats_0.5.1     stringr_1.4.0     dplyr_1.0.5      
## [13] purrr_0.3.4       readr_2.0.2       tidyr_1.1.3       tibble_3.1.0     
## [17] ggplot2_3.3.5     tidyverse_1.3.1  
## 
## loaded via a namespace (and not attached):
##   [1] utf8_1.2.1            rms_6.2-0             tidyselect_1.1.0     
##   [4] htmlwidgets_1.5.3     grid_4.0.4            maptools_1.1-1       
##   [7] munsell_0.5.0         codetools_0.2-18      units_0.7-2          
##  [10] withr_2.4.2           colorspace_2.0-0      highr_0.8            
##  [13] uuid_0.1-4            rstudioapi_0.13       stats4_4.0.4         
##  [16] robustbase_0.93-7     ggsignif_0.6.1        TTR_0.24.2           
##  [19] listenv_0.8.0         labeling_0.4.2        emmeans_1.5.5-1      
##  [22] mnormt_2.0.2          farver_2.1.0          rprojroot_2.0.2      
##  [25] coda_0.19-4           parallelly_1.24.0     vctrs_0.3.7          
##  [28] generics_0.1.0        TH.data_1.0-10        xfun_0.26            
##  [31] ggthemes_4.2.4        R6_2.5.0              VGAM_1.1-5           
##  [34] cachem_1.0.4          assertthat_0.2.1      scales_1.1.1         
##  [37] forecast_8.15         multcomp_1.4-16       nnet_7.3-15          
##  [40] gtable_0.3.0          multcompView_0.1-8    globals_0.14.0       
##  [43] conquer_1.0.2         sandwich_3.0-0        timeDate_3043.102    
##  [46] rlang_0.4.10          MatrixModels_0.5-0    splines_4.0.4        
##  [49] rstatix_0.7.0         rgdal_1.5-23          TMB_1.7.20           
##  [52] broom_0.7.9           checkmate_2.0.0       yaml_2.2.1           
##  [55] reshape2_1.4.4        abind_1.4-5           modelr_0.1.8         
##  [58] backports_1.2.1       quantmod_0.4.18       Hmisc_4.5-0          
##  [61] tools_4.0.4           psych_2.1.3           lavaan_0.6-8         
##  [64] ellipsis_0.3.1        RColorBrewer_1.1-2    proxy_0.4-26         
##  [67] extraoperators_0.1.1  tigris_1.5            Rcpp_1.0.7           
##  [70] plyr_1.8.6            base64enc_0.1-3       classInt_0.4-3       
##  [73] ggpubr_0.4.0          rpart_4.1-15          fracdiff_1.5-1       
##  [76] cowplot_1.1.1         zoo_1.8-9             haven_2.3.1          
##  [79] cluster_2.1.0         fs_1.5.0              here_1.0.1           
##  [82] magrittr_2.0.1        openxlsx_4.2.3        lmerTest_3.1-3       
##  [85] SparseM_1.81          lmtest_0.9-38         reprex_2.0.0         
##  [88] tmvnsim_1.0-2         mvtnorm_1.1-1         matrixStats_0.58.0   
##  [91] patchwork_1.1.1       hms_1.0.0             evaluate_0.14        
##  [94] xtable_1.8-4          rio_0.5.26            jpeg_0.1-8.1         
##  [97] JWileymisc_1.2.0      broom.mixed_0.2.6     readxl_1.3.1         
## [100] gridExtra_2.3         compiler_4.0.4        mice_3.13.0          
## [103] KernSmooth_2.23-18    V8_3.4.0              crayon_1.4.1         
## [106] minqa_1.2.4           htmltools_0.5.1.1     mgcv_1.8-33          
## [109] tzdb_0.1.2            multilevelTools_0.1.1 Formula_1.2-4        
## [112] rdocsyntax_0.4.1.9000 DBI_1.1.1             dbplyr_2.1.1         
## [115] MASS_7.3-53           rappdirs_0.3.3        sf_1.0-2             
## [118] boot_1.3-26           car_3.0-10            cli_3.0.1            
## [121] quadprog_1.5-8        insight_0.14.4.1      parallel_4.0.4       
## [124] pkgconfig_2.0.3       numDeriv_2016.8-1.1   foreign_0.8-81       
## [127] sp_1.4-5              xml2_1.3.2            pbivnorm_0.6.0       
## [130] estimability_1.3      rvest_1.0.0           digest_0.6.27        
## [133] rmarkdown_2.7         cellranger_1.1.0      htmlTable_2.1.0      
## [136] curl_4.3              urca_1.3-0            quantreg_5.85        
## [139] nloptr_1.2.2.2        tseries_0.10-48       lifecycle_1.0.0      
## [142] nlme_3.1-152          jsonlite_1.7.2        carData_3.0-4        
## [145] fansi_0.4.2           pillar_1.6.0          lattice_0.20-41      
## [148] fastmap_1.1.0         httr_1.4.2            DEoptimR_1.0-8       
## [151] survival_3.2-7        xts_0.12.1            glue_1.4.2           
## [154] zip_2.1.1             png_0.1-7             performance_0.7.3.5  
## [157] class_7.3-18          stringi_1.5.3         polspline_1.1.19     
## [160] latticeExtra_0.6-29   memoise_2.0.0         e1071_1.7-9
```
