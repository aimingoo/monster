#!/bin/bash

##################################################################################################
#- Monster - full or incremental static site generator for Ghost
#- Usage:
#-	> monster [update|generate|preview [port]] ...
#-	> monster [--init | --help | --version]
#- Example:
#-	> monster update --deploy-now
#- Default behavior:
#-	> monster generate --generate
#- Dependencies: buster, wget, git, sqlite3, jq, curl, sum
#- Version: 1.0.4
##################################################################################################

UPDATE_SITE=false
PREVIEW_SITE=false
GENERATE_SITE=false

## direct commands or --help
if [[ "$1" == "--help" ]]; then
	head -n 20 $0 | grep -Ee '^#-' | sed 's/^#-//'
	exit
fi
if [[ "$1" == "--version" ]]; then
	head -n 20 $0 | grep -Eie '^#-[ 	]*version[: 	]+' | grep -Eoe '[0-9]+\..*'
	exit
fi

## initialization configure
IN_DOMAIN=
IN_GITHUB_USER=
IN_GITHUB_TOKEN=
IN_DB=
IN_SITE=
IN_EMAIL=
function init_read_configure {
	while [[ -z "${IN_DOMAIN}" ]]; do
		read -p "Your Github name or domain: " IN_DOMAIN
	done
	IN_GITHUB_USER=${IN_DOMAIN%%.github.io}
	if [[ "${IN_GITHUB_USER}" == "${IN_DOMAIN}" ]]; then
		if [[ "${IN_DOMAIN}" =~ \. ]]; then ## has '.' char
			IN_GITHUB_USER=
		else
			IN_DOMAIN="${IN_GITHUB_USER}.github.io"
		fi
	fi

	read -p "Your Github access token, or Enter to skip: " IN_GITHUB_TOKEN

	read -p "Your Ghost local account(e-mail), or Enter to skip: " IN_EMAIL

	while true; do
		read -p "Your Ghost local .db file, or Enter to skip: " IN_DB
		IN_DB=$(sh -c "echo ${IN_DB}")
		if [ -z "${IN_DB}" -o -f "${IN_DB}" ]; then break; fi
	done

	read -p "Your Ghost site, or Enter set default [localhost:2368]: " IN_SITE
	if [[ -z "${IN_SITE}" ]]; then
		IN_SITE="http://localhost:2368"
	else
		IN_SITE=${IN_SITE%/}
		if [[ ${IN_SITE} =~ ^:[0-9]+$ ]]; then
			IN_SITE="http://localhost${IN_SITE}"
		elif [[ ! ${IN_SITE} =~ ^https*:// ]]; then
			IN_SITE="http://${IN_SITE}"
		fi
	fi
}

if [[ "$1" == "--init" ]]; then init_read_configure && cat > .monster <<_INITCONFIG
## Github domain
DOMAIN="${IN_DOMAIN}"

## Ghost .db file path
DB="${IN_DB}"

## Ghost site address
SITE="${IN_SITE}"

## Github account, and rate of api access
# 	- GITHUB_USER=$(git config --global github.user)
# 	- GITHUB_TOKEN=$(git config --global github.token)
GITHUB_USER="${IN_GITHUB_USER}"
GITHUB_TOKEN="${IN_GITHUB_TOKEN}"
GITHUB_APIRATE=1
GITHUB_PAGESIZE=100

## Other
EMAIL="${IN_EMAIL}"
PROTOCOL="https"

## Advertisement token string for your site
# AD_TOKEN=

## Default directory of static files
# STATIC_PATH="./static"

## Default behavior
# GENERATE_INFO=false
# SYNC_REMOVED=false
# PATCH_VERSION=true
# RESET_DOMAIN=true
# CHECK_STATIC=true
# SHORT_PATH=false

## Pick more files
# PICK_STATIC_TAGCLOUD=false
# PICK_STATIC_PROFILE=false
# PICK_ARCHIVES_POST=false
# PICK_ROBOTS_TXT=true
# PICK_SITEMAP=true
# FORCE=false

## Other override
# IGNORE_LIST=("archives-post" "author" "page" "rss" "tag" "assets" "content" "shared")
# ACCEPT_LIST=("assets" "content" "rss" "shared")
# VERDIR_LIST=("assets" "shared" "public")
_INITCONFIG
	echo "File .monster saved."

	GITIGNORE=".gitignore"
	if [[ -d .git/info ]]; then
		GITIGNORE=".git/info/exclude"
	fi
	echo -e '\nstatic/\npatchme.sh\nmonster.log\n.monster\n.sqlitedb' >> $GITIGNORE
	echo "File ${GITIGNORE} updated."

	exit
fi

## Check update or generate command
if [[ "$1" == "preview" ]]; then
	PREVIEW_SITE=true
	shift
elif [[ "$1" == "update" ]]; then
	UPDATE_SITE=true
	shift
else
	GENERATE_SITE=true
	if [[ "$1" == "generate" ]]; then
		shift
	elif [[ "${1:0:1}" != "-" ]]; then
		$0 --help
		exit
	fi
fi

## main command - preview
if $PREVIEW_SITE; then
	PYTHON=$(which python python2 python3 | head -n1)
	if [[ -z "$PYTHON" ]]; then
		echo "Where is Python?" && exit
	fi

	STATIC_PATH='./static'
	if [[ -f '.monster' ]]; then
		CONFIG_ITEM=$(grep -Ee '^STATIC_PATH=' '.monster')
		if [[ -n "$CONFIG_ITEM" ]]; then
			declare "${CONFIG_ITEM}"
		fi
	fi

	if [[ ! -d "${STATIC_PATH}" ]]; then
		echo "Where is static directory ${STATIC_PATH}?"
	else
		echo "Serving HTTP on localhost port ${1:-8000} ..."
		cd ${STATIC_PATH}
		${PYTHON} -m SimpleHTTPServer $@ >/dev/null 2>&1
		cd -
	fi
	exit
fi

## fake 'readlink -f'
# - https://stackoverflow.com/a/1116890
function readlink_f {
	local TARGET_FILE
	TARGET_FILE=$1

	pushd `dirname $TARGET_FILE` > /dev/null
	TARGET_FILE=`basename $TARGET_FILE`

	# Iterate down a (possible) chain of symlinks
	while [ -L "$TARGET_FILE" ]
	do
	    TARGET_FILE=`readlink $TARGET_FILE`
	    cd `dirname $TARGET_FILE`
	    TARGET_FILE=`basename $TARGET_FILE`
	done

	# Compute the canonicalized name by finding the physical path 
	# for the directory we're in and appending the target file.
	echo "`pwd -P`/$TARGET_FILE"
	popd > /dev/null
}

## get script path
# - https://stackoverflow.com/a/4774063
# 	> pushd `dirname $0` > /dev/null
pushd `dirname $(readlink_f "$0")` > /dev/null
SCRIPTPATH=`pwd -P`
popd > /dev/null

## other main commands
if $UPDATE_SITE; then
	bash "${SCRIPTPATH}/../libexec/updatesite.sh" $@
elif $GENERATE_SITE; then
	bash "${SCRIPTPATH}/../libexec/makesite.sh" $@
fi

## extra parament parser
PARAM_INDEX=0
for param; do
	let PARAM_INDEX++
	if [[ "$param" == "--preview" ]]; then
		shift $PARAM_INDEX
		$0 preview $@
		exit
	fi
done
