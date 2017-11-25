MAKEFILE_DEFINES=''
CONFIG_DEFINES=''

[ "$PREFIX" ] || PREFIX="/usr/local"

add_define() # $1 = MAKEFILE or CONFIG $2 = define $3 = value
{ eval "${1}_DEFINES=\"\${${1}_DEFINES} $2=$3\""; }

add_dirs() # $1 = INCLUDE or LIBRARY  $@ = include or library paths
{	ADD="$1"; LINK="${1%"${1#?}"}"; shift
	while [ "$1" ]; do
		eval "${ADD}_DIRS=\"\${${ADD}_DIRS} -${LINK}${1}\""
		shift
	done
	eval "${ADD}_DIRS=\"\${${ADD}_DIRS# }\""
}

check_compiler() # $1 = language  $2 = function in lib
{	if [ "$1" = cxx ]; then
		COMPILER="$CXX"
		TEMP_CODE="$TEMP_CXX"
		TEST_C="extern \"C\" { void $2(void); } int main() { $2(); }"
	else
		COMPILER="$CC"
		TEMP_CODE="$TEMP_C"
		TEST_C="void $2(void); int main(void) { $2(); return 0; }"
	fi
}

check_lib() # $1 = language  $2 = HAVE_$2  $3 = lib  $4 = function in lib  $5 = extralibs $6 = headers $7 = critical error message [checked only if non-empty]
{	tmpval="$(eval "printf %s \"\$HAVE_$2\"")"
	[ "$tmpval" = 'no' ] && return 0

	check_compiler "$1" "$4"

	if [ "$4" ]; then
		ECHOBUF="Checking function $4 in ${3% }"
		if [ "$6" ]; then
			printf %s\\n "$6" "int main(void) { void *p = (void*)$4; return 0; }" > "$TEMP_CODE"
		else
			printf %s\\n "$TEST_C" > "$TEMP_CODE"
		fi
	else
		ECHOBUF="Checking existence of ${3% }"
		printf %s\\n 'int main(void) { return 0; }' > "$TEMP_CODE"
	fi
	answer='no'
	"$COMPILER" -o \
		"$TEMP_EXE" \
		"$TEMP_CODE" \
		$INCLUDE_DIRS \
		$LIBRARY_DIRS \
		$(printf %s "$5") \
		$CFLAGS \
		$LDFLAGS \
		$(printf %s "$3") >>config.log 2>&1 && answer='yes'
	eval "HAVE_$2=\"$answer\""
	printf %s\\n "$ECHOBUF ... $answer"
	rm -f -- "$TEMP_CODE" "$TEMP_EXE"

	[ "$answer" = 'no' ] && {
		[ "$7" ] && die 1 "$7"
		[ "$tmpval" = 'yes' ] && {
			die 1 "Forced to build with library $3, but cannot locate. Exiting ..."
		}

	}

	return 0
}

check_pkgconf()	#$1 = HAVE_$1	$2 = package	$3 = version	$4 = critical error message [checked only if non-empty]
{	tmpval="$(eval echo \$HAVE_$1)"
	[ "$tmpval" = 'no' ] && return 0

	ECHOBUF="Checking presence of package $2"
	[ "$3" ] && ECHOBUF="$ECHOBUF >= $3"

	[ "$PKG_CONF_PATH" = "none" ] && {
		eval HAVE_$1="no"
		echo "$ECHOBUF ... no"
		return 0
	}

	answer='no'
	version='no'
	$PKG_CONF_PATH --atleast-version="${3:-0.0}" "$2" && {
		answer='yes'
		version=$($PKG_CONF_PATH --modversion "$2")
		eval $1_CFLAGS=\"$($PKG_CONF_PATH $2 --cflags)\"
		eval $1_LIBS=\"$($PKG_CONF_PATH $2 --libs)\"
	}
	
	eval HAVE_$1="$answer";
	echo "$ECHOBUF ... $version"
	PKG_CONF_USED="$PKG_CONF_USED $1"
	[ "$answer" = 'no' ] && {
		[ "$4" ] && die 1 "$4"
		[ "$tmpval" = 'yes' ] && \
			die 1 "Forced to build with package $2, but cannot locate. Exiting ..."
	}
}

check_header()	#$1 = HAVE_$1	$2..$5 = header files
{	tmpval="$(eval echo \$HAVE_$1)"
	[ "$tmpval" = 'no' ] && return 0
	CHECKHEADER="$2"
	echo "#include <$2>" > "$TEMP_C"
	[ "$3" != "" ] && CHECKHEADER="$3" && echo "#include <$3>" >> "$TEMP_C"
	[ "$4" != "" ] && CHECKHEADER="$4" && echo "#include <$4>" >> "$TEMP_C"
	[ "$5" != "" ] && CHECKHEADER="$5" && echo "#include <$5>" >> "$TEMP_C"
	echo "int main(void) { return 0; }" >> "$TEMP_C"
	answer='no'
	"$CC" -o "$TEMP_EXE" "$TEMP_C" $INCLUDE_DIRS >>config.log 2>&1 && answer='yes'
	eval HAVE_$1="$answer"; echo "Checking presence of header file $CHECKHEADER ... $answer"
	rm -f -- "$TEMP_C" "$TEMP_EXE"
	[ "$tmpval" = 'yes' ] && [ "$answer" = 'no' ] && \
		die 1 "Build assumed that $2 exists, but cannot locate. Exiting ..."
}

