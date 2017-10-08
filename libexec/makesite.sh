#!/bin/bash

##################################################################################################
#- Monster module - makesite.sh
#- Usage:
#-	> bash makesite.sh [--generate --reset-domain --short-path --deploy-now]
#-	> bash makesite.sh [--pick-sitemap=false --patch-version=false --check-static=false]
#-	> bash makesite.sh [--help | --version]
#- Example:
#-	> bash makesite.sh --generate --reset-domain=false --pick-sitemap=false
#- Note:
#-  > param switch: --paramName=paramValue, default paramValue is true
#-	- Have a '--domain' parament to set you domain address
#-	- Have a '--generate-info' sub-option for '--generate' to show more
#-	- By default(all options off), the script will check files in ./static/
#- Dependencies: wget, git
#- Version: 1.0.5
##################################################################################################

## default setting
SITE="http://localhost:2368"
STATIC_PATH="./static"
DOMAIN=""
GENERATE=false
GENERATE_INFO=false
PICK_SITEMAP=true
PATCH_VERSION=true
RESET_DOMAIN=true
SHORT_PATH=false
CHECK_STATIC=true
DEPLOY_NOW=false

## check dependencies
# - https://gist.github.com/terencewestphal/8b9101e86928c0054a518de262b80a77
function dependency {
  for executable in "$@"; do
    ! type ${executable} >/dev/null 2>&1 && \
    printf "Dependency not installed: ${executable}\n" 1>&2 && return 1
  done
  return 0
}

## direct commands or --help
for param; do
	if [[ "$param" == "--help" ]]; then
		head -n 20 $0 | grep -Ee '^#-' | sed 's/^#-//'
		exit
	fi
	if [[ "$param" == "--version" ]]; then
		head -n 20 $0 | grep -Eie '^#-[ 	]*version[: 	]+' | grep -Eoe '[0-9]+\..*'
		exit
	fi
done

## check dependencies
if ! dependency wget; then
	echo "The makesite.sh abort."
	exit
fi

## load monster configure
#	- with other variant override
IGNORE_LIST=("archives-post" "about" "author" "page" "rss" "tag" "assets" "content" "shared")
VERDIR_LIST=("assets" "shared" "public")
if [[ -f "./.monster" ]]; then
	source ./.monster
fi

## proess arguments
for param; do
	declare $(echo ${param%%=*} | tr '[a-z]' '[A-Z]' | sed 's/^--*//; s/-/_/g')=$(expr "$param" : '.*=\(.*\)' \| true)
done

## check configures
if [[ -z "$DOMAIN" ]]; then
	echo "Configure file .monster lost, or pass --DOMAIN parament please."
	echo "Or run 'monster --init' first."
	exit
fi

## sed -i, compatible macosx and gnu
if sed --version 2>&1 | grep -q 'illegal option'; then
	function sed_inplace { local INPLACE_FILE="$1"; shift; sed -i '' -e "$*" "$INPLACE_FILE"; }
	function sed_inplace_E { local INPLACE_FILE="$1"; shift; sed -i '' -Ee "$*" "$INPLACE_FILE"; }
	function sed_inplace_all { while read -r INPLACE_FILE; do sed -i '' -e "$*" "$INPLACE_FILE"; done }
	function sed_inplace_all_E { while read -r INPLACE_FILE; do sed -i '' -Ee "$*" "$INPLACE_FILE"; done }
else
	function sed_inplace { local INPLACE_FILE="$1"; shift; sed -i'' -e "$*" "$INPLACE_FILE"; }
	function sed_inplace_E { local INPLACE_FILE="$1"; shift; sed -i'' -Ee "$*" "$INPLACE_FILE"; }
	function sed_inplace_all { while read -r INPLACE_FILE; do sed -i'' -e "$*" "$INPLACE_FILE"; done }
	function sed_inplace_all_E { while read -r INPLACE_FILE; do sed -i'' -Ee "$*" "$INPLACE_FILE"; done }
fi

SITEADDR="${SITE##*://}"
SITEREGX="\\(https*://\\)${SITEADDR}"

