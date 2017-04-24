#!/bin/bash

# GIT LFS latest versions
GIT_OLDEST_SUPPORTED_VERSION="2.10.0"
LFS_OLDEST_SUPPORTED_VERSION="1.4.1"

# Version compare
function versionCompare () {
	# Default to a failed comparison result.
	local -i result=1;

	# Ensure there are two versions to compare.
	[ $# -lt 2 ] || [ -z "${1}" ] || [ -z "${2}" ] && echo "${FUNCNAME[0]} requires a minimum of two arguments to compare versions." &>/dev/stderr && return ${result}

	# Determine the operation to perform, if any.
	local op="${3}"

	# Convert passed versions into values for comparison.
	local v1=$(versionCompareConvert ${1})
	local v2=$(versionCompareConvert ${2})

	# Immediately return when comparing version equality (which doesn't require sorting).
	if [ -z "${op}" ]; then
		[ "${v1}" == "${v2}" ] && echo 0 && return;
	else
		if [ "${op}" == "!=" ] || [ "${op}" == "<>" ] || [ "${op}" == "ne" ]; then
			if [ "${v1}" != "${v2}" ]; then
				let result=0;
			fi;
			return ${result};
		elif [ "${op}" == "=" ] || [ "${op}" == "==" ] || [ "${op}" == "eq" ]; then
			if [ "${v1}" == "${v2}" ]; then
				let result=0;
			fi;
			return ${result};
		elif [ "${op}" == "le" ] || [ "${op}" == "<=" ] || [ "${op}" == "ge" ] || [ "${op}" == ">=" ] && [ "${v1}" == "${v2}" ]; then
			if [ "${v1}" == "${v2}" ]; then
				let result=0;
			fi;
			return ${result};
		fi
	fi

	# If we get to this point, the versions should be different.
	# Immediately return if they're the same.
	[ "${v1}" == "${v2}" ] && return ${result}

	local sort='sort'

	# If only one version has a pre-release label, reverse sorting so
	# the version without one can take precedence.
	[[ "${v1}" == *"-"* ]] && [[ "${v2}" != *"-"* ]] || [[ "${v2}" == *"-"* ]] && [[ "${v1}" != *"-"* ]] && sort="${sort} -r"

	# Sort the versions.
	local -a sorted=($(printf "%s\n%s" "${v1}" "${v2}" | ${sort}))

	# No operator passed, indicate which direction the comparison leans.
	if [ -z "${op}" ]; then
		if [ "${v1}" == "${sorted[0]}" ]; then
			echo -1;
		else
			echo 1;
		fi
		return
	fi

	case "${op}" in
		"<" | "lt" | "<=" | "le") if [ "${v1}" == "${sorted[0]}" ]; then let result=0; fi;;
		">" | "gt" | ">=" | "ge") if [ "${v1}" == "${sorted[1]}" ]; then let result=0; fi;;
	esac
	return ${result}
}

# Converts a version string to an integer that is used for comparison purposes.
function versionCompareConvert () {
	local version="${@}"

	# Remove any build meta information as it should not be used per semver spec.
	version="${version%+*}"

	# Extract any pre-release label.
	local prerelease
	[[ "${version}" = *"-"* ]] && prerelease=${version##*-}
	[ -n "${prerelease}" ] && prerelease="-${prerelease}"

	version="${version%%-*}"

	# Separate version (minus pre-release label) into an array using periods as the separator.
	local OLDIFS=${IFS} && local IFS=. && version=(${version%-*}) && IFS=${OLDIFS}

	# Unfortunately, we must use sed to strip of leading zeros here.
	local major=$(echo ${version[0]:=0} | sed 's/^0*//')
	local minor=$(echo ${version[1]:=0} | sed 's/^0*//')
	local patch=$(echo ${version[2]:=0} | sed 's/^0*//')
	local build=$(echo ${version[3]:=0} | sed 's/^0*//')

	# Combine the version parts and pad everything with zeros, except major.
	printf "%04d%04d%04d%04d%s\n" "${major}" "${minor}" "${patch}" "${build}" "${prerelease}"
}


#----------------#
# MAIN MAIN MAIN #
#----------------#

GIT_VERSION="$(git version | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')"
LFS_VERSION="$(git lfs version | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')"

git_cmp="$(versionCompare $GIT_VERSION $GIT_OLDEST_SUPPORTED_VERSION)"

if [ $git_cmp -lt 0 ]; then
	echo "Your git ${GIT_VERSION} is lower than the oldest supported version ($GIT_OLDEST_SUPPORTED_VERSION). Please upgrade git"
	exit
fi

lfs_cmp="$(versionCompare $LFS_VERSION $LFS_OLDEST_SUPPORTED_VERSION)"

if [ $lfs_cmp -lt 0 ]; then
	echo "Your git-lfs ${LFS_VERSION} is lower than the oldest supported version ($LFS_OLDEST_SUPPORTED_VERSION). Please upgrade git-lfs"
	exit
fi

echo "running git-submodule setup"
git submodule init
git submodule update
