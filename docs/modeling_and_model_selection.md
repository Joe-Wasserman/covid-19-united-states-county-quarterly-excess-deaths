COVID-19 United States Excess Deaths by county and quarter: Model
comparison and selection
================

<!-- modeling_and_model_selection.md is generated from modeling_and_model_selection.Rmd. Please edit that file -->

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
| region_code | 51.206 | 0.973 |
| quarter     |  0.027 | 0.001 |
| Residual    |  1.393 | 0.026 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.792 | 0.033 |
| county_set_code | 80.906 | 0.951 |
| quarter         |  0.027 | 0.000 |
| Residual        |  1.392 | 0.016 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     | 48.363 | 0.879 |
| census_division |  5.259 | 0.096 |
| quarter         |  0.027 | 0.000 |
| Residual        |  1.393 | 0.025 |

| Var           |  Sigma |   ICC |
|:--------------|-------:|------:|
| region_code   | 49.428 | 0.896 |
| census_region |  4.329 | 0.078 |
| quarter       |  0.027 | 0.000 |
| Residual      |  1.393 | 0.025 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.794 | 0.032 |
| county_set_code | 76.643 | 0.879 |
| census_division |  6.358 | 0.073 |
| quarter         |  0.027 | 0.000 |
| Residual        |  1.392 | 0.016 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.793 | 0.032 |
| county_set_code | 78.246 | 0.897 |
| census_region   |  4.770 | 0.055 |
| quarter         |  0.027 | 0.000 |
| Residual        |  1.392 | 0.016 |

| Var         |  Sigma |   ICC |
|:------------|-------:|------:|
| region_code | 45.293 | 0.818 |
| state       |  8.688 | 0.157 |
| quarter     |  0.027 | 0.000 |
| Residual    |  1.393 | 0.025 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.796 | 0.033 |
| county_set_code | 72.095 | 0.845 |
| state           |  9.051 | 0.106 |
| quarter         |  0.027 | 0.000 |
| Residual        |  1.392 | 0.016 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     | 45.313 | 0.812 |
| state           |  6.075 | 0.109 |
| census_division |  3.009 | 0.054 |
| quarter         |  0.027 | 0.000 |
| Residual        |  1.393 | 0.025 |

| Var           |  Sigma |   ICC |
|:--------------|-------:|------:|
| region_code   | 45.306 | 0.802 |
| state         |  6.538 | 0.116 |
| census_region |  3.216 | 0.057 |
| quarter       |  0.027 | 0.000 |
| Residual      |  1.393 | 0.025 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.796 | 0.033 |
| county_set_code | 72.132 | 0.841 |
| state           |  6.462 | 0.075 |
| census_division |  3.006 | 0.035 |
| quarter         |  0.027 | 0.000 |
| Residual        |  1.392 | 0.016 |

| Var             |  Sigma |   ICC |
|:----------------|-------:|------:|
| region_code     |  2.796 | 0.032 |
| county_set_code | 72.123 | 0.836 |
| state           |  7.080 | 0.082 |
| census_region   |  2.835 | 0.033 |
| quarter         |  0.027 | 0.000 |
| Residual        |  1.392 | 0.016 |

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
      calculate = TRUE,
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
Models 5, 7, 8, 11, and 12 have the lowest MSE.

| model |   mse |
|------:|------:|
|     1 | 10458 |
|     2 | 10385 |
|     3 | 10416 |
|     4 | 10444 |
|     5 | 10379 |
|     6 | 10380 |
|     7 | 10396 |
|     8 | 10379 |
|     9 | 10392 |
|    10 | 10394 |
|    11 | 10379 |
|    12 | 10379 |

Mean Squared Error of Alternate Models

# Outlier estimates

