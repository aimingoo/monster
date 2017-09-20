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
#- Dependencies: buster, wget, git
#- Version: 1.0.3
##################################################################################################

## default setting
SITE="http://localhost:2368"
STATIC_PATH="./static"
DOMAIN=""
GENERATE=false
GENERATE_INFO=false
RESET_DOMAIN=true
SHORT_PATH=false
DEPLOY_NOW=false
PICK_SITEMAP=true
PATCH_VERSION=true
CHECK_STATIC=true

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
if ! dependency buster wget; then
	echo "The makesite.sh abort."
	exit
fi

## load monster configure
#	- with other variant override
IGNORE_LIST=("archives-post" "author" "page" "rss" "tag" "assets" "content" "shared")
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

SITEADDR="${SITE##*://}"
SITEREGX="\\(https*://\\)${SITEADDR}"

## call buster to generate site
if [[ "$GENERATE" == "true" ]]; then
	function wget { $RAW_WGET -l inf --reject-regex='\/amp\/$|\/tag\/.*[^\/]$' $@; }
	# function wget { $RAW_WGET -l inf --adjust-extension $@; }
	export RAW_WGET=`which wget`
	export -f wget
	# generate static site
	echo -e "\033[0;32mGenerate your static site...\033[0m"
	if [[ "$GENERATE_INFO" == "true" ]]; then
		buster generate --dir="${STATIC_PATH}" --domain="${SITE}"
	else
		buster generate --dir="${STATIC_PATH}" --domain="${SITE}" 2>&1 | tee monster.log | cut -c 1-70 | xargs -L 1 -I{} printf '\r> %-73s' '{}'; printf "\n"
		cat monster.log |\
			grep -Eie '^(FINISHED|Total wall clock time|Downloaded:|Converted links in|--\d+-\d+-\d+ )|failed:|error[ 0-9:]*' |\
			grep -B1 -Eve '^(--|FINISHED)' | grep --color -Eie 'failed:|error[ 0-9:]*|$'
	fi
fi

# Try copy sitemap files
if [[ -d "${STATIC_PATH}" ]]; then
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
else
	echo "Abort because have not '${STATIC_PATH}' directory."
	exit 1
fi

if [[ "$RESET_DOMAIN" == "true" ]] && [[ "$SITEADDR" != "$DOMAIN" ]]; then
	# remove amp/canonical/editor links
	find "${STATIC_PATH}" -name "*.html" -type f -exec sed -i '' -E \
'/<link rel="(canonical|amphtml)"/d;'\
's/<a href="[^"]*\/ghost\/editor\/[^>]*>[^>]*>//g'\
	'{}' \;

	# fix domain and other issues
	echo -e "\033[0;32mPatching domain and other issues...\033[0m"
	find "${STATIC_PATH}" -name "*.html" -type f -exec sed -i '' \
's|u='${SITEREGX}'|u=\1'${DOMAIN}'|g;'\
's|url='${SITEREGX}'|url=\1'${DOMAIN}'|g;'\
's|href="'${SITEREGX}'|href="\1'${DOMAIN}'|g;'\
's|src="'${SITEREGX}'|src="\1'${DOMAIN}'|g;'\
's|link>'${SITEREGX}'|link>\1'${DOMAIN}'|g;'\
's|'${SITEREGX}'|\1'${DOMAIN}'|g'\
	'{}' \;
	find "${STATIC_PATH}" -name "*.xsl" -type f -exec sed -i '' 's|'${SITEREGX}'|\1'${DOMAIN}'|g' '{}' \;
	find "${STATIC_PATH}" -name "*.xml" -type f -exec sed -i '' \
's|href="//'${SITEADDR}'|href=//"'${DOMAIN}'|g;'\
's|loc>'${SITEREGX}'|loc>\1'${DOMAIN}'|g'\
	'{}' \;

	if [[ -d "${STATIC_PATH}/shared" ]]; then
		find "${STATIC_PATH}/shared" -name "*.js" -type f -exec sed -i '' 's|//'${SITEADDR}'|//'${DOMAIN}'|g' '{}' \;
	fi
	if [[ -d "${STATIC_PATH}/rss" ]]; then
		find "${STATIC_PATH}/rss" -name "*.rss" -type f -exec sed -i '' 's|'${SITEREGX}'|\1'${DOMAIN}'|g' '{}' \;
	fi
	if [[ -f "${STATIC_PATH}/robots.txt" ]]; then
		sed -i '' 's|'${SITEREGX}'|\1'${DOMAIN}'|g' "${STATIC_PATH}/robots.txt"
	fi
	find "${STATIC_PATH}" -name "tag-cloud" -type f -exec sed -i '' 's|'${SITEREGX}'|\1'${DOMAIN}'|g' '{}' \;

	echo -e "\033[0;32mRemove .1 files ...\033[0m"
	find "${STATIC_PATH}" -type f -depth 1 -name '*.?' | grep '[0-9]$' | xargs -L1 -I{} rm '{}'
fi

# recheck
if [[ "$CHECK_STATIC" == 'true' ]] && [[ "$SITEADDR" != "$DOMAIN" ]]; then
	INVALID=$(find "${STATIC_PATH}" -type f -print0 | xargs -n1 -0 grep -Hl "=[ '\"]*[^/]*/*${SITEADDR}")
	if [[ -n "$INVALID" ]]; then
		echo "Include hyperlink point to <$SITEADDR> in next files:"
		echo "$INVALID" | xargs -n1 echo "  - "
		echo "Abort."
		exit 2
	fi
fi

# folder to static file
if [[ "$SHORT_PATH" == "true" ]]; then
	echo -e "\033[0;32mConvert to short filename ...\033[0m"
	total=$(find "${STATIC_PATH}" -type d -depth 1 | wc -l | sed 's/^ *//g')
	current=0
	declare -a all_posts
	find "${STATIC_PATH}" -type d -depth 1 | while read -r name; do
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
			sed -i '' -E "s/(\"|')(\\.\\/){0,1}index\\.html/\1${short_name}.html/g; s/(\"|')\\.\\.\\/(\"|')/\1index.html\2/g; s/(\"|')\\.\\.\\//\\1/g" "${name}.html"
			## replace $short_name in all .html files
			# 	- find "${STATIC_PATH}" -name '*.html' -type f -print0 | xargs -n1 -I{} -0 \
			# 	-	sed -i '' -E "s#([\"'/]$short_name)/*((\.[0-9])*(['\"/])|index\\.html)#\\1.html\\4#g" '{}'
			all_posts+=("${short_name}")
		fi
	done

	function join { local IFS="$1"; shift; echo "$*"; }
	posts=$(join '|' "${all_posts[@]}")
	find "${STATIC_PATH}" -name '*.html' -type f -print0 | xargs -n1 -I{} -0 \
		sed -i '' -E "s#([\"'/](${posts}))/*((\.[0-9])*(['\"/])|index\\.html)#\\1.html\\5#g" '{}'

	printf "\n"
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