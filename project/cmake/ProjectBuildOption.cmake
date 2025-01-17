include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/FetchToolset.cmake")

include("${ATFRAMEWORK_CMAKE_TOOLSET_DIR}/Import.cmake")
include(IncludeDirectoryRecurse)
include(EchoWithColor)

# generate check header
if(CMAKE_VERSION VERSION_LESS "3.20.0")
  include(WriteCompilerDetectionHeader)
  write_compiler_detection_header(
    FILE "${PROJECT_ATFRAME_UTILS_INCLUDE_DIR}/config/compiler_features.h" PREFIX UTIL_CONFIG
    COMPILERS GNU Clang AppleClang MSVC
    FEATURES c_std_90
             c_std_99
             c_std_11
             c_restrict
             c_static_assert
             c_variadic_macros
             cxx_std_98
             cxx_std_11
             cxx_std_14
             cxx_std_17
             cxx_std_20
             cxx_alias_templates
             cxx_attributes
             cxx_attribute_deprecated
             cxx_auto_type
             cxx_constexpr
             cxx_decltype
             cxx_decltype_auto
             cxx_default_function_template_args
             cxx_defaulted_functions
             cxx_delegating_constructors
             cxx_deleted_functions
             cxx_final
             cxx_generic_lambdas
             cxx_inheriting_constructors
             cxx_lambdas
             cxx_long_long_type
             cxx_noexcept
             cxx_nonstatic_member_init
             cxx_nullptr
             cxx_override
             cxx_range_for
             cxx_raw_string_literals
             cxx_relaxed_constexpr
             cxx_return_type_deduction
             cxx_rvalue_references
             cxx_sizeof_member
             cxx_static_assert
             cxx_thread_local
             cxx_variadic_templates)
endif()
# file(MAKE_DIRECTORY "${PROJECT_ATFRAME_UTILS_INCLUDE_DIR}/config") file(RENAME
# "${CMAKE_BINARY_DIR}/compiler_features.h" "${PROJECT_ATFRAME_UTILS_INCLUDE_DIR}/config/compiler_features.h")

# 默认配置选项
# ######################################################################################################################
option(LIBUNWIND_ENABLED "Enable using libunwind." OFF)
option(LOG_WRAPPER_ENABLE_LUA_SUPPORT "Enable lua support." ON)
option(LOG_WRAPPER_CHECK_LUA "Check lua support." ON)
set(LOG_WRAPPER_MAX_SIZE_PER_LINE
    "2097152"
    CACHE STRING "Max size in one log line.")
set(LOG_WRAPPER_CATEGORIZE_SIZE
    "16"
    CACHE STRING "Default log categorize number.")
option(ENABLE_NETWORK "Enable network support." ON)

# Check pthread
find_package(Threads)
if(CMAKE_USE_PTHREADS_INIT)
  set(THREAD_TLS_USE_PTHREAD 1)
  if(THREADS_PREFER_PTHREAD_FLAG)
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_DEFINITIONS ${THREADS_PREFER_PTHREAD_FLAG})
  endif()
endif()

# Check mkstemp/_mktemp/_mktemp_s for file system
include(CheckCXXSourceCompiles)
include(CheckCSourceCompiles)

if(WIN32)
  check_cxx_source_compiles(
    "
    #include <io.h>
    #include <stdio.h>
    int main() {
        char buffer[32] = \"abcdefgXXXXXX\";
        const char* f = _mktemp(buffer);
        puts(f);
        return 0;
    }
    "
    LIBATFRAME_UTILS_TEST_WINDOWS_MKTEMP)
  if(LIBATFRAME_UTILS_TEST_WINDOWS_MKTEMP)
    set(LIBATFRAME_UTILS_ENABLE_WINDOWS_MKTEMP TRUE)
  endif()
else()
  check_c_source_compiles(
    "
    #include <stdlib.h>
    #include <stdio.h>
    #include <unistd.h>
    int main() {
        char buffer[32] = \"/tmp/abcdefgXXXXXX\";
        int f = mkstemp(buffer);
        close(f);
        return 0;
    }
    "
    LIBATFRAME_UTILS_TEST_POSIX_MKSTEMP)
  if(LIBATFRAME_UTILS_TEST_POSIX_MKSTEMP)
    set(LIBATFRAME_UTILS_ENABLE_POSIX_MKSTEMP TRUE)
  endif()
