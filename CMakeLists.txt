# This is the main CMake file for the NCEPLIBS project.
#
# Kyle Gerheiser, Dom Heinzeller
cmake_minimum_required(VERSION 3.15)

file(STRINGS "VERSION" pVersion)

project(
  NCEPLIBS
  VERSION ${pVersion}
  # CXX isn't actually used, but need CMAKE_CXX_COMPILER in umbrella module
  LANGUAGES C CXX Fortran)

include(ExternalProject)
include(GNUInstallDirs)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/CMakeModules/Modules/")

if(NOT CMAKE_BUILD_TYPE MATCHES "^(Debug|Release|RelWithDebInfo|MinSizeRel)$")
  message(STATUS "Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE
    "Release"
    CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release"
    "MinSizeRel" "RelWithDebInfo")
endif()

# Read Branch/Tag and Version of components from this file
set(DEFAULT_LIBCOMPS ${CMAKE_CURRENT_SOURCE_DIR}/COMPONENTS)

# User options
<<<<<<< HEAD
option(OPENMP        "Enable OpenMP threading" OFF)
option(ENABLE_TESTS  "Enable testing"          OFF)
option(BUILD_CRTM    "Build CRTM library"      ON)
option(BUILD_UPP     "Build UPP library"       ON)
option(DEPLOY        "Deploy modulefiles"      OFF)
option(TCLMOD        "Create Tcl modulefiles " OFF)
option(FLAT          "Flat install structure"  ON)
=======
option(OPENMP        "Enable OpenMP threading"         OFF)
option(ENABLE_TESTS  "Enable testing"                  OFF)
option(BUILD_CRTM    "Build CRTM library"              ON)
option(BUILD_POST    "Build NCEPpost library"          ON)
option(DEPLOY        "Deploy modulefiles/shellscripts" ON)
option(FLAT          "Flat install structure"          ON)
>>>>>>> release/public-v2
option(LIBCOMPS      "File to read components from" ${DEFAULT_LIBCOMPS})
option(DOWNLOAD_ONLY "Just download the components" OFF)
option(USE_LOCAL     "Use locally downloaded components" OFF)
option(ENABLE_DOCS "Enable generation of doxygen-based documentation." OFF)

if(DOWNLOAD_ONLY AND USE_LOCAL)
  message(FATAL_ERROR "DOWNLOAD_ONLY AND USE_LOCAL CANNOT BOTH BE ON, ABORT!")
endif()

# Read list of components to install from:
if(NOT LIBCOMPS)
  set(LIBCOMPS_FILE ${DEFAULT_LIBCOMPS})
else()
  set(LIBCOMPS_FILE ${LIBCOMPS})
endif()
message(STATUS "Installing NCEPLIBS from ${LIBCOMPS_FILE}")
message(STATUS "Installing NCEPLIBS at ${CMAKE_INSTALL_PREFIX}")

# Enable CRTM if UPP library is desired.
if(BUILD_UPP)
  if(NOT BUILD_CRTM)
    message(STATUS "Enabling UPP will enable CRTM")
  endif()
  set(BUILD_CRTM ON)
endif()

# Deploy modulefile if requested
if(DEPLOY)
  message(STATUS "Installing NCEPLIBS modulefiles at ${CMAKE_INSTALL_PREFIX}/modules, NCEPLIBS shell scripts at ${CMAKE_INSTALL_PREFIX}/bin")
endif()

function(trapLocalError sourceDir)
  if(NOT EXISTS ${sourceDir})
    message(FATAL_ERROR "Directory does not exist ${sourceDir}, ABORT!")
  endif()
endfunction()

function(getInstallDir FLAT lib ver installDir)
  if(FLAT)
    set(var ${lib}-${ver})
  else()
    set(var ${lib}/${lib}-${ver})
  endif()
  set(${installDir} ${var} PARENT_SCOPE)
endfunction()

# Function to get the Branch/Tag and Version
function(getTagVer fileName libName tag ver)
  set(${tag} "develop" PARENT_SCOPE)
  execute_process(
    COMMAND cat ${fileName}
    COMMAND grep -w ${libName}
    COMMAND cut -d| -f2
    RESULT_VARIABLE _ret OUTPUT_VARIABLE _val)
  if( _ret EQUAL 0 )
    string( STRIP ${_val} _val ) # Strip out leading/trailing blanks
    set( ${tag} ${_val} PARENT_SCOPE )
  endif()
  set(${ver} "develop" PARENT_SCOPE)
  execute_process(
    COMMAND cat ${fileName}
    COMMAND grep -w ${libName}
    COMMAND cut -d| -f3
    RESULT_VARIABLE _ret OUTPUT_VARIABLE _val)
  if( _ret EQUAL 0 )
    string( STRIP ${_val} _val ) # Strip out leading/trailing blanks
    string( REPLACE "/" "-" _val ${_val} ) # replace / in names with - (dont want subdirectories)
    set( ${ver} ${_val} PARENT_SCOPE )
  endif()
