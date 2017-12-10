# Helper macro for LIST_REPLACE
macro(LIST_REPLACE LISTV OLDVALUE NEWVALUE)
	LIST(FIND ${LISTV} ${OLDVALUE} INDEX)
	LIST(INSERT ${LISTV} ${INDEX} ${NEWVALUE})
	MATH(EXPR __INDEX "${INDEX} + 1")
	LIST(REMOVE_AT ${LISTV} ${__INDEX})
endmacro(LIST_REPLACE)

# Wrapper around ADD_EXECUTABLE, which adds the necessary -mmcu flags and
# sets up builds for multiple devices. Also creates targets to generate 
# disassembly listings, size outputs, map files, and to upload to device. 
# Also adds all these extra files created including map files to the clean
# list.
FUNCTION(add_platform_executable EXECUTABLE_NAME DEPENDENCIES)
	SET(DEVICES ${SUPPORTED_DEVICES})
	
	SET(EXE_NAME ${EXECUTABLE_NAME})
	LIST(REMOVE_AT  ARGV	0)
	
	SET(DEPS ${DEPENDENCIES})
	SEPARATE_ARGUMENTS(DEPS)
	LIST(REMOVE_AT  ARGV    0)
	
	FOREACH(device ${DEVICES})
		
		SET(ELF_FILE ${EXE_NAME}-${device}.elf)
		SET(MAP_FILE ${EXE_NAME}-${device}.map)
		SET(LST_FILE ${EXE_NAME}-${device}.lst)
		SET(SYM_FILE ${EXE_NAME}-${device}.sym)
		SET(HEX_FILE ${EXE_NAME}-${device}.hex)
		
		ADD_EXECUTABLE(${ELF_FILE} ${ARGN})
		SET_TARGET_PROPERTIES(
			${ELF_FILE} PROPERTIES
			COMPILE_FLAGS "-mmcu=${device}"
            LINK_FLAGS "-mmcu=${device} -Wl,-Map,${MAP_FILE}  ${EXTRA_LINKER_FLAGS} -L ${MSP430_TI_COMPILER_FOLDER}/include -T ../${EXE_NAME}-${device}.ld"
			)
            # A user-defined command file <project>-<device>.ld must be present in source directory. It is used to control sections and so on.
            # To use standard command file (<device>.ld) from MSP0GCC include directory replace the last line by this:
            #LINK_FLAGS "-mmcu=${device} -Wl,-Map,${MAP_FILE}  ${EXTRA_LINKER_FLAGS} -L ${MSP430_TI_COMPILER_FOLDER}/include -T ${device}.ld"
		SET(DDEPS ${DEPS})
		
		IF(DDEPS)
		    LIST(REMOVE_DUPLICATES DDEPS)
                    FOREACH(dep ${DDEPS})
			LIST_REPLACE(DDEPS "${dep}" "${dep}-${device}")
                    ENDFOREACH(dep)
		    TARGET_LINK_LIBRARIES(${ELF_FILE} ${DDEPS})
		ENDIF(DDEPS)
		
		ADD_CUSTOM_TARGET(
			${EXE_NAME}-${device}.lst ALL
			${MSP430_OBJDUMP} -h -S ${ELF_FILE} > ${LST_FILE}
			DEPENDS ${ELF_FILE}
			)

		ADD_CUSTOM_TARGET(
			${EXE_NAME}-${device}.sym ALL
			${MSP430_NM} -l -a -S -s --size-sort ${ELF_FILE} > ${SYM_FILE}
			DEPENDS ${ELF_FILE}
			)

		ADD_CUSTOM_TARGET(
			${EXE_NAME}-${device}.hex ALL
			${MSP430_OBJCOPY} -Oihex ${ELF_FILE} ${HEX_FILE} > ${HEX_FILE}
			DEPENDS ${ELF_FILE}
		)

		ADD_CUSTOM_TARGET(
			${EXE_NAME}-${device}.size ALL
			${MSP430_SIZE} ${ELF_FILE}
			DEPENDS ${ELF_FILE}
		)

		ADD_CUSTOM_TARGET(
			${EXE_NAME}-${device}-upload
			# TODO Try to resolve the gdb_agent_console problem described here
            # http://e2e.ti.com/support/development_tools/code_composer_studio/f/81/p/647037/2378562#2378562
            # and then TODO create script to burn the chip - via mspdebug or MAPFlasher or anything.
			#export LD_LIBRARY_PATH=${FLASHER_PATH}:$LD_LIBRARY_PATH
			#PROGBIN -w "last-burn.hex" -v -g -z [VCC]
			#${FLASHER_PATH} ${PROGBIN} ${MSP430_OBJCOPY} ${ELF_FILE}
			DEPENDS ${HEX_FILE}
			)

		LIST(APPEND	all_lst_files	${LST_FILE})
		LIST(APPEND all_elf_files 	${ELF_FILE})
		LIST(APPEND	all_map_files	${MAP_FILE})
		LIST(APPEND	all_sym_files	${SYM_FILE})
		LIST(APPEND	all_hex_files	${HEX_FILE})

	ENDFOREACH(device)
	
	ADD_CUSTOM_TARGET(
		${EXE_NAME} ALL
		DEPENDS ${all_elf_files}
		)

	#ADD_CUSTOM_TARGET(
	#	${SYM_NAME} ALL
	#	DEPENDS ${all_elf_files}
	#)

	GET_DIRECTORY_PROPERTY(clean_files ADDITIONAL_MAKE_CLEAN_FILES)
	LIST(APPEND clean_files ${all_map_files})
	LIST(APPEND clean_files ${all_lst_files})
	LIST(APPEND clean_files ${all_elf_files})
	LIST(APPEND clean_files ${all_sym_files})
	LIST(APPEND clean_files ${all_hex_files})
	SET_DIRECTORY_PROPERTIES(PROPERTIES 
		ADDITIONAL_MAKE_CLEAN_FILES "${clean_files}"
	)
