#!/bin/sh

# Program Data
PROGRAM_NAME="ct"
ALT_PROGRAM_NAME="create-template"
LICENSE="GNU GPLv3"
VERSION="1.1"
AUTHOR="Hamza Kerem Mumcu <hamzamumcu@protonmail.com>"
USAGE="Usage: $PROGRAM_NAME [-g|--generate] [-n|--no-edit] [-m|--make-executable]
[-q|--quiet] [-s|--no-messages] [-h|--help] [-v|--version] FILE [TEMPLATE]"

# Configuration Data
config_dir="$HOME/.config/$PROGRAM_NAME"
config_file="$config_dir/.$PROGRAM_NAME.conf"
info_file="$config_dir/.$PROGRAM_NAME.info"
def_permissions="755"
# Assign editor to be $EDITOR or to vim if $EDITOR is empty 
editor="${EDITOR:-vim}" 

cleanup(){
	[ -f "$stdin_tmp_file" ] && rm "$stdin_tmp_file"
	[ -f "$config_tmp_file" ] && rm "$config_tmp_file"
	[ -f "$filename_tmp_file" ] && rm "$filename_tmp_file"
}

err(){
	# Print error message, "$1", to stderr and exit.
	[ "$suppress_bool" -ne 0 ] && printf "%s Exitting.\n" "$1" >&2
	cleanup
	exit 1
}

warn(){
	# Print warning message, "$1", to stderr. Don't exit.
	[ "$quiet_bool" -ne 0 ] && printf "%s\n" "$1" >&2
	return 1
}

show_help(){
	# Print program usage.
	printf "%s\n" "$USAGE"	
	if [ -f "$info_file" ]; then
		printf "\n"
		cat "$info_file" || err "Failed to display $info_file"
	fi
	cleanup
	exit 0
}

show_version(){
	# Print program version info.
	printf "%s\n" "$PROGRAM_NAME - $ALT_PROGRAM_NAME $VERSION"
	printf "Licensed under %s\n" "$LICENSE"
	printf "Written by %s\n" "$AUTHOR"
	cleanup
	exit 0
}

get_ext(){
	file="$1"
	[ -z "$file" ] && return 1
	
	strlen="${#file}"
	dot_index=-1
	i=$((strlen-1))
	
	# Get dot index
	while [ "$i" -gt -1 ]; do
		char="$(printf "%s" "$file" | cut -b $((i+1)))"
		[ "$char" = '.' ] && dot_index="$i" && break
		i=$((i-1))
	done
	
	[ "$dot_index" -eq -1 ] && return 1

	# Get filename without extension
	i=1
	while [ "$i" -le "$dot_index" ]; do
		char="$(printf "%s" "$file" | cut -b $i)"
		file_name="${file_name}${char}"
		i=$((i+1))
	done

	# Get extension
	i=$((dot_index+2))
	while [ "$i" -le "$strlen" ]; do
		char="$(printf "%s" "$file" | cut -b $i)"
		file_ext="${file_ext}${char}"
		i=$((i+1))
	done	
}

get_line(){
	
	local_file="$1"
	local_line_num="$2"
	i=1
	
	while read -r line; do
		[ "$i" -eq "$local_line_num" ] && printf "%s" "$line"
		i=$((i+1))	
	done < "$local_file"
}

process_filename(){
		
	while read -r line; do
		if [ -z "$file_name" ] && [ -z "$file_ext" ]; then
			# if file exists, don't overwrite! Exit instead.
			[ -f "$line" ] && err "File $line exists. Refusing to overwrite."

			get_ext "$line"
			stdin_tmp_file="$(mktemp)"
		else
			# Write passed template names to a temp. file
			printf "%s\n" "$line" >> "$stdin_tmp_file"	
		fi
	done < "$filename_tmp_file"
}

parse_opts(){
	# Parse and evaluate each option one by one 
	quiet_bool=1
	suppress_bool=1
	generate_bool=1
	no_edit_bool=1
	make_exe_bool=1
	file_name=
	file_ext=
	stdin_tmp_file=
	filename_tmp_file="$(mktemp)"
	
	while [ "$#" -gt 0 ]; do
		case "$1" in
			-n|--no-edit) no_edit_bool=0;;
			-m|--make-executable) make_exe_bool=0;;
			-g|--generate) generate_bool=0;;
			-h|--help) show_help;;
			-v|--version) show_version;;
			-q|--quiet) quiet_bool=0;;	
			-s|--no-messages) suppress_bool=0;;	
			--) break;;
			-*) err "Unknown option. Please see '--help'.";;
			*)  printf "%s\n" "$1" >> "$filename_tmp_file";;
		esac
		shift
	done
	
	# Process filnames	
	process_filename

	# Error checking. 
	if [ "$generate_bool" -ne 0 ] && { [ -z "$file_name" ] || [ -z "$file_ext" ]; }; then
		err "Failed to process file name and extension. Input file must have an extension."
	fi
}

