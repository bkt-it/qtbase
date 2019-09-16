#=============================================================================
# Copyright 2005-2011 Kitware, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# * Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#
# * Neither the name of Kitware, Inc. nor the names of its
#   contributors may be used to endorse or promote products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#=============================================================================

######################################
#
#       Macros for building Qt files
#
######################################

include(CMakeParseArguments)

# macro used to create the names of output files preserving relative dirs
macro(QT6_MAKE_OUTPUT_FILE infile prefix ext outfile )
    string(LENGTH ${CMAKE_CURRENT_BINARY_DIR} _binlength)
    string(LENGTH ${infile} _infileLength)
    set(_checkinfile ${CMAKE_CURRENT_SOURCE_DIR})
    if(_infileLength GREATER _binlength)
        string(SUBSTRING "${infile}" 0 ${_binlength} _checkinfile)
        if(_checkinfile STREQUAL "${CMAKE_CURRENT_BINARY_DIR}")
            file(RELATIVE_PATH rel ${CMAKE_CURRENT_BINARY_DIR} ${infile})
        else()
            file(RELATIVE_PATH rel ${CMAKE_CURRENT_SOURCE_DIR} ${infile})
        endif()
    else()
        file(RELATIVE_PATH rel ${CMAKE_CURRENT_SOURCE_DIR} ${infile})
    endif()
    if(WIN32 AND rel MATCHES "^([a-zA-Z]):(.*)$") # absolute path
        set(rel "${CMAKE_MATCH_1}_${CMAKE_MATCH_2}")
    endif()
    set(_outfile "${CMAKE_CURRENT_BINARY_DIR}/${rel}")
    string(REPLACE ".." "__" _outfile ${_outfile})
    get_filename_component(outpath ${_outfile} PATH)
    get_filename_component(_outfile ${_outfile} NAME_WE)
    file(MAKE_DIRECTORY ${outpath})
    set(${outfile} ${outpath}/${prefix}${_outfile}.${ext})
endmacro()


macro(QT6_GET_MOC_FLAGS _moc_flags)
    set(${_moc_flags})
    get_directory_property(_inc_DIRS INCLUDE_DIRECTORIES)

    if(CMAKE_INCLUDE_CURRENT_DIR)
        list(APPEND _inc_DIRS ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR})
    endif()

    foreach(_current ${_inc_DIRS})
        if("${_current}" MATCHES "\\.framework/?$")
            string(REGEX REPLACE "/[^/]+\\.framework" "" framework_path "${_current}")
            set(${_moc_flags} ${${_moc_flags}} "-F${framework_path}")
        else()
            set(${_moc_flags} ${${_moc_flags}} "-I${_current}")
        endif()
    endforeach()

    get_directory_property(_defines COMPILE_DEFINITIONS)
    foreach(_current ${_defines})
        set(${_moc_flags} ${${_moc_flags}} "-D${_current}")
    endforeach()

    if(WIN32)
        set(${_moc_flags} ${${_moc_flags}} -DWIN32)
    endif()
    if (MSVC)
        set(${_moc_flags} ${${_moc_flags}} --compiler-flavor=msvc)
    endif()
endmacro()


