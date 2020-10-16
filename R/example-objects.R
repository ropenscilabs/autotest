#' Get all objects constructed in all example code of one package
#'
#' @param package Either locally installed package or path to local source
#' @param run_donttest Exactly as for `pkgload::run_example`, and passed through
#' to `tools::Rd2ex`
#' @param run_dontrun ... same ...
#' @return List of all objects constructed in all examples, along with
#' associated packages and functions or classes from or by which those objects
#' are defined.
#' @noRd
get_example_objs <- function (package,
                              run_donttest = FALSE,
                              run_dontrun = FALSE) {

    pkg_name <- get_package_name (package)
    if (pkg_is_source (package)) {
        if (!paste0 ("package:", pkg_name) %in% search ())
            devtools::load_all (package, export_all = FALSE)

        flist <- list.files (file.path (package, "man"),
                             pattern = "\\.Rd$",
                             full.names = TRUE)
    } else {
        flist <- tools::Rd_db (package)
    }

    suppressWarnings (
        objs <- lapply (flist, function (i)
                        example_objects (i, run_dontrun, run_donttest))
        )
    objs <- unique (unlist (objs))

    exclude_these <- c ("gg", "ggplot")
    objs <- objs [which (!objs %in% exclude_these)]
    if (length (objs) == 0) {
        objs <- NULL
    } else {
        obj_pkgs <- param_desc_is_other_fn (package, objs)
        names (objs) <- obj_pkgs
    }

    return (objs)
}

#' Get objects from one single `.Rd` file
#'
#' @param f One Rd file
#' @noRd
example_objects <- function (f,
                             run_donttest = FALSE,
                             run_dontrun = FALSE) {

    tmp <- tempfile (fileext = ".R")
    utils::capture.output (tools::Rd2ex (f,
                                         out = tmp,
                                         commentDontrun = !run_dontrun,
                                         commentDonttest = !run_donttest))
    if (!file.exists (tmp)) # no example
        return (NULL)

    env <- new.env (parent = globalenv ())
    utils::capture.output (
        ret <- source (tmp, echo = FALSE, local = env, max.deparse.length = Inf)
    )
    o1 <- class (ret$value)
    o2 <- unlist (lapply (ls (envir = env), function (i) class (get (i, envir = env))))
    ret <- unique (c (o1, o2))

    # List given in ?typeof, but noting that they need to be be transformed
    # because, for example, typeof(2.) is "double", yet class(2.) is "numeric".
    simple_types <- c ("logical", "integer", "double", "complex", "character",
                       "raw", "list") # plus "NULL", "closeure", "special", "builtin")
    simple_types <- vapply (simple_types, function (s)
                            class (do.call (paste0 ("as.", s), list (1))),
                            character (1), USE.NAMES = FALSE)
    simple_types <- c (simple_types, "NULL", "closeure", "special", "builtin")
    ret <- ret [!ret %in% simple_types]

    if (length (ret) == 0)
        ret <- NULL

    return (ret)
}