endif()

if(ANDROID)
  # Android发现偶现_Unwind_Backtrace调用崩溃,默认金庸掉这个功能。 可以用adb logcat | ./ndk-stack -sym $PROJECT_PATH/obj/local/armeabi 代替
  option(LOG_WRAPPER_ENABLE_STACKTRACE "Try to enable stacktrace for log." OFF)
else()
  option(LOG_WRAPPER_ENABLE_STACKTRACE "Try to enable stacktrace for log." ON)
endif()
option(LOCK_DISABLE_MT "Disable multi-thread support lua support." OFF)
set(LOG_STACKTRACE_MAX_STACKS
    "100"
    CACHE STRING "Max stacks when stacktracing.")

include("${PROJECT_ATFRAME_UTILS_SOURCE_DIR}/log/log_configure.cmake")

# 内存混淆int
set(ENABLE_MIXEDINT_MAGIC_MASK
    0
    CACHE STRING "Integer mixed magic mask")
if(NOT ENABLE_MIXEDINT_MAGIC_MASK)
  set(ENABLE_MIXEDINT_MAGIC_MASK 0)
endif()

# third_party

if(LOG_WRAPPER_ENABLE_LUA_SUPPORT AND LOG_WRAPPER_CHECK_LUA)
  include("${ATFRAMEWORK_CMAKE_TOOLSET_DIR}/ports/lua/lua.cmake")
endif()

if(LOG_WRAPPER_ENABLE_STACKTRACE)
  if(NOT ANDROID AND NOT CMAKE_OSX_DEPLOYMENT_TARGET)
    # include("${ATFRAMEWORK_CMAKE_TOOLSET_DIR}/ports/jemalloc/jemalloc.cmake")
    if(NOT WIN32 AND NOT MINGW)
      include("${ATFRAMEWORK_CMAKE_TOOLSET_DIR}/ports/libunwind/libunwind.cmake")
    endif()
  endif()
endif()

if(NOT ATFRAMEWORK_CMAKE_TOOLSET_THIRD_PARTY_CRYPTO_DISABLED)
  include("${ATFRAMEWORK_CMAKE_TOOLSET_DIR}/ports/ssl/port.cmake")
endif()

if(ENABLE_NETWORK)
  include("${ATFRAMEWORK_CMAKE_TOOLSET_DIR}/ports/libuv/libuv.cmake")
  include("${ATFRAMEWORK_CMAKE_TOOLSET_DIR}/ports/libcurl/libcurl.cmake")
endif()

find_package(Libuuid)
if(TARGET libuuid)
  echowithcolor(COLOR YELLOW "-- Dependency(${PROJECT_NAME}): uuid generator with libuuid.(Target: libuuid)")
  list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES libuuid)
  set(LIBATFRAME_UTILS_ENABLE_LIBUUID TRUE)
elseif(Libuuid_FOUND)
  echowithcolor(
    COLOR YELLOW
    "-- Dependency(${PROJECT_NAME}): uuid generator with libuuid.(${Libuuid_INCLUDE_DIRS}:${Libuuid_LIBRARIES})")
  list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_INCLUDE_DIRS ${Libuuid_INCLUDE_DIRS})
  if(Libuuid_LIBRARIES)
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES ${Libuuid_LIBRARIES})
  endif()
  set(LIBATFRAME_UTILS_ENABLE_LIBUUID TRUE)
else()
  set(LIBATFRAME_UTILS_ENABLE_LIBUUID FALSE)
endif()

