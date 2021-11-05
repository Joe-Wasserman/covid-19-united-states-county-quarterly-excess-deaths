COVID-19 United States Excess Deaths by county and quarter: Model
comparison and selection
================

<!-- /results/README.md is generated from /results/README.Rmd. Please edit that file -->

# Model comparison strategy

Several models with alternate specifications of random grouping factors
were evaluated. To select a model, they were compared in terms of:

1.  Performance on 2015-2019 training data

2.  Performance on Q1 2020 data

3.  Outlier estimates in training data

# Intraclass correlations

First, we examined the intraclass correlation coefficients for each
specification to evaluate their reasonableness.

| Var         |  Sigma |   ICC |
|:------------|-------:|------:|
| region_code | 49.275 | 0.994 |
| quarter     |  0.040 | 0.001 |
| Residual    |  0.278 | 0.006 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.843 | 0.037 |
| county_set_code | 74.225 | 0.959 |
| quarter         |  0.040 | 0.001 |
| Residual        |  0.278 | 0.004 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     | 46.443 | 0.893 |
| census_division |  5.263 | 0.101 |
| quarter         |  0.040 | 0.001 |
| Residual        |  0.278 | 0.005 |

| Var           |  Sigma |   ICC |
|:--------------|-------:|------:|
| region_code   | 47.426 | 0.912 |
| census_region |  4.266 | 0.082 |
| quarter       |  0.040 | 0.001 |
| Residual      |  0.278 | 0.005 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.846 | 0.036 |
| county_set_code | 70.185 | 0.884 |
| census_division |  6.079 | 0.077 |
| quarter         |  0.040 | 0.001 |
| Residual        |  0.278 | 0.004 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.845 | 0.036 |
| county_set_code | 71.726 | 0.904 |
| census_region   |  4.468 | 0.056 |
| quarter         |  0.040 | 0.001 |
| Residual        |  0.278 | 0.004 |

| Var         |  Sigma |   ICC |
|:------------|-------:|------:|
| region_code | 43.610 | 0.839 |
| state       |  8.037 | 0.155 |
| quarter     |  0.040 | 0.001 |
| Residual    |  0.278 | 0.005 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.847 | 0.037 |
| county_set_code | 66.024 | 0.851 |
| state           |  8.390 | 0.108 |
| quarter         |  0.040 | 0.001 |
| Residual        |  0.278 | 0.004 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     | 43.634 | 0.833 |
| state           |  5.426 | 0.104 |
| census_division |  3.015 | 0.058 |
| quarter         |  0.040 | 0.001 |
| Residual        |  0.278 | 0.005 |

| Var           |  Sigma |   ICC |
|:--------------|-------:|------:|
| region_code   | 43.627 | 0.824 |
| state         |  5.906 | 0.112 |
| census_region |  3.097 | 0.058 |
| quarter       |  0.040 | 0.001 |
| Residual      |  0.278 | 0.005 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.847 | 0.036 |
| county_set_code | 66.061 | 0.846 |
| state           |  5.899 | 0.076 |
| census_division |  2.931 | 0.038 |
| quarter         |  0.040 | 0.001 |
| Residual        |  0.278 | 0.004 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.847 | 0.036 |
| county_set_code | 66.048 | 0.842 |
| state           |  6.541 | 0.083 |
| census_region   |  2.662 | 0.034 |
| quarter         |  0.040 | 0.001 |
| Residual        |  0.278 | 0.004 |

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
      train_model = TRUE
    )
  )
