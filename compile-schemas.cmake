find_program(GLIB_COMPILE_SCHEMAS_BIN glib-compile-schemas)
message("Found ${GLIB_COMPILE_SCHEMAS_BIN}")

execute_process (COMMAND ${GLIB_COMPILE_SCHEMAS_BIN} "${CMAKE_INSTALL_PREFIX}/share/glib-2.0/schemas")
