# library(roxygen2)
# roxygenise('C:/src/github_jm/config-utils/R/packages/msvs')

#' @export
get_location <- function() {
    find.package('msvs')
}

apply_dirsep <- function(x, dirsep='/') {
    # We use string replacement to allow for multipls backslashes that is required in 
    # character replacement in Makefile template files
    # return (normalizePath( x, winslash=dirsep, mustWork=FALSE))
    # x <- "c:/src/csiro\\blah\\blah"
    x <- stringr::str_replace_all(x, '/', dirsep)
    x <- stringr::str_replace_all(x, '\\\\', dirsep)
    return(x)
}

get_path_from_env <- function(envvarname, dirsep='/', do_cat=TRUE) {
# LIB_PATH_UNIX=`cmd /c .\\\\src\\\\get_libpath.cmd`
    env <- Sys.getenv(envvarname)
    if (env == '') {stop(paste0('environment variable not found: ', envvarname))}
    x <- apply_dirsep( env, dirsep )
    do_cat_if(x, do_cat=do_cat)
}

do_cat_if <- function(x, do_cat=TRUE) {
    if(do_cat) {cat(x)}
    else { return(x) }
}

#' @export
get_library_path <- function(dirsep='/', do_cat=TRUE) {
# LIB_PATH_UNIX=`cmd /c .\\\\src\\\\get_libpath.cmd`
    return(get_path_from_env(envvarname = 'LIBRARY_PATH', dirsep=dirsep, do_cat=do_cat))
}

#' @export
get_include_path <- function(dirsep='/', do_cat=TRUE) {
# INCL_PATH_UNIX=`cmd /c .\\\\src\\\\get_includepath.cmd`
    return(get_path_from_env(envvarname = 'INCLUDE_PATH', dirsep=dirsep, do_cat=do_cat))
}

#' @export
get_configure_win_part <- function(dirsep='/', do_cat=TRUE) {
    x <- file.path(get_location(), 'exec', 'configure.win.part')
    x <- apply_dirsep( x, dirsep )
    do_cat_if(x, do_cat=do_cat)
}

#' @export
get_win_cp_cmd <- function(dirsep='/', do_cat=TRUE) {
    x <- file.path(get_location(), 'exec', 'win_cp.cmd')
    x <- apply_dirsep( x, dirsep )
    do_cat_if(x, do_cat=do_cat)
}

#' @export
get_makefile_win_template <- function(dirsep='/', do_cat=TRUE) {
    x <- file.path(get_location(), 'templates', 'Makefile.win.in')
    x <- apply_dirsep( x, dirsep )
    do_cat_if(x, do_cat=do_cat)
}

#' @export
get_makevars_win_template <- function(dirsep='/', do_cat=TRUE) {
    x <- file.path(get_location(), 'templates', 'Makevars.win.in')
    x <- apply_dirsep( x, dirsep )
    do_cat_if(x, do_cat=do_cat)
}

#' @export
get_msbuild_exe_path <- function(dirsep='/', do_cat=TRUE) {
    x <- file.path(msvs:::get_location(), 'exec', 'get_msbuildpath.cmd')
    if(!file.exists(x)) {stop('script to find msbuild was not found')}
    msbuild_exe <- system(x, intern=TRUE)
    if(!file.exists(msbuild_exe)) {stop(paste0('File does not exist: ', msbuild_exe))}
    do_cat_if(msbuild_exe, do_cat=do_cat)
}

# template <- 'C:/src/github_jm/config-utils/R/packages/msvs/inst/templates/Makefile.win.in'
# replacements <- list('blah')
# names(replacements) <- 
# '@SOLUTION_FILE_NAME@'
#     )

lreplace <- function(x, replacements) {
    stopifnot(is.list(replacements))
    tags <- names(replacements)
    for (f in tags) {
        x <- stringr::str_replace_all(x, f, replacements[[f]])
    }
    x
}

create_file_from_template <- function(template,out_file, replacements) {
    if(!file.exists(template)) {stop(paste0('Template file does not exist: ', template))}
    x <- readLines(con=template)
    x <- lreplace(x, replacements)
    writeLines(x, con=out_file)
}