read_config(){
	[ -r "$config_file" ] || err "Failed to read $config_file. Please create the configuration file if you haven't done so."
	found_lang_bool=1
	line_num=0

	# truncate info_file if '--generate' is passed
	[ "$generate_bool" -eq 0 ] && printf "" > "$info_file"

	while read -r line; do
		line_num=$((line_num+1))

		# remove all whitespace
		line="$(printf "%s" "$line" | tr -d '[:space:]')"
		# check if line is a comment, if so continue on with next iteration
		[ "$(printf "%s" "$line" | cut -b 1)" = "#" ] && continue
		# check if line is empty, if so continue on with next iteration
		[ "$line" = "" ] && continue

		# Get variable values from config file.
		# The extension given in the second field is recieved and compared to 
		# the passed file's extension. If they do not match, continue on with next line.
		read_extension="$(printf "%s" "$line" | cut -d ':' -f 2)"
		[ "$generate_bool" -ne 0 ] && [ -n "$read_extension" ] && { [ "$file_ext" = "$read_extension" ] || continue; }
		read_lang_full="$(printf "%s" "$line" | cut -d ':' -f 1)"
		
		# Raise error if empty value is met
		if [ -z "$read_extension" ] || [ -z "$read_lang_full" ]; then
				err "Empty values detected in $config_file on line $line_num."
		fi

		# Generate neccessary directories and write language name to info_file 
		if [ "$generate_bool" -eq 0 ]; then
			[ ! -d "$config_dir/$read_lang_full" ] && mkdir "$config_dir/$read_lang_full"
			printf "%s" "${read_lang_full}: " >> "$info_file"
		fi


		# Get configuration file templates
		config_tmp_file="$(mktemp)"
		i=3
		while true; do
			template="$(printf "%s" "$line" | cut -d ':' -f $i)"
			[ -z "$template" ] && break

			# Generate neccessary directories 
			if [ "$generate_bool" -eq 0 ]; then 
				[ ! -f "$config_dir/$read_lang_full/$template" ] && printf "" > "$config_dir/$read_lang_full/$template"
				printf "%s" "${template} " >> "$info_file"	
			fi

			printf "%s\n" "$template" >> "$config_tmp_file"	

			i=$((i+1))
		done

		found_lang_bool=0
		if [ "$generate_bool" -eq 0 ]; then
			printf "\n" >> "$info_file"
		else
			break
		fi

	done < "$config_file"

	[ "$generate_bool" -ne 0 ] && [ "$found_lang_bool" -ne 0 ] && err "Language belonging to extension .$file_ext was not found."
}

apply_templates(){

	# Check if passed templates match configuration file templates.
	# If they do append template files to target file in the order they were
	# passed in. If not, raise warning.
	
	file="${file_name}.${file_ext}"

	while read -r line; do
		if grep -qx "$line" "$config_tmp_file"; then
			cat "$config_dir/$read_lang_full/$line" >> "$file" 
		elif printf "%s" "$line" | grep -Ewq '^([0-9]+)$'; then
			template="$(get_line "$config_tmp_file" $((line+1)))"
			if [ -n "$template" ]; then
				cat "$config_dir/$read_lang_full/$template" >> "$file" 
			else
				warn "Template $line is not a valid template index. Skipping."
			fi
		else
			warn "Template $line is not a valid template name. Skipping."
		fi
	done < "$stdin_tmp_file"

	# If user passed no templates, assume the default template (first template in the config file)
	# will be used. 
	template=
	if [ "$(wc --bytes "$stdin_tmp_file" | cut -b 1)"	= "0" ]; then
		template="$(get_line "$config_tmp_file" 1)"
		cat "$config_dir/$read_lang_full/$template" >> "$file"
	fi

	# Replace neccessary parts of the file
	sed -i "s/\$file/$file_name/g" "$file" 2> /dev/null || warn "Failed to search and replace using sed."

	[ "$make_exe_bool" -eq 0 ] && chmod "$def_permissions" "$file"
	[ "$no_edit_bool" -ne 0 ] && "$editor" "$file"

}

parse_opts "$@"

read_config

[ "$generate_bool" -ne 0 ] && apply_templates

cleanup