check_macro()	#$1 = HAVE_$1	$2 = macro name
{	tmpval="$(eval echo \$HAVE_$1)"
	[ "$tmpval" = 'no' ] && return 0
	ECHOBUF="Checking presence of predefined macro $2"
	cat << EOF > "$TEMP_C"
#ifndef $2
#error $2 is not defined
#endif
int main(void) { return 0; }
EOF
	answer='no'
	"$CC" -o "$TEMP_EXE" "$TEMP_C" $CFLAGS $INCLUDE_DIRS >>config.log 2>&1 && answer='yes'
	eval HAVE_$1="$answer"; echo "$ECHOBUF ... $answer"
	rm -f -- "$TEMP_C" "$TEMP_EXE"
	[ "$tmpval" = 'yes' ] && [ "$answer" = 'no' ] && \
		die 1 "Build assumed that $2 is defined, but it's not. Exiting ..."
}

check_switch() # $1 = language  $2 = HAVE_$2  $3 = switch  $4 = critical error message [checked only if non-empty]
{	check_compiler "$1" ''

	ECHOBUF="Checking for availability of switch $3 in $COMPILER"
	printf %s\\n 'int main(void) { return 0; }' > "$TEMP_CODE"
	answer='no'
	"$COMPILER" -o "$TEMP_EXE" "$TEMP_CODE" "$3" >>config.log 2>&1 && answer='yes'
	eval "HAVE_$2=\"$answer\""
	printf %s\\n "$ECHOBUF ... $answer"
	rm -f -- "$TEMP_CODE" "$TEMP_EXE"
	[ "$answer" = 'no' ] && {
		[ "$4" ] && die 1 "$4"
	}
}

create_config_header()
{   outfile="$1"; shift

	printf %s\\n "Creating config header: $outfile"
	name="$(printf %s "QB_${outfile}__" | tr '.[a-z]' '_[A-Z]')"

	{	printf %s\\n "#ifndef $name" "#define $name" '' \
			"#define PACKAGE_NAME \"$PACKAGE_NAME\""

		while [ "$1" ]; do
			case "$(eval "printf %s \"\$HAVE_$1\"")" in
				'yes')
					if [ "$(eval "printf %s \"\$C89_$1\"")" = 'no' ]; then
						printf %s\\n '#if __cplusplus || __STDC_VERSION__ >= 199901L' \
							"#define HAVE_$1 1" '#endif'
					else
						printf %s\\n "#define HAVE_$1 1"
					fi
				;;
				'no') printf %s\\n "/* #undef HAVE_$1 */";;
			esac
			shift
		done

		eval "set -- $CONFIG_DEFINES"
		for VAR do
			printf %s\\n "#define ${VAR%%=*} ${VAR#*=}"
		done

		printf %s\\n '#endif'
	} > "$outfile"
}

create_config_make()
{	outfile="$1"; shift

	printf %s\\n "Creating make config: $outfile"

	{	[ "$USE_LANG_C" = 'yes' ] && printf %s\\n "CC = $CC" "CFLAGS = $CFLAGS"
		[ "$USE_LANG_CXX" = 'yes' ] && printf %s\\n "CXX = $CXX" "CXXFLAGS = $CXXFLAGS"

		printf %s\\n "WINDRES = $WINDRES" \
			"ASFLAGS = $ASFLAGS" \
			"LDFLAGS = $LDFLAGS" \
			"INCLUDE_DIRS = $INCLUDE_DIRS" \
			"LIBRARY_DIRS = $LIBRARY_DIRS" \
			"PACKAGE_NAME = $PACKAGE_NAME" \
			"BUILD = $BUILD" \
			"PREFIX = $PREFIX"

		while [ "$1" ]; do
			case "$(eval "printf %s \"\$HAVE_$1\"")" in
				'yes')
					if [ "$(eval "printf %s \"\$C89_$1\"")" = 'no' ]; then
						printf %s\\n "ifneq (\$(C89_BUILD),1)" \
							"HAVE_$1 = 1" 'endif'
					else
						printf %s\\n "HAVE_$1 = 1"
					fi
				;;
				'no') printf %s\\n "HAVE_$1 = 0";;
			esac
			
			case "$PKG_CONF_USED" in
				*$1*)
					FLAGS="$(eval "printf %s \"\$$1_CFLAGS\"")"
					LIBS="$(eval "printf %s \"\$$1_LIBS\"")"
					printf %s\\n "$1_CFLAGS = ${FLAGS%"${FLAGS##*[! ]}"}" \
						"$1_LIBS = ${LIBS%"${LIBS##*[! ]}"}"
				;;
			esac
			shift
		done
		eval "set -- $MAKEFILE_DEFINES"
		for VAR do
			printf %s\\n "${VAR%%=*} = ${VAR#*=}"
		done

	} > "$outfile"
}

. qb/config.libs.sh
