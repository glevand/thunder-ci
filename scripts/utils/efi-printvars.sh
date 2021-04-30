#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} - Print EFI variables." >&2
	echo "Usage: ${script_name} [flags]" >&2
	echo "Option flags:" >&2
	echo "  -h --help        - Show this help and exit." >&2
	echo "  -v --verbose     - Verbose execution." >&2
	echo "  -g --debug       - Extra verbose execution." >&2
	echo "Send bug reports to: Geoff Levand <geoff@infradead.org>." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="hvg"
	local long_opts="help,verbose,debug"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-h | --help)
			usage=1
			shift
			;;
		-v | --verbose)
			verbose=1
			shift
			;;
		-g | --debug)
			verbose=1
			debug=1
			set -x
			shift
			;;
		--)
			shift
			if [[ ${*} ]]; then
				set +o xtrace
				echo "${script_name}: ERROR: Got extra args: '${*}'" >&2
				usage
				exit 1
			fi
			break
			;;
		*)
			echo "${script_name}: ERROR: Internal opts: '${*}'" >&2
			exit 1
			;;
		esac
	done
}

on_exit() {
	local result=${1}

	set +x
	echo "${script_name}: Done: ${result}" >&2
}

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}):\[\e[0m\] '
script_name="${0##*/}"
base_name="${script_name##*/%}"
base_name="${base_name%.sh}"

SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd)"}

start_time="$(date +%Y.%m.%d-%H.%M.%S)"
SECONDS=0

trap "on_exit 'failed.'" EXIT
set -o pipefail
set -e

source "${SCRIPTS_TOP}/../tdd-lib/util.sh"

process_opts "${@}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

efivar="${efivar:-efivar}"
efibootmgr="${efibootmgr:-efibootmgr}"

if ! check_progs "${efivar} ${efibootmgr}"; then
	exit 1
fi

readarray -t list < <("${efivar}" --list | sort)
sleep 0.1

host="$(hostname)"

echo '' >&1
echo "Generated by ${script_name} (TDD Project) - ${start_time}" >&1
echo "https://github.com/glevand/tdd-project" >&1
echo "Host '${host//[$'\t\r\n ']}'" >&1
echo '' >&1

start=1
echo "==============================================================================" >&1

for i in "${list[@]}"; do
	if [[ ${start} ]]; then
		unset start
	else
		echo "------------------------------------------------------------------------------" >&1
	fi
	"${efivar}" --print --name="${i}"
	sleep 0.1
done

echo "==============================================================================" >&1
"${efibootmgr}" -v
echo "==============================================================================" >&1

trap "on_exit 'Success.'" EXIT
exit 0