endfunction()

# Collect list of components to append to CMAKE_PREFIX_PATH
list(APPEND _comps
  bacio sigio sfcio gfsio sp ip ip2 w3nco g2 g2c g2tmpl nemsio nemsiogfs landsfcutil w3emc wrf_io bufr wgrib2)

set(nceplibs ${_comps})

if(BUILD_CRTM)
  list(APPEND _comps crtm)
endif()
if(BUILD_UPP)
  list(APPEND _comps upp)
endif()

list(APPEND _cpath "${CMAKE_PREFIX_PATH}")
list(APPEND _cpath "${CMAKE_INSTALL_PREFIX}")
foreach(_comp ${_comps})
  list(APPEND _cpath "${CMAKE_INSTALL_PREFIX}/${_comp}")
endforeach()

# Create CMAKE_PREFIX_PATH list with an alternate separator
string(REPLACE ";" "|" CMAKE_PREFIX_PATH_ALT_SEP "${_cpath}")

set(nemsio_depends bacio w3nco)
set(nemsiogfs_depends nemsio)
set(w3emc_depends nemsio sigio)
set(ip2_depends sp)

if(DOWNLOAD_ONLY)
  set(CONFIGURE_ONLY "echo")
  set(BUILD_ONLY     "echo")
  set(INSTALL_ONLY   "echo")
endif()

set(wgrib2_CMAKE_ARGS "-DUSE_IPOLATES=3" "-DUSE_SPECTRAL=ON" "-DUSE_NETCDF4=ON")
set(wgrib2_depends ip2)

foreach(lib ${nceplibs})
  getTagVer("${LIBCOMPS_FILE}" "${lib}" GIT_TAG ver)
  getInstallDir(${FLAT} ${lib} ${ver} installDir)

  set(GIT_URL    "https://github.com/noaa-emc/nceplibs-${lib}")
  set(SOURCE_DIR "${CMAKE_SOURCE_DIR}/download/nceplibs-${lib}")

  if(USE_LOCAL)
    set(GIT_URL      "")
    set(GIT_TAG      "")
    trapLocalError(${SOURCE_DIR})
  endif()

  ExternalProject_Add(${lib}
    GIT_REPOSITORY "${GIT_URL}"
    GIT_TAG        "${GIT_TAG}"
    PREFIX         "${CMAKE_BINARY_DIR}/${lib}"
    SOURCE_DIR     "${SOURCE_DIR}"
    LIST_SEPARATOR |
    CMAKE_ARGS     "-DCMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH_ALT_SEP}"
                   "-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}/${installDir}"
                   "-DENABLE_TESTS=${ENABLE_TESTS}"
                   "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
                   "-DCMAKE_Fortran_COMPILER=${CMAKE_Fortran_COMPILER}"
                   "-DOPENMP=${OPENMP}"
                   ${${lib}_CMAKE_ARGS}
    DEPENDS        ${${lib}_depends}
    CONFIGURE_COMMAND ${CONFIGURE_ONLY}
    BUILD_COMMAND     ${BUILD_ONLY}
    INSTALL_COMMAND   ${INSTALL_ONLY}
    )
endforeach()

if(BUILD_CRTM)
  getTagVer("${LIBCOMPS_FILE}" "crtm" GIT_TAG ver)
  getInstallDir(${FLAT} "crtm" ${ver} installDir)

  set(GIT_URL    "https://github.com/noaa-emc/emc_crtm")
  set(SOURCE_DIR "${CMAKE_SOURCE_DIR}/download/emc_crtm")

  if(USE_LOCAL)
    set(GIT_URL      "")
    set(GIT_TAG      "")
    trapLocalError(${SOURCE_DIR})
  endif()

  ExternalProject_Add(crtm
    GIT_REPOSITORY "${GIT_URL}"
    GIT_TAG        "${GIT_TAG}"
    PREFIX         "${CMAKE_BINARY_DIR}/crtm"
    SOURCE_DIR     "${SOURCE_DIR}"
    LIST_SEPARATOR |
    CMAKE_ARGS     "-DCMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH_ALT_SEP}"
                   "-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}/${installDir}"
                   "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
                   "-DCMAKE_Fortran_COMPILER=${CMAKE_Fortran_COMPILER}"
    CONFIGURE_COMMAND ${CONFIGURE_ONLY}
    BUILD_COMMAND     ${BUILD_ONLY}
    INSTALL_COMMAND   ${INSTALL_ONLY}
    )