To evaluate the extent of outlier model predictions, including
unexpectedly large changes quarter-to-quarter, time series outliers were
identified using `tsoutliers()` from the
{[forecast](https://cran.r-project.org/package=forecast)} R package.
Using this method, no models had any county-quarter outliers.

| model | outlier_regions | outlier_total |
|------:|----------------:|--------------:|
|     1 |               0 |             0 |
|     2 |               0 |             0 |
|     3 |               0 |             0 |
|     4 |               0 |             0 |
|     5 |               0 |             0 |
|     6 |               0 |             0 |
|     7 |               0 |             0 |
|     8 |               0 |             0 |
|     9 |               0 |             0 |
|    10 |               0 |             0 |
|    11 |               0 |             0 |
|    12 |               0 |             0 |

Summary of Model Outliers

<!-- ```{r plot-volatility} -->
<!-- ```  -->
<!-- ```{r plot volatility output, include=TRUE, error=FALSE} -->
<!-- try(fitted_outlier_plots %>%  -->
<!--   walk(print)) -->
<!-- ``` -->

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
| fixed    | n/a             | (Intercept)       |    2.897 |     0.104 |      27.8 |    52.4 |       0 |
| fixed    | n/a             | population_z      |    6.381 |     0.027 |     233.5 |  2532.8 |       0 |
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
##  [1] knitr_1.31        lme4_1.1-26       Matrix_1.3-2      aweek_1.0.2      
##  [5] lubridate_1.7.10  data.table_1.14.0 tidycensus_0.11.4 furrr_0.2.2      
##  [9] future_1.21.0     forcats_0.5.1     stringr_1.4.0     dplyr_1.0.5      
## [13] purrr_0.3.4       readr_2.0.2       tidyr_1.1.3       tibble_3.1.0     
## [17] ggplot2_3.3.5     tidyverse_1.3.1  
## 
## loaded via a namespace (and not attached):
##   [1] utf8_1.2.1            rms_6.2-0             tidyselect_1.1.0     
##   [4] htmlwidgets_1.5.3     grid_4.0.4            maptools_1.1-1       
##   [7] munsell_0.5.0         codetools_0.2-18      units_0.7-2          
##  [10] statmod_1.4.35        withr_2.4.2           colorspace_2.0-0     
##  [13] highr_0.8             uuid_0.1-4            rstudioapi_0.13      
##  [16] stats4_4.0.4          robustbase_0.93-7     ggsignif_0.6.1       
##  [19] TTR_0.24.2            listenv_0.8.0         emmeans_1.5.5-1      
##  [22] mnormt_2.0.2          rprojroot_2.0.2       coda_0.19-4          
##  [25] parallelly_1.24.0     vctrs_0.3.7           generics_0.1.0       
##  [28] TH.data_1.0-10        xfun_0.26             ggthemes_4.2.4       
##  [31] R6_2.5.0              VGAM_1.1-5            cachem_1.0.4         
##  [34] assertthat_0.2.1      scales_1.1.1          forecast_8.15        
##  [37] multcomp_1.4-16       nnet_7.3-15           gtable_0.3.0         
##  [40] multcompView_0.1-8    globals_0.14.0        conquer_1.0.2        
##  [43] sandwich_3.0-0        timeDate_3043.102     rlang_0.4.10         
##  [46] MatrixModels_0.5-0    splines_4.0.4         rstatix_0.7.0        
##  [49] rgdal_1.5-23          TMB_1.7.20            broom_0.7.6          
##  [52] checkmate_2.0.0       reshape2_1.4.4        yaml_2.2.1           
##  [55] abind_1.4-5           modelr_0.1.8          backports_1.2.1      
##  [58] quantmod_0.4.18       Hmisc_4.5-0           tools_4.0.4          
##  [61] psych_2.1.3           lavaan_0.6-8          ellipsis_0.3.1       
##  [64] RColorBrewer_1.1-2    proxy_0.4-26          extraoperators_0.1.1 
##  [67] tigris_1.5            Rcpp_1.0.7            plyr_1.8.6           
##  [70] base64enc_0.1-3       classInt_0.4-3        ggpubr_0.4.0         
##  [73] rpart_4.1-15          fracdiff_1.5-1        cowplot_1.1.1        
##  [76] zoo_1.8-9             haven_2.3.1           cluster_2.1.0        
##  [79] fs_1.5.0              here_1.0.1            magrittr_2.0.1       
##  [82] openxlsx_4.2.3        lmerTest_3.1-3        SparseM_1.81         
##  [85] lmtest_0.9-38         reprex_2.0.0          tmvnsim_1.0-2        
##  [88] mvtnorm_1.1-1         matrixStats_0.58.0    hms_1.0.0            
##  [91] evaluate_0.14         xtable_1.8-4          rio_0.5.26           
##  [94] jpeg_0.1-8.1          JWileymisc_1.2.0      broom.mixed_0.2.6    
##  [97] readxl_1.3.1          gridExtra_2.3         compiler_4.0.4       
## [100] mice_3.13.0           KernSmooth_2.23-18    V8_3.4.0             
## [103] crayon_1.4.1          minqa_1.2.4           htmltools_0.5.1.1    
## [106] mgcv_1.8-33           tzdb_0.1.2            multilevelTools_0.1.1
## [109] Formula_1.2-4         rdocsyntax_0.4.1.9000 DBI_1.1.1            
## [112] dbplyr_2.1.1          MASS_7.3-53           rappdirs_0.3.3       
## [115] sf_1.0-2              boot_1.3-26           car_3.0-10           
## [118] cli_2.5.0             quadprog_1.5-8        insight_0.14.4.1     
## [121] parallel_4.0.4        pkgconfig_2.0.3       numDeriv_2016.8-1.1  
## [124] foreign_0.8-81        sp_1.4-5              xml2_1.3.2           
## [127] pbivnorm_0.6.0        estimability_1.3      rvest_1.0.0          
## [130] digest_0.6.27         rmarkdown_2.7         cellranger_1.1.0     
## [133] htmlTable_2.1.0       curl_4.3              urca_1.3-0           
## [136] quantreg_5.85         nloptr_1.2.2.2        tseries_0.10-48      
## [139] lifecycle_1.0.0       nlme_3.1-152          jsonlite_1.7.2       
## [142] carData_3.0-4         fansi_0.4.2           pillar_1.6.0         
## [145] lattice_0.20-41       fastmap_1.1.0         httr_1.4.2           
## [148] DEoptimR_1.0-8        survival_3.2-7        xts_0.12.1           
## [151] glue_1.4.2            zip_2.1.1             png_0.1-7            
## [154] performance_0.7.3.5   class_7.3-18          stringi_1.5.3        
## [157] polspline_1.1.19      latticeExtra_0.6-29   memoise_2.0.0        
## [160] e1071_1.7-9
```
