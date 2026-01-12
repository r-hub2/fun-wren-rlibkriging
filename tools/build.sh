#!/usr/bin/env bash
set -eo pipefail

if [[ "$DEBUG_CI" == "true" ]]; then
  set -x
fi


# Setup used/unused bindings
export ENABLE_R_BINDING=ON
export ENABLE_OCTAVE_BINDING=OFF
export ENABLE_MATLAB_BINDING=OFF
export ENABLE_PYTHON_BINDING=OFF

export MAKE_SHARED_LIBS=off
export STATIC_LIB=on

: ${R_HOME=$(R RHOME)}
if test -z "${R_HOME}"; then
   as_fn_error $? "Could not determine R_HOME." "$LINENO" 5
fi

# Static libKriging build (using libK/.ci)
cd src/libK
CI=`ls -a | grep travis-ci`
echo "CI: "$CI

{
$CI/common/before_script.sh
} || {
echo "!!! Failed checking configuration !!!"
}

export CC=`${R_HOME}/bin/R CMD config CC`
export CXX=`${R_HOME}/bin/R CMD config CXX`
export FC=`${R_HOME}/bin/R CMD config FC`

# R workflow requires to use R cmd with full path.
# These declarations help to skip declaration without full path in libKriging build scripts.
export CMAKE_Fortran_COMPILER="$(${R_HOME}/bin/R CMD config FC | awk '{ print $1 }')"
export Fortran_LINK_FLAGS="$(${R_HOME}/bin/R CMD config FLIBS)"

if [ "$_R_CHECK_CRAN_INCOMING_" != "FALSE" ]; then
  # enable Rcout & Rcerr:
  # Get RcppArma include - use shortPathName on Windows to avoid spaces
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
      # Use shortPathName to avoid spaces, then convert to forward slashes
      export RCPP_INCLUDE_PATH=$(${R_HOME}/bin/Rscript --vanilla -e "cat(gsub('\\\\\\\\', '/', shortPathName(file.path(system.file(package='Rcpp'),'include'))))")
      export R_INCLUDE_PATH=$(${R_HOME}/bin/Rscript --vanilla -e "cat(gsub('\\\\\\\\', '/', shortPathName(R.home('include'))))")
      ;;
    *)
      export RCPP_INCLUDE_PATH="$(${R_HOME}/bin/Rscript -e 'invisible(write(system.file(package="Rcpp"),stdout()))')"/include
      export R_INCLUDE_PATH="$(${R_HOME}/bin/Rscript -e 'invisible(write(R.home("include"),stdout()))')"
      ;;
  esac
  echo "build: Rcpp include path ${RCPP_INCLUDE_PATH}"
  echo "build: R include path ${R_INCLUDE_PATH}"
  sed -i.bak -e "s|enable_language(CXX)|enable_language(CXX)\nfile(TO_CMAKE_PATH \"\${RCPP_INCLUDE_PATH}\" RCPP_INCLUDE_PATH)\nfile(TO_CMAKE_PATH \"\${R_INCLUDE_PATH}\" R_INCLUDE_PATH)\ninclude_directories(\"\${RCPP_INCLUDE_PATH}\" \"\${R_INCLUDE_PATH}\")\nmessage(STATUS \"Rcpp include path \${RCPP_INCLUDE_PATH}\")\nmessage(STATUS \"R include path \${R_INCLUDE_PATH}\")|g" \
     CMakeLists.txt
  rm -rf CMakeLists.txt.bak
  EXTRA_CMAKE_OPTIONS="-DRCPP_INCLUDE_PATH=${RCPP_INCLUDE_PATH} -DR_INCLUDE_PATH=${R_INCLUDE_PATH} ${EXTRA_CMAKE_OPTIONS}"
fi

BUILD_TEST=false \
MODE=Release \
EXTRA_CMAKE_OPTIONS="${EXTRA_CMAKE_OPTIONS:-} -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_SHARED_LIBS=${MAKE_SHARED_LIBS} -DSTATIC_LIB=${STATIC_LIB} -DEXTRA_SYSTEM_LIBRARY_PATH=${EXTRA_SYSTEM_LIBRARY_PATH}" \
$CI/linux-macos/build.sh # should support '.travis-ci' or 'travis-ci'"

rm -rf ../../inst
mkdir -p ../../inst
mv build/installed/lib ../../inst/.
mv build/installed/share ../../inst/.
mv build/installed/include ../../inst/.

cd ../..

# update doc
#R -e "roxygen2::roxygenise(package.dir = '.')" # No: it will loop on install, because roxygen2 requires loading package...
# update Rccp links
${R_HOME}/bin/R -e "Rcpp::compileAttributes(pkgdir = '.', verbose = TRUE)"

# Convert CRLF to LF in generated files (CMake and Rcpp generate CRLF on Windows)
if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]]; then
  # Convert in build directory
  find src/libK/build -type f \( -name 'Makefile*' -o -name '*.c' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) -exec sed -i $'s/\r$//' {} + 2>/dev/null || true
  # Convert Rcpp-generated files
  find src -maxdepth 1 -type f \( -name '*.cpp' -o -name '*.h' \) -exec sed -i $'s/\r$//' {} + 2>/dev/null || true
  find R -maxdepth 1 -type f -name 'RcppExports.R' -exec sed -i $'s/\r$//' {} + 2>/dev/null || true
fi