```

# Performance on 2015-2019 training data

Compare model performance indices for all five models. Although many
models perform similarly for these metrics, when taken together and with
a focus on AIC and BIC, model 8 (counties nested within county sets
nested within states) and model 12 (counties nested within county sets
nested within states nested within census regions) appear to be the top
two contenders.

| Name     | Model           |   AIC | AIC_wt |   BIC | BIC_wt | R2_conditional | R2_marginal |   ICC |  RMSE | Sigma |
|:---------|:----------------|------:|-------:|------:|-------:|---------------:|------------:|------:|------:|------:|
| Model 1  | lmerModLmerTest | 78174 |  0.000 | 78244 |  0.000 |          0.995 |       0.960 | 0.887 | 0.494 | 0.509 |
| Model 2  | lmerModLmerTest | 76762 |  0.000 | 76841 |  0.000 |          0.996 |       0.941 | 0.927 | 0.494 | 0.508 |
| Model 3  | lmerModLmerTest | 78079 |  0.000 | 78157 |  0.000 |          0.995 |       0.958 | 0.890 | 0.494 | 0.509 |
| Model 4  | lmerModLmerTest | 78105 |  0.000 | 78183 |  0.000 |          0.995 |       0.958 | 0.892 | 0.494 | 0.509 |
| Model 5  | lmerModLmerTest | 76706 |  0.000 | 76793 |  0.000 |          0.996 |       0.940 | 0.928 | 0.494 | 0.508 |
| Model 6  | lmerModLmerTest | 76725 |  0.000 | 76812 |  0.000 |          0.996 |       0.939 | 0.929 | 0.494 | 0.508 |
| Model 7  | lmerModLmerTest | 77937 |  0.000 | 78015 |  0.000 |          0.995 |       0.958 | 0.889 | 0.494 | 0.509 |
| Model 8  | lmerModLmerTest | 76615 |  0.244 | 76702 |  0.962 |          0.996 |       0.941 | 0.925 | 0.494 | 0.508 |
| Model 9  | lmerModLmerTest | 77935 |  0.000 | 78022 |  0.000 |          0.995 |       0.958 | 0.890 | 0.494 | 0.509 |
| Model 10 | lmerModLmerTest | 77933 |  0.000 | 78020 |  0.000 |          0.995 |       0.958 | 0.891 | 0.494 | 0.509 |
| Model 11 | lmerModLmerTest | 76614 |  0.285 | 76710 |  0.014 |          0.996 |       0.941 | 0.926 | 0.494 | 0.508 |
| Model 12 | lmerModLmerTest | 76613 |  0.471 | 76709 |  0.024 |          0.996 |       0.941 | 0.926 | 0.494 | 0.508 |

Model Performance

# Performance on Q1 2020 data

Compare mean squared error (MSE) of model-predicted death rates against
observed death rates in Q1 2020. Because the COVID-19 pandemic only
began partway through March, 2020, we can evaluate model performance by
examining concordance of predicted and observed deaths in Q1 2020.
Models 5, 8, 11, and 12 have the lowest MSE.

| model |  mse |
|------:|-----:|
|     1 | 8318 |
|     2 | 7855 |
|     3 | 8040 |
|     4 | 8205 |
|     5 | 7817 |
|     6 | 7841 |
|     7 | 7991 |
|     8 | 7823 |
|     9 | 7967 |
|    10 | 7977 |
|    11 | 7818 |
|    12 | 7820 |

Mean Squared Error of Alternate Models

# Outlier estimates

To evaluate the extent of outlier model predictions, including
unexpectedly large changes quarter-to-quarter, time series outliers were
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
|     1 |               1 |             1 |
|     2 |               3 |            12 |
|     3 |               0 |             0 |
|     4 |               0 |             0 |
|     5 |               3 |            12 |
|     6 |               3 |            12 |
|     7 |               4 |            18 |
|     8 |               3 |            14 |
|     9 |               4 |            17 |
|    10 |               4 |            18 |
|    11 |               3 |            14 |
|    12 |               3 |            13 |

Summary of Model Outliers

    ## [[1]]

![](README_files/plot%20volatility%20output-1.png)<!-- -->

    ## 
    ## [[2]]

![](README_files/plot%20volatility%20output-2.png)<!-- -->

    ## 
    ## [[3]]
    ## NULL
    ## 
    ## [[4]]
    ## NULL
    ## 
    ## [[5]]

![](README_files/plot%20volatility%20output-3.png)<!-- -->

    ## 
    ## [[6]]

![](README_files/plot%20volatility%20output-4.png)<!-- -->

    ## 
    ## [[7]]

![](README_files/plot%20volatility%20output-5.png)<!-- -->

    ## 
    ## [[8]]

![](README_files/plot%20volatility%20output-6.png)<!-- -->

    ## 
    ## [[9]]

![](README_files/plot%20volatility%20output-7.png)<!-- -->

    ## 
    ## [[10]]

![](README_files/plot%20volatility%20output-8.png)<!-- -->

    ## 
    ## [[11]]

![](README_files/plot%20volatility%20output-9.png)<!-- -->

    ## 
    ## [[12]]

![](README_files/plot%20volatility%20output-10.png)<!-- -->

# Final model

Based on these results, model 8 was selected as the final model. In this
model, **total deaths per day** was regressed on:

-   county population (z-scored)

-   years since 2015

-   quarter of the year (fixed grouping factor)

-   county (random grouping factor nested within county set)

-   county set (random grouping factor nested within state)

-   state (random grouping factor)

## Model coefficients (fixed and random effects)

| effect   | group           | term              | estimate | std.error | statistic |      df | p.value |
|:---------|:----------------|:------------------|---------:|----------:|----------:|--------:|--------:|
| fixed    | n/a             | (Intercept)       |    2.899 |     0.104 |      27.8 |    52.4 |       0 |
| fixed    | n/a             | population_z      |    6.384 |     0.027 |     233.5 |  2532.8 |       0 |
| fixed    | n/a             | year_zero         |    0.031 |     0.002 |      18.0 | 42146.9 |       0 |
| fixed    | n/a             | quarter2          |   -0.354 |     0.007 |     -51.8 | 42023.7 |       0 |
| fixed    | n/a             | quarter3          |   -0.466 |     0.007 |     -68.1 | 42023.2 |       0 |
| fixed    | n/a             | quarter4          |   -0.229 |     0.007 |     -33.6 | 42027.9 |       0 |
| ran_pars | region_code     | sd\_\_(Intercept) |    0.388 |       n/a |       n/a |     n/a |     n/a |
| ran_pars | county_set_code | sd\_\_(Intercept) |    1.629 |       n/a |       n/a |     n/a |     n/a |
| ran_pars | state           | sd\_\_(Intercept) |    0.627 |       n/a |       n/a |     n/a |     n/a |
| ran_pars | Residual        | sd\_\_Observation |    0.508 |       n/a |       n/a |     n/a |     n/a |

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