# helper macro to set up a moc rule
function(QT6_CREATE_MOC_COMMAND infile outfile moc_flags moc_options moc_target moc_depends)
    # Pass the parameters in a file.  Set the working directory to
    # be that containing the parameters file and reference it by
    # just the file name.  This is necessary because the moc tool on
    # MinGW builds does not seem to handle spaces in the path to the
    # file given with the @ syntax.
    get_filename_component(_moc_outfile_name "${outfile}" NAME)
    get_filename_component(_moc_outfile_dir "${outfile}" PATH)
    if(_moc_outfile_dir)
        set(_moc_working_dir WORKING_DIRECTORY ${_moc_outfile_dir})
    endif()
    set (_moc_parameters_file ${outfile}_parameters)
    set (_moc_parameters ${moc_flags} ${moc_options} -o "${outfile}" "${infile}")
    string (REPLACE ";" "\n" _moc_parameters "${_moc_parameters}")

    if(moc_target)
        set(_moc_parameters_file ${_moc_parameters_file}$<$<BOOL:$<CONFIGURATION>>:_$<CONFIGURATION>>)
        set(targetincludes "$<TARGET_PROPERTY:${moc_target},INCLUDE_DIRECTORIES>")
        set(targetdefines "$<TARGET_PROPERTY:${moc_target},COMPILE_DEFINITIONS>")

        set(targetincludes "$<$<BOOL:${targetincludes}>:-I$<JOIN:${targetincludes},\n-I>\n>")
        set(targetdefines "$<$<BOOL:${targetdefines}>:-D$<JOIN:${targetdefines},\n-D>\n>")

        file (GENERATE
            OUTPUT ${_moc_parameters_file}
            CONTENT "${targetdefines}${targetincludes}${_moc_parameters}\n"
        )

        set(targetincludes)
        set(targetdefines)
    else()
        file(WRITE ${_moc_parameters_file} "${_moc_parameters}\n")
    endif()

    set(_moc_extra_parameters_file @${_moc_parameters_file})
    add_custom_command(OUTPUT ${outfile}
                       COMMAND ${QT_CMAKE_EXPORT_NAMESPACE}::moc ${_moc_extra_parameters_file}
                       DEPENDS ${infile} ${moc_depends}
                       ${_moc_working_dir}
                       VERBATIM)
    set_source_files_properties(${infile} PROPERTIES SKIP_AUTOMOC ON)
    set_source_files_properties(${outfile} PROPERTIES SKIP_AUTOMOC ON)
    set_source_files_properties(${outfile} PROPERTIES SKIP_AUTOUIC ON)
endfunction()


function(QT6_GENERATE_MOC infile outfile )
    # get include dirs and flags
    qt6_get_moc_flags(moc_flags)
    get_filename_component(abs_infile ${infile} ABSOLUTE)
    set(_outfile "${outfile}")
    if(NOT IS_ABSOLUTE "${outfile}")
        set(_outfile "${CMAKE_CURRENT_BINARY_DIR}/${outfile}")
    endif()
    if ("x${ARGV2}" STREQUAL "xTARGET")
        set(moc_target ${ARGV3})
    endif()
    qt6_create_moc_command(${abs_infile} ${_outfile} "${moc_flags}" "" "${moc_target}" "")
endfunction()


# qt6_wrap_cpp(outfiles inputfile ... )