set(LIBATFRAME_UTILS_ENABLE_UUID_WINRPC FALSE)
if(NOT LIBATFRAME_UTILS_ENABLE_LIBUUID AND WIN32)
  include(CheckCXXSourceCompiles)
  set(LIBATFRAME_UTILS_TEST_UUID_BACKUP_CMAKE_REQUIRED_LIBRARIES ${CMAKE_REQUIRED_LIBRARIES})
  set(CMAKE_REQUIRED_LIBRARIES Rpcrt4)
  check_cxx_source_compiles(
    "
    #include <rpc.h>
    int main() {
        UUID Uuid;
        UuidCreate(&Uuid);
        return 0;
    }
    "
    LIBATFRAME_UTILS_TEST_UUID)

  set(CMAKE_REQUIRED_LIBRARIES ${LIBATFRAME_UTILS_TEST_UUID_BACKUP_CMAKE_REQUIRED_LIBRARIES})
  unset(LIBATFRAME_UTILS_TEST_UUID_BACKUP_CMAKE_REQUIRED_LIBRARIES)
  if(LIBATFRAME_UTILS_TEST_UUID)
    set(LIBATFRAME_UTILS_ENABLE_UUID_WINRPC TRUE)
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES Rpcrt4)
    echowithcolor(COLOR YELLOW "-- Dependency(${PROJECT_NAME}): uuid generator with Windows Rpcrt4.")
  endif()
endif()

if(NOT LIBATFRAME_UTILS_ENABLE_LIBUUID AND NOT LIBATFRAME_UTILS_ENABLE_UUID_WINRPC)
  set(LIBATFRAME_UTILS_ENABLE_UUID_INTERNAL_IMPLEMENT TRUE)
  echowithcolor(COLOR YELLOW "-- Dependency(${PROJECT_NAME}): uuid generator with internal implement.")
else()
  set(LIBATFRAME_UTILS_ENABLE_UUID_INTERNAL_IMPLEMENT FALSE)
endif()

# libuv
if(ENABLE_NETWORK)
  if(ATFRAMEWORK_CMAKE_TOOLSET_THIRD_PARTY_LIBUV_LINK_NAME)
    set(NETWORK_EVPOLL_ENABLE_LIBUV 1)
    message(STATUS "libuv using target(${PROJECT_NAME}): ${ATFRAMEWORK_CMAKE_TOOLSET_THIRD_PARTY_LIBUV_LINK_NAME}")
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES ${ATFRAMEWORK_CMAKE_TOOLSET_THIRD_PARTY_LIBUV_LINK_NAME})
  else()
    message(STATUS "Libuv support disabled(${PROJECT_NAME})")
  endif()

  # curl
  if(TARGET CURL::libcurl)
    message(STATUS "Curl using target(${PROJECT_NAME}): CURL::libcurl")
    set(NETWORK_ENABLE_CURL 1)
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES CURL::libcurl)
  elseif(CURL_FOUND AND CURL_LIBRARIES)
    message(STATUS "Curl support enabled(${PROJECT_NAME})")
    set(NETWORK_ENABLE_CURL 1)
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_INCLUDE_DIRS ${CURL_INCLUDE_DIRS})
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES ${CURL_LIBRARIES})
  else()
    message(STATUS "Curl support disabled(${PROJECT_NAME})")
  endif()
endif()

if(OPENSSL_FOUND)
  if((TARGET LibreSSL::Crypto) OR (TARGET LibreSSL::SSL))
    if(TARGET LibreSSL::Crypto)
      message(STATUS "OpenSSL using target(${PROJECT_NAME}): LibreSSL::Crypto")
      list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES LibreSSL::Crypto)
    endif()
    if(TARGET LibreSSL::SSL)
      message(STATUS "OpenSSL using target(${PROJECT_NAME}): LibreSSL::SSL")
      list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES LibreSSL::SSL)
    endif()
    set(CRYPTO_USE_LIBRESSL 1)
  elseif((TARGET OpenSSL::SSL) OR (TARGET OpenSSL::Crypto))
    if(TARGET OpenSSL::SSL)
      message(STATUS "OpenSSL using target(${PROJECT_NAME}): OpenSSL::SSL")
      list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES OpenSSL::SSL)
    endif()
    if(TARGET OpenSSL::Crypto)
      message(STATUS "OpenSSL using target(${PROJECT_NAME}): OpenSSL::Crypto")
      list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES OpenSSL::Crypto)
    endif()
    set(CRYPTO_USE_OPENSSL 1)
  else()
    message(STATUS "OpenSSL using(${PROJECT_NAME}): ${OPENSSL_SSL_LIBRARY};${OPENSSL_CRYPTO_LIBRARY}")
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_INCLUDE_DIRS ${OPENSSL_INCLUDE_DIR})
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES ${OPENSSL_SSL_LIBRARY} ${OPENSSL_CRYPTO_LIBRARY})
    set(CRYPTO_USE_OPENSSL 1)
  endif()
  if(OPENSSL_FOUND)
    if((DEFINED VCPKG_CMAKE_SYSTEM_NAME AND VCPKG_CMAKE_SYSTEM_NAME STREQUAL "WindowsStore")
       OR MINGW
       OR (CMAKE_SYSTEM_NAME STREQUAL "MinGW")
       OR (CMAKE_SYSTEM_NAME STREQUAL "Windows"))
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES Ws2_32 Crypt32)
    endif()
  endif()
  