#' @export
create_makefile_from_template <- function(template,out_file, solution_filename, from_dll_filenoext, to_dll_filenoext, msbuild_exe_path) {
    if(!file.exists(template)) {stop(paste0('Template file does not exist: ', template))}
    # SLN=@SOLUTION_FILE_NAME@
    # MYLIB_MS=@BUILD_OUTPUT_FILENAME_NOEXT@
    # MYLIB_FN=@TARGET_OUTPUT_FILENAME_NOEXT@
    # MSB=@MSBUILD_EXE_PATH@
    wincp <- get_win_cp_cmd(dirsep='\\\\\\\\', do_cat=FALSE)
    replacements <- list(solution_filename,
        from_dll_filenoext,
        to_dll_filenoext,
        msbuild_exe_path, 
        paste0('cmd /c ', wincp))
    # replacements <- as.list(letters[1:4])
    names(replacements) <- c(
        '@SOLUTION_FILE_NAME@', 
        '@BUILD_OUTPUT_FILENAME_NOEXT@',
        '@TARGET_OUTPUT_FILENAME_NOEXT@',
        '@MSBUILD_EXE_PATH@',
        '@ROBOCP_CMD@')
    create_file_from_template(template,out_file, replacements) 
}

#' @export
create_makevars_from_template <- function(template,out_file, local_libs_args,local_include_args) {
    if(!file.exists(template)) {stop(paste0('Template file does not exist: ', template))}
    # LOCAL_LIBS_ARGS=@LOCAL_LIBS_ARGS@
    # LOCAL_INCLUDES_ARGS=@LOCAL_INCLUDES_ARGS@
    replacements <- list(local_libs_args,local_include_args)
    names(replacements) <- c(
        '@LOCAL_LIBS_ARGS@', 
        '@LOCAL_INCLUDES_ARGS@')
    create_file_from_template(template,out_file, replacements) 
}


#' @export
custom_install_shlib <- function(files, srclibname='swift_r', shlib_ext, r_arch, r_package_dir, windows, group.writable=FALSE) {

  ## This package needs to rename swift.so to swift_r.so. This is not easy to do so at compilation time, 
  ## as the name of the package seems hard-wired to be used for the shared library. 
  ## A custom Makefile would overcome this (?) but this is a pain. Instead, we use the possibility to use a custom install.libs.r file. 
  ## shlib_install <- function(instdir, arch) in file install.R in the standard R package tools of the R distribution.
  ## See also 1.1.5 Package subdirectories in the manual "Writing R Extensions"

  ## We largely use the default behavior of shlib_install

  #files <- Sys.glob(paste0("*", shlib_ext))

  if (length(files)) {

    # if (!windows) {
      if (length(files) != 1) stop (paste("Custom library deployment on non-windows; expecting only one matching file for glob *", shlib_ext))
      extension <- tools::file_ext(shlib_ext)
      MYSHLIB_EXT <- paste0(srclibname, '.', extension)
    # }
    arch <- r_arch
    instdir <- r_package_dir
    if(group.writable) { ## group-write modes if requested:
      fmode <- "664"
      dmode <- "775"
    } else {
      fmode <- "644"
      dmode <- "755"
    }

    libarch <- if (nzchar(arch)) paste0("libs", arch) else "libs"
    dest_dir <- file.path(instdir, libarch)
    message('installing to ', dest_dir, domain = NA)
    dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
    # if (!windows) {
      file.copy(files[1], file.path(dest_dir, MYSHLIB_EXT), overwrite = TRUE)
    # } else {
      # file.copy(files, dest_dir, overwrite = TRUE)
    # }
    ## not clear if this is still necessary, but sh version did so
    if (!windows)
        Sys.chmod(file.path(dest_dir, files), dmode)

    ## OS X NOT YET TESTED
    if (grepl("^darwin", R.version$os)) {
      stop('custom_install_shlib not tested on Apple stuff')
    }
    ## OS X does not keep debugging symbols in binaries
    ## anymore so optionally we can create dSYMs. This is
    ## important since we will blow away .o files so there
    ## is no way to create it later.

    # if (grepl("^darwin", R.version$os) && dsym) {
    #     message(gettextf("generating debug symbols (%s)", "dSYM"),
    #       domain = NA)
    #     dylib <- Sys.glob(paste0(dest_dir, "/*", MYSHLIB_EXT))
    #     for (file in dylib) system(paste0("dsymutil ", file))
    # }

    #if(config_val_to_logical(Sys.getenv("_R_SHLIB_BUILD_OBJECTS_SYMBOL_TABLES_",
  #			                    "TRUE"))
    if(as.logical(Sys.getenv("_R_SHLIB_BUILD_OBJECTS_SYMBOL_TABLES_",'TRUE'))
      && file_test("-f", "symbols.rds")) {
        file.copy("symbols.rds", dest_dir)
    }
  }
}