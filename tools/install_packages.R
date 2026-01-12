#!/usr/bin/env Rscript

packages = commandArgs(trailingOnly=TRUE)

if (.Platform$OS.type=="windows")
    options(pkgType = "win.binary") # Prefer windows binary if available (even if not latest version)

# On macOS, try to use binary packages when available
if (Sys.info()["sysname"] == "Darwin") {
    options(pkgType = "both") # Try binary first, then source
}

for (lib in packages) {

    cat(paste0("Installing package: ", lib, "\n"))
    
    # Try to install the package
    install.packages(lib, repos='https://cloud.r-project.org')

    # Verify installation
    if ( ! library(lib, character.only=TRUE, logical.return=TRUE) ) {
        cat(paste0("\n#########################\nCannot install ", lib, "\n"))
        cat(paste0("System info: ", Sys.info()["sysname"], " ", Sys.info()["release"], "\n"))
        cat(paste0("R version: ", R.version.string, "\n"))
        cat("#########################\n\n")
        quit(status=1, save='no')
    } else {
        cat(paste0("Successfully installed and loaded: ", lib, " (version ", packageVersion(lib), ")\n\n"))
    }
}