endif()

if(BUILD_UPP)
  getTagVer("${LIBCOMPS_FILE}" "upp" GIT_TAG ver)
  getInstallDir(${FLAT} "upp" ${ver} installDir)

  set(GIT_URL    "https://github.com/noaa-emc/emc_post")
  set(SOURCE_DIR "${CMAKE_SOURCE_DIR}/download/emc_post")

  if(USE_LOCAL)
    set(GIT_URL      "")
    set(GIT_TAG      "")
    trapLocalError(${SOURCE_DIR})
  endif()

  if(${CMAKE_Fortran_COMPILER_ID} MATCHES "^(GNU)$" AND ${CMAKE_Fortran_COMPILER_VERSION} VERSION_GREATER_EQUAL 10)
    set(EMC_POST_PATCH_COMMAND "${CMAKE_SOURCE_DIR}/emc_post_gfortran-10.sh")
  else()
    set(EMC_POST_PATCH_COMMAND "echo")
  endif()

  ExternalProject_Add(nceppost
    GIT_REPOSITORY "${GIT_URL}"
    GIT_TAG        "${GIT_TAG}"
    GIT_SUBMODULES "CMakeModules"
    PREFIX         "${CMAKE_BINARY_DIR}/upp"
    SOURCE_DIR     "${SOURCE_DIR}"
    LIST_SEPARATOR |
    CMAKE_ARGS     "-DCMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH_ALT_SEP}"
                   "-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}/${installDir}"
                   "-DOPENMP=${OPENMP}"
                   "-DBUILD_POSTEXEC=OFF"
                   "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
                   "-DCMAKE_Fortran_COMPILER=${CMAKE_Fortran_COMPILER}"
    DEPENDS        bacio w3nco w3emc g2 g2tmpl ip sp crtm
    PATCH_COMMAND     "${EMC_POST_PATCH_COMMAND}"
    CONFIGURE_COMMAND ${CONFIGURE_ONLY}
    BUILD_COMMAND     ${BUILD_ONLY}
    INSTALL_COMMAND   ${INSTALL_ONLY}
    )
endif()

if(DOWNLOAD_ONLY)
  add_custom_target(tarball
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMAND tar -czf nceplibs.tgz download)
    add_dependencies(tarball ${_comps})
endif()

if(DEPLOY)
  # Find NetCDF so that NETCDF can be added to the
  # umbrella module file and the umbrella shell scripts
  find_package(NetCDF REQUIRED COMPONENTS C Fortran)
  execute_process(COMMAND ${NetCDF_Fortran_CONFIG_EXECUTABLE} --prefix
                  OUTPUT_VARIABLE NetCDF_ROOT OUTPUT_STRIP_TRAILING_WHITESPACE)
                  message(STATUS "Found NetCDF: ${NetCDF_ROOT}")
  # Find ESMF so that ESMFMKFILE can be added to the
  # umbrella module file and the umbrella shell scripts
  find_package(ESMF REQUIRED)
  if (NOT ESMF_FOUND)
    message(FATAL_ERROR "ESMF not found, abort")
  endif()

  # Prepare to deploy
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/deploy_modulefiles.sh.in
    ${CMAKE_CURRENT_BINARY_DIR}/deploy_modulefiles.sh
    @ONLY)
  add_custom_target(prep2deploy ALL
    COMMAND chmod +x ${CMAKE_CURRENT_BINARY_DIR}/deploy_modulefiles.sh
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/deploy_modulefiles.sh)

  # Deploy modulefiles and shell scripts (if enabled), but do not add to make all (make user do it)
  add_custom_target(deploy
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/deploy_modulefiles.sh)
  add_dependencies(deploy prep2deploy)
endif()

# Determine whether or not to generate documentation.
if(ENABLE_DOCS)
  find_package(Doxygen REQUIRED)
endif()
add_subdirectory(docs)  