## call wget to generate site
if [[ "$GENERATE" == "true" ]]; then
	function wget_buster {
		wget --recursive --convert-links --page-requisites --no-parent --directory-prefix="${STATIC_PATH}" \
			--no-host-directories --restrict-file-name=unix $@
	}
	# generate static site
	echo -e "\033[0;32mGenerate your static site...\033[0m"
	if [[ "$GENERATE_INFO" == "true" ]]; then
		wget_buster -l inf --reject-regex='\/amp\/$|\/tag\/.*[^\/]$' "${SITE}"
	else
		wget_buster -l inf --reject-regex='\/amp\/$|\/tag\/.*[^\/]$' "${SITE}" 2>&1 | tee monster.log | cut -c 1-70 | xargs -L 1 -I{} printf '\r> %-73s' '{}'; printf "\n"
		cat monster.log |\
			grep -Eie '^(FINISHED|Total wall clock time|Downloaded:|Converted links in|--\d+-\d+-\d+ )|failed:|error[ 0-9:]*' |\
			grep -B1 -Eve '^(--|FINISHED)' | grep --color -Eie 'failed:|error[ 0-9:]*|$'
	fi
fi

# directory exist?
if [[ ! -d "${STATIC_PATH}" ]]; then
	echo "Abort because have not '${STATIC_PATH}' directory."
	exit 1
fi

# try copy sitemap files
if [[ "$PICK_SITEMAP" == "true" ]]; then
	echo -e "\033[0;32mCopy sitemap files...\033[0m"
	wget -N -q --directory-prefix "${STATIC_PATH}" ${SITE}/sitemap.xsl
	wget -N -q --directory-prefix "${STATIC_PATH}" ${SITE}/sitemap.xml
	wget -N -q --directory-prefix "${STATIC_PATH}" ${SITE}/sitemap-pages.xml
	wget -N -q --directory-prefix "${STATIC_PATH}" ${SITE}/sitemap-posts.xml
	wget -N -q --directory-prefix "${STATIC_PATH}" ${SITE}/sitemap-authors.xml
	wget -N -q --directory-prefix "${STATIC_PATH}" ${SITE}/sitemap-tags.xml
fi

# fix versions for assets file
if [[ "$PATCH_VERSION" == "true" ]]; then
	echo -e "\033[0;32mPatching versions...\033[0m"
	for VERDIR in ${VERDIR_LIST[@]}; do
		if [[ -d "${STATIC_PATH}/${VERDIR}" ]]; then
			find "${STATIC_PATH}/${VERDIR}" -name '*\?*' -type f -exec sh -c "echo '{}' | sed 's|\?.*$||' | xargs -I[] mv '{}' '[]'" \;
		fi
	done
fi

# reset domain
if [[ "$RESET_DOMAIN" == "true" ]] && [[ "$SITEADDR" != "$DOMAIN" ]]; then
	# remove amp/canonical/editor links
	sed_inplace_all_E \
'/<link rel="(canonical|amphtml)"/d;'\
's/<a href="[^"]*\/ghost\/editor\/[^>]*>[^>]*>//g'\
	< <(find "${STATIC_PATH}" -name "*.html" -type f)

	# fix domain and other issues
	echo -e "\033[0;32mPatching domain and other issues...\033[0m"
	sed_inplace_all \
's|u='${SITEREGX}'|u=\1'${DOMAIN}'|g;'\
's|url='${SITEREGX}'|url=\1'${DOMAIN}'|g;'\
's|href="'${SITEREGX}'|href="\1'${DOMAIN}'|g;'\
's|src="'${SITEREGX}'|src="\1'${DOMAIN}'|g;'\
's|link>'${SITEREGX}'|link>\1'${DOMAIN}'|g;'\
's|'${SITEREGX}'|\1'${DOMAIN}'|g'\
	< <(find "${STATIC_PATH}" -name "*.html" -type f)

	sed_inplace_all \
's|'${SITEREGX}'|\1'${DOMAIN}'|g'\
	< <(find "${STATIC_PATH}" -name "*.xsl" -type f)

	sed_inplace_all \