ENDFUNCTION(add_platform_executable)

# Wrapper around ADD_LIBRARY, which adds the necessary -mmcu flags and
# sets up builds for multiple devices. 
FUNCTION(add_platform_library LIBRARY_NAME LIBRARY_TYPE DEPENDENCIES)
	SET(DEVICES ${SUPPORTED_DEVICES})
	
	SET(LIB_NAME ${LIBRARY_NAME})
	LIST(REMOVE_AT  ARGV    0)
	
	SET(DEPS ${DEPENDENCIES})
	SEPARATE_ARGUMENTS(DEPS)
	LIST(REMOVE_AT  ARGV    0)
	
	SET(TYPE ${LIBRARY_TYPE})
	LIST(REMOVE_AT  ARGV	0)
	
	FOREACH(device ${DEVICES})
		SET(LIB_DNAME ${LIB_NAME}-${device})
		SET(SYM_FILE ${LIB_DNAME}.sym)
		SET(ASM_FILE ${LIB_DNAME}.s)
		SET(LIB_FILE lib${LIB_DNAME}.a)
		
		ADD_LIBRARY(${LIB_DNAME} ${TYPE} ${ARGN})
		SET_TARGET_PROPERTIES(
                        ${LIB_DNAME} PROPERTIES
                        COMPILE_FLAGS "-mmcu=${device}"
                        LINK_FLAGS "-mmcu=${device} ${EXTRA_LINKER_FLAGS} -T ${MSP430_TI_COMPILER_FOLDER}/include/${device}.ld"
                )
		
		SET(DDEPS ${DEPS})
		FOREACH(dep ${DEPS})
			LIST_REPLACE(DDEPS "${dep}" "${dep}-${device}")
		ENDFOREACH(dep)
		IF(DDEPS)
		    TARGET_LINK_LIBRARIES(${LIB_DNAME} ${DDEPS})
		ENDIF(DDEPS)
		ADD_CUSTOM_TARGET(
			${SYM_FILE}
			${MSP430_NM} -l -a -S -s --size-sort ${LIB_FILE} > ${SYM_FILE}
			DEPENDS ${LIB_DNAME}
		)
                ADD_CUSTOM_TARGET(
                        ${ASM_FILE}
                        ${MSP430_OBJDUMP} -h -D -f -l -S -a ${LIB_FILE} > ${ASM_FILE}
                        DEPENDS ${LIB_DNAME}
                )
                LIST(APPEND     all_lib_files   ${LIB_FILE})
                LIST(APPEND     all_sym_files   ${SYM_FILE})
                LIST(APPEND     all_asm_files   ${ASM_FILE})
	ENDFOREACH(device)
	
	GET_DIRECTORY_PROPERTY(clean_files ADDITIONAL_MAKE_CLEAN_FILES)
	LIST(APPEND clean_files ${all_lib_files})
	LIST(APPEND clean_files ${all_sym_files})
	LIST(APPEND clean_files ${all_asm_files})
	SET_DIRECTORY_PROPERTIES(PROPERTIES 
		ADDITIONAL_MAKE_CLEAN_FILES "${clean_files}"
	)
ENDFUNCTION(add_platform_library)

MACRO(install_file_tree LOCATION)
    FOREACH(ifile ${ARGN})
        FILE(RELATIVE_PATH rel ${PUBLIC_INCLUDE_DIRECTORY} ${ifile})
        GET_FILENAME_COMPONENT( dir ${rel} DIRECTORY )
        INSTALL(FILES ${ifile} DESTINATION ${LOCATION}/${dir})
    ENDFOREACH(ifile)
ENDMACRO(install_file_tree)

MACRO(install_platform_library LIBRARY_NAME)
	FOREACH(device ${SUPPORTED_DEVICES})
	    INSTALL(TARGETS ${LIBRARY_NAME}-${device} DESTINATION lib EXPORT ${LIBRARY_NAME}-config)
	    IF (PUBLIC_INCLUDE_DIRECTORY)
	      TARGET_INCLUDE_DIRECTORIES(${LIBRARY_NAME}-${device} PUBLIC ${PLATFORM_PACKAGES_PATH}/include/${LIBRARY_NAME})
	    ENDIF (PUBLIC_INCLUDE_DIRECTORY)
	ENDFOREACH(device)
	IF (PUBLIC_INCLUDE_DIRECTORY)
	  INSTALL_FILE_TREE(include/${LIBRARY_NAME} ${ARGN})
	ENDIF (PUBLIC_INCLUDE_DIRECTORY)
	INSTALL(EXPORT ${LIBRARY_NAME}-config DESTINATION lib/cmake/${LIBRARY_NAME})
ENDMACRO(install_platform_library)