function(QT6_WRAP_CPP outfiles )
    # get include dirs
    qt6_get_moc_flags(moc_flags)

    set(options)
    set(oneValueArgs TARGET)
    set(multiValueArgs OPTIONS DEPENDS)

    cmake_parse_arguments(_WRAP_CPP "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(moc_files ${_WRAP_CPP_UNPARSED_ARGUMENTS})
    set(moc_options ${_WRAP_CPP_OPTIONS})
    set(moc_target ${_WRAP_CPP_TARGET})
    set(moc_depends ${_WRAP_CPP_DEPENDS})

    foreach(it ${moc_files})
        get_filename_component(it ${it} ABSOLUTE)
        qt6_make_output_file(${it} moc_ cpp outfile)
        qt6_create_moc_command(${it} ${outfile} "${moc_flags}" "${moc_options}" "${moc_target}" "${moc_depends}")
        list(APPEND ${outfiles} ${outfile})
    endforeach()
    set(${outfiles} ${${outfiles}} PARENT_SCOPE)
endfunction()



# _qt6_parse_qrc_file(infile _out_depends _rc_depends)
# internal

function(_QT6_PARSE_QRC_FILE infile _out_depends _rc_depends)
    get_filename_component(rc_path ${infile} PATH)

    if(EXISTS "${infile}")
        #  parse file for dependencies
        #  all files are absolute paths or relative to the location of the qrc file
        file(READ "${infile}" RC_FILE_CONTENTS)
        string(REGEX MATCHALL "<file[^<]+" RC_FILES "${RC_FILE_CONTENTS}")
        foreach(RC_FILE ${RC_FILES})
            string(REGEX REPLACE "^<file[^>]*>" "" RC_FILE "${RC_FILE}")
            if(NOT IS_ABSOLUTE "${RC_FILE}")
                set(RC_FILE "${rc_path}/${RC_FILE}")
            endif()
            set(RC_DEPENDS ${RC_DEPENDS} "${RC_FILE}")
        endforeach()
        # Since this cmake macro is doing the dependency scanning for these files,
        # let's make a configured file and add it as a dependency so cmake is run
        # again when dependencies need to be recomputed.
        qt6_make_output_file("${infile}" "" "qrc.depends" out_depends)
        configure_file("${infile}" "${out_depends}" COPYONLY)
    else()
        # The .qrc file does not exist (yet). Let's add a dependency and hope
        # that it will be generated later
        set(out_depends)
    endif()

    set(${_out_depends} ${out_depends} PARENT_SCOPE)
    set(${_rc_depends} ${RC_DEPENDS} PARENT_SCOPE)
endfunction()


# qt6_add_binary_resources(target inputfiles ... )

function(QT6_ADD_BINARY_RESOURCES target )

    set(options)
    set(oneValueArgs DESTINATION)
    set(multiValueArgs OPTIONS)

    cmake_parse_arguments(_RCC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(rcc_files ${_RCC_UNPARSED_ARGUMENTS})
    set(rcc_options ${_RCC_OPTIONS})
    set(rcc_destination ${_RCC_DESTINATION})

    if(NOT rcc_destination)
        set(rcc_destination ${CMAKE_CURRENT_BINARY_DIR}/${target}.rcc)
    endif()

    foreach(it ${rcc_files})
        get_filename_component(infile ${it} ABSOLUTE)

        _QT6_PARSE_QRC_FILE(${infile} _out_depends _rc_depends)
        set_source_files_properties(${infile} PROPERTIES SKIP_AUTORCC ON)
        set(infiles ${infiles} ${infile})
        set(out_depends ${out_depends} ${_out_depends})
        set(rc_depends ${rc_depends} ${_rc_depends})
    endforeach()

    add_custom_command(OUTPUT ${rcc_destination}
                       COMMAND ${QT_CMAKE_EXPORT_NAMESPACE}::rcc
                       ARGS ${rcc_options} --binary --name ${target} --output ${rcc_destination} ${infiles}
                       DEPENDS ${rc_depends} ${out_depends} ${infiles} VERBATIM)
    add_custom_target(${target} ALL DEPENDS ${rcc_destination})
endfunction()


# qt6_add_resources(target resourcename ...
# or
# qt6_add_resources(outfiles inputfile ... )

function(QT6_ADD_RESOURCES outfiles )
    if (TARGET ${outfiles})
        cmake_parse_arguments(arg "" "OUTPUT_TARGETS" "" ${ARGN})
        QT6_PROCESS_RESOURCE(${ARGV})
        if (arg_OUTPUT_TARGETS)
            set(${arg_OUTPUT_TARGETS} ${${arg_OUTPUT_TARGETS}} PARENT_SCOPE)
        endif()
    else()
        set(options)
        set(oneValueArgs)
        set(multiValueArgs OPTIONS)

        cmake_parse_arguments(_RCC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

        set(rcc_files ${_RCC_UNPARSED_ARGUMENTS})
        set(rcc_options ${_RCC_OPTIONS})

        if("${rcc_options}" MATCHES "-binary")
            message(WARNING "Use qt6_add_binary_resources for binary option")
        endif()

        foreach(it ${rcc_files})
            get_filename_component(outfilename ${it} NAME_WE)
            get_filename_component(infile ${it} ABSOLUTE)
            set(outfile ${CMAKE_CURRENT_BINARY_DIR}/qrc_${outfilename}.cpp)

            _QT6_PARSE_QRC_FILE(${infile} _out_depends _rc_depends)
            set_source_files_properties(${infile} PROPERTIES SKIP_AUTORCC ON)

            add_custom_command(OUTPUT ${outfile}
                               COMMAND ${QT_CMAKE_EXPORT_NAMESPACE}::rcc
                               ARGS ${rcc_options} --name ${outfilename} --output ${outfile} ${infile}
                               MAIN_DEPENDENCY ${infile}
                               DEPENDS ${_rc_depends} "${_out_depends}" VERBATIM)
            set_source_files_properties(${outfile} PROPERTIES SKIP_AUTOMOC ON)
            set_source_files_properties(${outfile} PROPERTIES SKIP_AUTOUIC ON)
            list(APPEND ${outfiles} ${outfile})
        endforeach()
        set(${outfiles} ${${outfiles}} PARENT_SCOPE)
    endif()
endfunction()

# qt6_add_big_resources(outfiles inputfile ... )

function(QT6_ADD_BIG_RESOURCES outfiles )
    if (CMAKE_VERSION VERSION_LESS 3.9)
        message(FATAL_ERROR, "qt6_add_big_resources requires CMake 3.9 or newer")
    endif()

    set(options)
    set(oneValueArgs)
    set(multiValueArgs OPTIONS)

    cmake_parse_arguments(_RCC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(rcc_files ${_RCC_UNPARSED_ARGUMENTS})
    set(rcc_options ${_RCC_OPTIONS})

    if("${rcc_options}" MATCHES "-binary")
        message(WARNING "Use qt6_add_binary_resources for binary option")
    endif()

    foreach(it ${rcc_files})
        get_filename_component(outfilename ${it} NAME_WE)
        get_filename_component(infile ${it} ABSOLUTE)
        set(tmpoutfile ${CMAKE_CURRENT_BINARY_DIR}/qrc_${outfilename}tmp.cpp)
        set(outfile ${CMAKE_CURRENT_BINARY_DIR}/qrc_${outfilename}.o)

        _QT6_PARSE_QRC_FILE(${infile} _out_depends _rc_depends)
        set_source_files_properties(${infile} PROPERTIES SKIP_AUTORCC ON)
        add_custom_command(OUTPUT ${tmpoutfile}
                           COMMAND ${QT_CMAKE_EXPORT_NAMESPACE}::rcc ${rcc_options} --name ${outfilename} --pass 1 --output ${tmpoutfile} ${infile}
                           DEPENDS ${infile} ${_rc_depends} "${out_depends}" VERBATIM)
        add_custom_target(big_resources_${outfilename} ALL DEPENDS ${tmpoutfile})
        add_library(rcc_object_${outfilename} OBJECT ${tmpoutfile})
        set_target_properties(rcc_object_${outfilename} PROPERTIES AUTOMOC OFF)
        set_target_properties(rcc_object_${outfilename} PROPERTIES AUTOUIC OFF)
        add_dependencies(rcc_object_${outfilename} big_resources_${outfilename})
        # The modification of TARGET_OBJECTS needs the following change in cmake
        # https://gitlab.kitware.com/cmake/cmake/commit/93c89bc75ceee599ba7c08b8fe1ac5104942054f
        add_custom_command(OUTPUT ${outfile}
                           COMMAND ${QT_CMAKE_EXPORT_NAMESPACE}::rcc
                           ARGS ${rcc_options} --name ${outfilename} --pass 2 --temp $<TARGET_OBJECTS:rcc_object_${outfilename}> --output ${outfile} ${infile}
                           DEPENDS rcc_object_${outfilename}
                           VERBATIM)
       list(APPEND ${outfiles} ${outfile})
    endforeach()
    set(${outfiles} ${${outfiles}} PARENT_SCOPE)
endfunction()

set(_Qt5_COMPONENT_PATH "${CMAKE_CURRENT_LIST_DIR}/..")

if (NOT CMAKE_VERSION VERSION_LESS 2.8.9)
    macro(qt6_use_modules _target _link_type)
        if(NOT CMAKE_MINIMUM_REQUIRED_VERSION VERSION_LESS 2.8.11)
            if(CMAKE_WARN_DEPRECATED)
                set(messageType WARNING)
            endif()
            if(CMAKE_ERROR_DEPRECATED)
                set(messageType FATAL_ERROR)
            endif()
            if(messageType)
                message(${messageType} "The qt6_use_modules macro is obsolete. Use target_link_libraries with IMPORTED targets instead.")
            endif()
        endif()

        if (NOT TARGET ${_target})
            message(FATAL_ERROR "The first argument to qt6_use_modules must be an existing target.")
        endif()
        if ("${_link_type}" STREQUAL "LINK_PUBLIC" OR "${_link_type}" STREQUAL "LINK_PRIVATE" )
            set(_qt6_modules ${ARGN})
            set(_qt6_link_type ${_link_type})
        else()
            set(_qt6_modules ${_link_type} ${ARGN})
        endif()

        if ("${_qt6_modules}" STREQUAL "")
            message(FATAL_ERROR "qt6_use_modules requires at least one Qt module to use.")
        endif()

        foreach(_module ${_qt6_modules})
            if (NOT Qt5${_module}_FOUND)
                find_package(Qt5${_module} PATHS "${_Qt5_COMPONENT_PATH}" NO_DEFAULT_PATH)
                if (NOT Qt5${_module}_FOUND)
                    message(FATAL_ERROR "Cannot use \"${_module}\" module which has not yet been found.")
                endif()
            endif()
            target_link_libraries(${_target} ${_qt6_link_type} ${Qt5${_module}_LIBRARIES})
            set_property(TARGET ${_target} APPEND PROPERTY INCLUDE_DIRECTORIES ${Qt5${_module}_INCLUDE_DIRS})
            set_property(TARGET ${_target} APPEND PROPERTY COMPILE_DEFINITIONS ${Qt5${_module}_COMPILE_DEFINITIONS})
            set_property(TARGET ${_target} APPEND PROPERTY COMPILE_DEFINITIONS_RELEASE QT_NO_DEBUG)
            set_property(TARGET ${_target} APPEND PROPERTY COMPILE_DEFINITIONS_RELWITHDEBINFO QT_NO_DEBUG)
            set_property(TARGET ${_target} APPEND PROPERTY COMPILE_DEFINITIONS_MINSIZEREL QT_NO_DEBUG)
            if (Qt5_POSITION_INDEPENDENT_CODE
                    AND (CMAKE_VERSION VERSION_LESS 2.8.12
                        AND (NOT CMAKE_CXX_COMPILER_ID STREQUAL "GNU"
                        OR CMAKE_CXX_COMPILER_VERSION VERSION_LESS 5.0)))
                set_property(TARGET ${_target} PROPERTY POSITION_INDEPENDENT_CODE ${Qt5_POSITION_INDEPENDENT_CODE})
            endif()
        endforeach()
    endmacro()
endif()

function(add_qt_gui_executable target)
    if(ANDROID)
        add_library("${target}" MODULE ${ARGN})
        # On our qmake builds we do don't compile the executables with
        # visibility=hidden. Not having this flag set will cause the
        # executable to have main() hidden and can then no longer be loaded
        # through dlopen()
        set_property(TARGET "${target}" PROPERTY C_VISIBILITY_PRESET default)
        set_property(TARGET "${target}" PROPERTY CXX_VISIBILITY_PRESET default)
        qt_android_apply_arch_suffix("${target}")
    else()
        add_executable("${target}" WIN32 MACOSX_BUNDLE ${ARGN})
    endif()
    target_link_libraries("${target}" PRIVATE Qt::Core Qt::Gui)

    if(ANDROID)
        qt_android_generate_deployment_settings("${target}")
    endif()
endfunction()

macro(_qt_import_plugin target plugin)
    get_target_property(plugin_class_name "${plugin}" QT_PLUGIN_CLASS_NAME)
    if(plugin_class_name)
        set_property(TARGET "${target}" APPEND PROPERTY QT_PLUGINS "${plugin}")
        # TODO mark it for installation
        # TODO also in shared builds
    endif()
endmacro()

# This function is used to indicate which plug-ins are going to be
# used by a given target.
# This allows both automatic static linking, and automatic installation of relevant
# plug-ins.
# Options :
#    NO_DEFAULT: won't link against any plug-in by default for that target, e.g. no platform plug-in.
#    INCLUDE: list of additional plug-ins to be linked against.
#    EXCLUDE: list of plug-ins to be removed from the default set.
# TODO : support qml plug-ins.
function(qt_import_plugins target)
    cmake_parse_arguments(arg "NO_DEFAULT" "" "INCLUDE;EXCLUDE" ${ARGN})

    if(${arg_NO_DEFAULT})
        set_target_properties(${target} PROPERTIES QT_DEFAULT_PLUGINS 0)
    else()
        set_target_properties(${target} PROPERTIES QT_DEFAULT_PLUGINS 1)
    endif()

    foreach(plugin ${arg_INCLUDE})
        _qt_import_plugin("${target}" "${plugin}")
    endforeach()

    foreach(plugin ${arg_EXCLUDE})
        set_property(TARGET "${target}" APPEND PROPERTY QT_NO_PLUGINS "${plugin}")
    endforeach()
endfunction()