's|href="//'${SITEADDR}'|href=//"'${DOMAIN}'|g;'\
's|loc>'${SITEREGX}'|loc>\1'${DOMAIN}'|g' \
	< <(find "${STATIC_PATH}" -name "*.xml" -type f)

	if [[ -d "${STATIC_PATH}/shared" ]]; then
		sed_inplace_all 's|//'${SITEADDR}'|//'${DOMAIN}'|g'\
		< <(find "${STATIC_PATH}/shared" -name "*.js" -type f)
	fi
	if [[ -d "${STATIC_PATH}/rss" ]]; then
		sed_inplace_all 's|'${SITEREGX}'|\1'${DOMAIN}'|g'\
		< <(find "${STATIC_PATH}/rss" -name "*.rss" -type f)
	fi
	if [[ -f "${STATIC_PATH}/robots.txt" ]]; then
		sed_inplace "${STATIC_PATH}/robots.txt" 's|'${SITEREGX}'|\1'${DOMAIN}'|g'
	fi
	sed_inplace_all 's|'${SITEREGX}'|\1'${DOMAIN}'|g'\
	< <(find "${STATIC_PATH}" -name "tag-cloud" -type f)

	echo -e "\033[0;32mRemove .1 files ...\033[0m"
	find "${STATIC_PATH}" -type f -depth 1 -name '*.?' | grep '[0-9]$' | xargs -L1 -I{} rm '{}'
fi

# folder to static file
if [[ "$SHORT_PATH" == "true" ]]; then
	echo -e "\033[0;32mConvert to short filename ...\033[0m"
	total=$(find "${STATIC_PATH}" -type d -depth 1 | wc -l | sed 's/^ *//g')
	current=0
	declare -a all_posts
	while read -r name; do
		let current+=1
		if [[ -f "$name/index.html" ]]; then
			## HRADCODE BEGIN
			short_name=${name##${STATIC_PATH}/}
			if [[ " ${IGNORE_LIST[@]} " =~ " ${short_name} " ]]; then continue; fi
			## HRADCODE END
			printf "\r[%${#total}d/%d] Process ${name}.html" ${current} ${total}

			## move file to parent
			mv "$name/index.html" "${name}.html"
			rm -rf "$name"
			## cut "../" from links
			##	1) "./index.html" or "index.html" => "${short_name}.html"
			##	2) "../" ==> "index.html"
			##	3) "../others ==> "others
			sed_inplace_E "${name}.html" "s/(\"|')(\\.\\/){0,1}index\\.html/\1${short_name}.html/g; s/(\"|')\\.\\.\\/(\"|')/\1index.html\2/g; s/(\"|')\\.\\.\\//\\1/g"
			## replace $short_name in all .html files
			# 	- find "${STATIC_PATH}" -name '*.html' -type f -print0 | xargs -n1 -I{} -0 \
			# 	-	sed -i'' -Ee "s#([\"'/]$short_name)/*((\.[0-9])*(['\"/])|index\\.html)#\\1.html\\4#g" '{}'
			all_posts+=("${short_name}")
		fi
	done < <(find "${STATIC_PATH}" -type d -depth 1)

	function join { local IFS="$1"; shift; echo "$*"; }
	posts=$(join '|' "${all_posts[@]}")
	sed_inplace_all_E "s#([\"'/](${posts}))/*((\.[0-9])*(['\"/])|index\\.html)#\\1.html\\5#g"\
		< <(find "${STATIC_PATH}" -name '*.html' -type f)

	printf "\n"
fi

# check static directory
if [[ "$CHECK_STATIC" == 'true' ]] && [[ "$SITEADDR" != "$DOMAIN" ]]; then
	INVALID=$(find "${STATIC_PATH}" -type f -print0 | xargs -n1 -0 grep -Hl "=[ '\"]*[^/]*/*${SITEADDR}")
	if [[ -n "$INVALID" ]]; then
		echo "Include hyperlink point to <$SITEADDR> in next files:"
		echo "$INVALID" | xargs -n1 echo "  - "
		echo "Abort."
		exit 2
	fi
fi

# and deploy or nothing
if [[ "$DEPLOY_NOW" == 'true' ]]; then
	# patch my site
	if [[ -f './patchme.sh' ]]; then
		source ./patchme.sh
	fi

	if ! dependency git; then
		echo "The makesite.sh abort."
		exit
	fi

	# finished
	echo -e "\033[0;32mCopy static files to Local git...\033[0m"
	cp -rfv "${STATIC_PATH}/" ./ | cut -c 1-70 | xargs -L 1 -I{} printf '\r> %-73s' '{}'
	printf "\n"
	rm -rf "${STATIC_PATH}"

	# Add changes to git
	echo -e "\033[0;32mCommit and Sync to Git...\033[0m"
	git add *

	# Commit changes
	msg="rebuilding site `date`"
	git commit -m "$msg"

	# Push source and build repos
	git push
fi

echo Done.
