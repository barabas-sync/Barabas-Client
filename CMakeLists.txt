cmake_minimum_required(VERSION 2.6)
project(barabas-dbus)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala)

find_package(Vala REQUIRED)
include(UseVala)

find_package(PkgConfig)
pkg_check_modules(GLIB REQUIRED glib-2.0>=2.26 gio-2.0>=2.26 gee-1.0 json-glib-1.0 sqlite3)
add_definitions(${GLIB_CFLAGS} ${GLIB_CFLAGS_OTHER} -g)
link_libraries(${GLIB_LIBRARIES})
link_directories(${GLIB_LIBRARY_DIRS})

vala_precompile(BARABAS_CLIENT_C
                         lib/barabas-protocol/internal/handshake_command.vala
                         lib/barabas-protocol/internal/user_password_login_command.vala
                         lib/barabas-protocol/internal/download_log_command.vala
                         lib/barabas-protocol/icommand.vala
                         lib/barabas-protocol/new_file_command.vala
                         lib/barabas-protocol/new_tag_command.vala
                         lib/barabas-protocol/remove_tag_command.vala
                         lib/barabas-protocol/request_download_command.vala
                         lib/caches/cache.vala
                         lib/caches/synced_file_cache.vala
                         lib/objects/local_file.vala
                         lib/objects/synced_file.vala
                         lib/objects/synced_file_tag.vala
                         lib/objects/synced_file_version.vala
                         lib/connection.vala
                         lib/connection_status.vala
                         lib/database.vala
                PACKAGES glib-2.0 gio-2.0 gee-1.0 json-glib-1.0 sqlite3
                GENERATE_VAPI barabas_client
                )
add_library(barabas-client ${BARABAS_CLIENT_C})

vala_precompile(BARABAS_DBUS_C
                         src/objects/aresource.vala
                         src/objects/download.vala
                         src/objects/local_file.vala
                         src/objects/search.vala
                         src/objects/synced_file.vala
                         src/objects/synced_file_version.vala
                         src/barabas.vala
                         src/file_monitor_client.vala
                         src/local_file_resource_manager.vala
                         src/resource_manager.vala
                PACKAGES glib-2.0 gio-2.0 gee-1.0 json-glib-1.0 sqlite3
                CUSTOM_VAPIS ${CMAKE_BINARY_DIR}/barabas_client.vapi)
add_executable(barabas-dbus ${BARABAS_DBUS_C})
target_link_libraries(barabas-dbus barabas-client)
