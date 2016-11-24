set(Boost_FIND_QUIETLY ON)

if (${WITH_SYSTEM_BOOST} STREQUAL "ON")
  find_package(Boost ${Boost_SYSTEM_VERSION} COMPONENTS ${Boost_COMPONENTS} REQUIRED)
elseif (${WITH_SYSTEM_BOOST} STREQUAL "AUTO")
  find_package(Boost ${Boost_SYSTEM_VERSION} COMPONENTS ${Boost_COMPONENTS})
endif()

if (Boost_FOUND)
  message("-- Boost: found system version ${Boost_SYSTEM_VERSION}")
else()
  message("-- Boost: will build version ${Boost_EXTERNAL_VERSION} from source")

  string(REPLACE "." "_" Boost_VERSION_FILE "${Boost_EXTERNAL_VERSION}")
  string(REPLACE ";" "," Boost_BUILD_COMPONENTS "${Boost_COMPONENTS}")

  # FIX: ccache?
  # FIX: Boost_J
  set(toolset "")
  if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
    set(toolset "gcc")
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/user-config.jam"
      "using gcc : : \"${CMAKE_CXX_COMPILER}\" ; \n")
  else()
    message(FATAL_ERROR "Unknown compiler ${CMAKE_CXX_COMPILER_ID}.")
  endif()

  set(Boost_CFLAGS -fPIC)
  set(Boost_B2_ARGS --toolset=${toolset} --debug-configuration --buildid=ceph --variant=release --link=static --threading=multi)

  ExternalProject_Add(external_boost
    PREFIX ${EXTERNAL_ROOT}
    DOWNLOAD_DIR ${EXTERNAL_DOWNLOAD_DIR}
    URL https://sourceforge.net/projects/boost/files/boost/${Boost_EXTERNAL_VERSION}/boost_${Boost_VERSION_FILE}.tar.bz2
    URL_HASH SHA256=${Boost_EXTERNAL_SHA256}
    BUILD_IN_SOURCE 1
    PATCH_COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_BINARY_DIR}/user-config.jam" "<SOURCE_DIR>/tools/build/src/user-config.jam"
    CONFIGURE_COMMAND ./bootstrap.sh --prefix=<INSTALL_DIR> --with-libraries=${Boost_BUILD_COMPONENTS}
    BUILD_COMMAND ./b2 ${Boost_B2_ARGS} "cxxflags=${Boost_CFLAGS}" install
    INSTALL_COMMAND true
    LOG_DOWNLOAD ${EXTERNAL_LOGGING}
    LOG_PATCH ${EXTERNAL_LOGGING}
    LOG_CONFIGURE ${EXTERNAL_LOGGING}
    LOG_BUILD ${EXTERNAL_LOGGING}
    LOG_INSTALL ${EXTERNAL_LOGGING})

  # set variables similar to FindBoost
  set(Boost_FOUND 1)
  set(Boost_VERSION ${Boost_EXTERNAL_VERSION})
  set(Boost_INCLUDE_DIRS ${EXTERNAL_ROOT}/include)
  set(Boost_LIBRARY_DIRS ${EXTERNAL_ROOT}/lib)
  set(Boost_LIBRARIES)
  foreach (component ${Boost_COMPONENTS})
    string (TOUPPER ${component} upper_component)
    set(Boost_${upper_component}_FOUND 1)
    set(Boost_${upper_component}_LIBRARY boost_${component})

    add_library(boost_${component} STATIC IMPORTED)
    add_dependencies(boost_${component} external_boost)
    set_property(TARGET boost_${component} PROPERTY IMPORTED_LOCATION "${EXTERNAL_ROOT}/lib/libboost_${component}-ceph.a")

    list(APPEND Boost_LIBRARIES ${Boost_${upper_component}_LIBRARY})

  endforeach()

  # iostreams must be linked with zlib
  list(APPEND Boost_LIBRARIES "-lz")

endif()

message("-- Boost: Boost_INCLUDE_DIRS = ${Boost_INCLUDE_DIRS}")
message("-- Boost: Boost_LIBRARY_DIRS = ${Boost_LIBRARY_DIRS}")
message("-- Boost: Boost_LIBRARIES = ${Boost_LIBRARIES}")