elseif(MBEDTLS_FOUND)
  if(TARGET mbedtls_static)
    message(STATUS "MbedTLS using target(${PROJECT_NAME}): mbedtls_static")
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES mbedtls_static)
  elseif(TARGET mbedtls)
    message(STATUS "MbedTLS using target(${PROJECT_NAME}): mbedtls")
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES mbedtls)
  else()
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_INCLUDE_DIRS ${MbedTLS_INCLUDE_DIRS})
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES ${MbedTLS_CRYPTO_LIBRARIES})
  endif()
  set(CRYPTO_USE_MBEDTLS 1)
endif()

if(NOT ATFRAMEWORK_CMAKE_TOOLSET_THIRD_PARTY_CRYPTO_DISABLED)
  find_package(Libsodium)
  if(Libsodium_FOUND)
    set(CRYPTO_USE_LIBSODIUM 1)
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_INCLUDE_DIRS ${Libsodium_INCLUDE_DIRS})
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES ${Libsodium_LIBRARIES})
  endif()
endif()

# Check fmtlib(https://fmt.dev/) or std::format
if(NOT DEFINED LIBATFRAME_UTILS_ENABLE_STD_FORMAT AND NOT DEFINED CACHE{LIBATFRAME_UTILS_ENABLE_STD_FORMAT})
  check_cxx_source_compiles(
    "
#include <format>
#include <iostream>
#include <string>
struct custom_object {
  int32_t x;
  std::string y;
};

// Some STL implement may have BUGs on some APIs, we need check it
template <class CharT>
struct std::formatter<custom_object, CharT> : std::formatter<CharT*, CharT> {
  template <class FormatContext>
  auto format(const custom_object &vec, FormatContext &ctx) {
    return std::vformat_to(ctx.out(), \"({},{})\", std::make_format_args(vec.x, vec.y));
  }
};
int main() {
  custom_object custom_obj;
  custom_obj.x = 43;
  custom_obj.y = \"44\";
  std::cout<< std::format(\"The answer is {}, custom object: {}.\", 42, custom_obj)<< std::endl;
  char buffer[64] = {0};
  const auto result = std::format_to_n(buffer, sizeof(buffer), \"{} {}: {}\", \"Hello\", \"World!\", 42);
  std::cout << \"Buffer: \" << buffer << \",Untruncated output size = \" << result.size << std::endl;
  return 0;
}"
    LIBATFRAME_UTILS_ENABLE_STD_FORMAT)
  set(LIBATFRAME_UTILS_ENABLE_STD_FORMAT
      ${LIBATFRAME_UTILS_ENABLE_STD_FORMAT}
      CACHE BOOL "Using std format for log formatter")
endif()
if(NOT LIBATFRAME_UTILS_ENABLE_STD_FORMAT)
  set(ATFRAMEWORK_CMAKE_TOOLSET_THIRD_PARTY_TEST_STD_FORMAT OFF)
  include("${ATFRAMEWORK_CMAKE_TOOLSET_DIR}/ports/fmtlib/fmtlib.cmake")
  if(ATFRAMEWORK_CMAKE_TOOLSET_THIRD_PARTY_FMTLIB_LINK_NAME
     AND NOT DEFINED LIBATFRAME_UTILS_ENABLE_FMTLIB
     AND NOT DEFINED CACHE{LIBATFRAME_UTILS_ENABLE_FMTLIB})
    set(LIBATFRAME_UTILS_TEST_FMT_BACKUP_CMAKE_REQUIRED_LIBRARIES ${CMAKE_REQUIRED_LIBRARIES})
    set(CMAKE_REQUIRED_LIBRARIES ${ATFRAMEWORK_CMAKE_TOOLSET_THIRD_PARTY_FMTLIB_LINK_NAME})
    check_cxx_source_compiles(
      "
        #include <fmt/format.h>
        #include <iostream>
        #include <string>
        int main() {
            std::cout<< fmt::format(\"The answer is {}.\", 42)<< std::endl;
            char buffer[64] = {0};
            const auto result = fmt::format_to_n(buffer, sizeof(buffer), \"{} {}: {}\", \"Hello\", \"World!\", 42);
            std::cout << \"Buffer: \" << buffer << \",Untruncated output size = \" << result.size << std::endl;
            return 0;
        }"
      LIBATFRAME_UTILS_ENABLE_FMTLIB)
    set(CMAKE_REQUIRED_LIBRARIES ${LIBATFRAME_UTILS_TEST_FMT_BACKUP_CMAKE_REQUIRED_LIBRARIES})
    unset(LIBATFRAME_UTILS_TEST_FMT_BACKUP_CMAKE_REQUIRED_LIBRARIES)

    set(LIBATFRAME_UTILS_ENABLE_FMTLIB
        ${LIBATFRAME_UTILS_ENABLE_FMTLIB}
        CACHE BOOL "Using fmt.dev for log formatter")
  endif()

  if(LIBATFRAME_UTILS_ENABLE_FMTLIB)
    list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES ${ATFRAMEWORK_CMAKE_TOOLSET_THIRD_PARTY_FMTLIB_LINK_NAME})
  endif()
endif()

check_cxx_source_compiles(
  "
#include <unordered_map>
#include <unordered_set>
#include <string>

int main() {
    std::unordered_set<std::string> k1;
    k1.insert(std::string());
    std::unordered_map<std::string, int> k2;
    k2[std::string()] = 123;
    return 0;
}"
  LIBATFRAME_UTILS_ENABLE_UNORDERED_MAP_SET)
if(LIBATFRAME_UTILS_ENABLE_UNORDERED_MAP_SET)
  check_cxx_source_compiles(
    "
        #include <unordered_map>
        #include <unordered_set>
        #include <string>

        int main() {
            std::unordered_set<std::string> k1;
            k1.reserve(8);
            std::unordered_map<std::string, int> k2;
            k2.reserve(8);
            return 0;
        }"
    LIBATFRAME_UTILS_UNORDERED_MAP_SET_HAS_RESERVE)
endif()

set(LIBATFRAME_UTILS_ENABLE_RTTI ${COMPILER_OPTIONS_TEST_RTTI})
set(LIBATFRAME_UTILS_ENABLE_EXCEPTION ${COMPILER_OPTIONS_TEST_EXCEPTION})
set(LIBATFRAME_UTILS_ENABLE_STD_EXCEPTION_PTR ${COMPILER_OPTIONS_TEST_STD_EXCEPTION_PTR})

# Test Configure
set(GTEST_ROOT
    ""
    CACHE STRING "GTest root directory")
set(BOOST_ROOT
    ""
    CACHE STRING "Boost root directory")
option(PROJECT_TEST_ENABLE_BOOST_UNIT_TEST "Enable boost unit test." OFF)

option(PROJECT_ENABLE_UNITTEST "Enable unit test" OFF)
option(PROJECT_ENABLE_SAMPLE "Enable sample" OFF)
if(CMAKE_CROSSCOMPILING)
  option(PROJECT_ENABLE_TOOLS "Enable sample" OFF)
else()
  option(PROJECT_ENABLE_TOOLS "Enable sample" ON)
endif()

option(ATFRAMEWORK_USE_DYNAMIC_LIBRARY "Build and linking with dynamic libraries." OFF)
