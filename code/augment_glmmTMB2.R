augment.glmmTMB2 <- function (x, data = stats::model.frame(x), newdata = NULL, type, type.predict = type,
          type.residuals = type, se.fit = FALSE, ...)
{
  notNAs <- function(o) {
    if (is.null(o) || all(is.na(o)))
      NULL
    else o
  }
  residuals0 <- purrr::possibly(stats::residuals, NULL)
  influence0 <- purrr::possibly(stats::influence, NULL)
  cooks.distance0 <- purrr::possibly(stats::cooks.distance,
                                     NULL)
  rstandard0 <- purrr::possibly(stats::rstandard, NULL)
  predict0 <- purrr::possibly(stats::predict, NULL)
  args <- list(x)
  if (!is.null(newdata)) {
    args$newdata <- newdata
  }
  if (!missing(type.predict)) {
    args$type <- type.predict
  }
  args$se.fit <- se.fit
  args <- c(args, list(...))
  if ("panelmodel" %in% class(x)) {
    pred <- model.frame(x)[, 1] - residuals(x)
  }
  else {
    # pred <- suppressWarnings(do.call(predict0, args))
    pred <- do.call(predict0, args)
  }
  if (is.null(pred)) {
    pred <- do.call(stats::fitted, args)
  }
  if (is.list(pred)) {
    ret <- data.frame(.fitted = as.vector(pred$fit))
    ret$.se.fit <- as.vector(pred$se.fit)
  }
  else {
    ret <- data.frame(.fitted = as.vector(pred))
  }
  na_action <- if (isS4(x)) {
    attr(stats::model.frame(x), "na.action")
  }
  else {
    stats::na.action(x)
  }
  if (missing(newdata) || is.null(newdata)) {
    if (!missing(type.residuals)) {
      ret$.resid <- residuals0(x, type = type.residuals)
    }
    else {
      ret$.resid <- residuals0(x)
    }
    infl <- influence0(x, do.coef = FALSE)
    if (!is.null(infl)) {
      if (inherits(x, "gam")) {
        ret$.hat <- infl
        ret$.sigma <- NA
      }
      else {
        zero_weights <- "weights" %in% names(x) &&
          any(zero_weight_inds <- abs(x$weights) < .Machine$double.eps^0.5)
        if (zero_weights) {
          ret[c(".hat", ".sigma")] <- 0
          ret$.hat[!zero_weight_inds] <- infl$hat
          ret$.sigma[!zero_weight_inds] <- infl$sigma
        }
        else {
          ret$.hat <- infl$hat
          ret$.sigma <- infl$sigma
        }
      }
    }
    ret$.cooksd <- notNAs(cooks.distance0(x))
    ret$.std.resid <- notNAs(rstandard0(x))
    original <- data
    if (class(na_action) == "exclude") {
      if (length(stats::residuals(x)) > nrow(data)) {
        warning("When fitting with na.exclude, rows with NA in ",
                "original data will be dropped unless those rows are provided ",
                "in 'data' argument")
      }
    }
  }
  else {
    original <- newdata
  }
  if (is.null(na_action) || nrow(original) == nrow(ret)) {
    original <- broom:::as_augment_tibble(original)
    return(as_tibble(cbind(original, ret)))
  }
  else if (class(na_action) == "omit") {
    original <- as_augment_tibble(original)
    original <- original[-na_action, ]
    return(as_tibble(cbind(original, ret)))
  }
  ret$.rownames <- rownames(ret)
  original$.rownames <- rownames(original)
  ret <- merge(original, ret, by = ".rownames")
  ret <- ret[order(match(ret$.rownames, rownames(original))),
             ]
  rownames(ret) <- NULL
  if (all(ret$.rownames == seq_along(ret$.rownames))) {
    ret$.rownames <- NULL
  }
  as_tibble(ret)
}
