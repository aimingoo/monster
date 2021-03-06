#!/bin/bash

##################################################################################################
#- Monster module - updatesite.sh
#- Usage:
#-	> bash updatesite.sh [--deploy-now] [--sync-removed --reset-domain=false --short-path=false]
#-	> bash updatesite.sh [--sync-slug | --sync-issue | --list <unment|user>] [--init [checksums]]
#-	> bash updatesite.sh [--deploy-only | --search <key> | --help | --version]
#- Note:
#-  > param switch: --paramName=paramValue, default paramValue is true
#-	- config for "--list unment" and "--sync-issue":
#-		GITHUB_PAGESIZE=xxx : set page size
#-	- paraments for "--sync-removed":
#-		--email=xxx     : set author's email of his account
#- Dependencies: sqlite3, jq, wget, curl, sum
#- Version: 1.0.7
##################################################################################################

SITE="http://localhost:2368"
STATIC_PATH="./static"
DB=""
EMAIL=""
DOMAIN=""
PROTOCOL="https"

# deploy action
DEPLOY_NOW=false
DEPLOY_ONLY=false
SYNC_REMOVED=false
SHORT_PATH=true
RESET_DOMAIN=true
ALWAYS_SYNC_SLUG=false

# pick more files...
PICK_STATIC_TAGCLOUD=false
PICK_STATIC_PROFILE=false
PICK_ARCHIVES_POST=false
PICK_ROBOTS_TXT=true
PICK_SITEMAP=true
FORCE=false

GITHUB_USER=""
GITHUB_TOKEN=""
GITHUB_APIRATE=1
GITHUB_PAGESIZE=100

ACCEPT_LIST=("assets" "content" "rss" "shared" "public")
FORCEPAGE_LIST=()
FORCEINDEX_LIST=("about" "archives-post")

## check dependencies
# - https://gist.github.com/terencewestphal/8b9101e86928c0054a518de262b80a77
function dependency {
  for executable in "$@"; do
    ! type ${executable} >/dev/null 2>&1 && \
    printf "Dependency not installed: ${executable}\n" 1>&2 && return 1
  done
  return 0
}

function get_labled_list {
	if ! dependency jq; then
		echo "The updatesite.sh abort."
		exit
	fi

	echo -e "\033[0;32mTry max pages ...\033[0m" 1>&2
	page_last=$(curl -s -I -X GET "https://api.github.com/repos/${GITHUB_USER}/${DOMAIN:-${GITHUB_USER}.github.io}/issues?page=1&per_page=${GITHUB_PAGESIZE}" |\
		grep '^Link:' | grep -Eoe '<[^<]*rel="last"' | sed 's/<\(.*\)>.*$/\1/')
	page_max=$(echo "${page_last}" | sed 's/.*\?page=\([0-9]*\)&.*/\1/')
	page_url="${page_last%%\?*}"
	labled=()
	for i in $(seq 1 ${page_max}); do
		printf "\r -> try page %d/%d" ${i} ${page_max} 1>&2

		sleep ${GITHUB_APIRATE}
		labled+=(`curl -s "${page_url}?page=${i}&per_page=${GITHUB_PAGESIZE}" |\
			jq '.[] | select(.labels[].name=="gitment") | .labels[] | select(.name!="gitment").name' | xargs`)
	done
	echo ", Done." 1>&2
	echo "${labled[@]}"
}

function get_checksums {
	find "${STATIC_PATH}" -name '*.html' | xargs -n1 grep -Eoe '"[^"]*?v=[0-9a-f]*"' |\
			sed 's|\.\./||g; s|\./||g' | sort | uniq | xargs -n1 -I{} curl --silent "${SITE}{}" | sum
}

## 0.11.x or lowness
##	- displayUpdateNotification	0.11.11
##	- databaseVersion	009
## 1.x or higher
##	- display_update_notification	1.12.1
function get_ghost_version {
	local where_setting='where key in ("displayUpdateNotification", "display_update_notification")'
	echo $(sqlite3 "${DB}" "select value from settings ${where_setting} limit 1")
}

function try_sync_slug {
	where_post='where page=0 and slug not like "_-%"'
	if [[ -n "$1" ]]; then
		where_post="${where_post} and slug=\"$@\""
	fi

	if [[ "$(get_ghost_version)" > "1" ]]; then
		sqlite3 "${DB}" "update posts set slug = id ${where_post}"
	else
		sqlite3 "${DB}" "update posts set slug = author_id || \"-\" || id ${where_post}"
	fi
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
if ! dependency sqlite3 curl wget sum; then
	echo "The updatesite.sh abort."
	exit
fi

## load monster configure
if [[ -f "./.monster" ]]; then
	source ./.monster
fi

## proess argument '--DB'
for param; do
	if [[ "$param" =~ ^--*[dD][bB]= ]]; then
		declare DB=$(expr "$param" : '.*=\(.*\)' \| true)
	fi
done

## check configures
if [[ -z "$DB" ]]; then
	echo "Configure file .monster lost, or pass --DB and other paraments please."
	echo "Or run 'monster --init' first."
	exit
fi

## sed -i, compatible macosx and gnu
if sed --version 2>&1 | grep -q 'illegal option'; then
	function sed_inplace_E { local INPLACE_FILE="$1"; shift; sed -i '' -Ee "$*" "$INPLACE_FILE"; }
else
	function sed_inplace_E { local INPLACE_FILE="$1"; shift; sed -i'' -Ee "$*" "$INPLACE_FILE"; }
fi

## direct commands
##	- variant used: $DB, $GITHUB_TOKEN, $GITHUB_USER, $GITHUB_APIRATE, $GITHUB_PAGESIZE
for param; do
	if [[ "$param" == "--init" ]]; then
		where_post="where status=\"published\" and visibility=\"public\""
		LAST_ID=`sqlite3 "${DB}" "select slug from posts ${where_post} order by updated_at desc limit 1"`
		LAST_AT=`sqlite3 "${DB}" "select updated_at from posts ${where_post} order by updated_at desc limit 1"`
		LAST_NEW=`sqlite3 "${DB}" "select slug from posts ${where_post} order by created_at desc limit 1"`
		LAST_TAG=(`sqlite3 "${DB}" -separator ' ' 'select id, count(*) from posts_tags order by id desc limit 1'`)
		echo -e "update_id=\"${LAST_ID}\"\nupdate_at=\"${LAST_AT}\"\nlast_create_id=\"${LAST_NEW}\"\nlast_tag=(${LAST_TAG[@]})\nlast_checksums=($2)" > .sqlitedb
		echo "File .sqlitedb saved."
		exit
	fi
	if [[ "$param" == "--sync-slug" ]]; then
		try_sync_slug && echo "Done."
		exit
	fi
	if [[ "$param" == "--sync-issue" ]]; then
		## or check with labels, ex:
		##	> curl -s 'https://api.github.com/repos/aimingoo/aimingoo.github.io/issues?creator=aimingoo&labels=gitment,1-1725'
		labled_list=" $(get_labled_list) "
		echo -e "\033[0;32mSync issues ...\033[0m"
		where_post="where status=\"published\" and visibility=\"public\" and page=0"
		current=0
		total=`sqlite3 "${DB}" "select count(*) from posts ${where_post}"`
		while read -r slug title; do
			let current+=1
			printf "[%${#total}d/%d] Process ${slug}|${title} ...\n" ${current} ${total}
			if [[ "${labled_list}" =~ " ${slug} " ]]; then continue; fi

			sleep ${GITHUB_APIRATE}
			curl -s -u "${GITHUB_USER}:${GITHUB_TOKEN}" -H 'Content-Type: application/json'\
				--data-binary "{\"title\":\"${title}\", \"body\": \"${PROTOCOL}://${DOMAIN:-${GITHUB_USER}.github.io}/${slug}.html\", \"labels\": [\"${slug}\", \"gitment\"]}"\
				"https://api.github.com/repos/${GITHUB_USER}/${DOMAIN:-${GITHUB_USER}.github.io}/issues" > /dev/null
			if [[ "$?" != "0" ]]; then echo ' -> ERROR'; fi
		done < <(sqlite3 "${DB}" -separator ' ' "select slug, title from posts ${where_post}")
		echo
		echo "Done."
		exit
	fi
	if [[ "$param" == "--list" ]]; then
		if [[ "$2" == "unment" ]]; then
			labled_list=" $(get_labled_list) "
			echo -e "\033[0;32mList non gitment posts ...\033[0m"
			where_post="where status=\"published\" and visibility=\"public\" and page=0"
			while read -r slug title; do
				if [[ "${labled_list}" =~ " ${slug} " ]]; then continue; fi
				echo " -> ${slug}|${title}"
			done < <(sqlite3 "${DB}" -separator ' ' "select slug, title from posts ${where_post}")
			echo "Done."
			exit
		fi
		if [[ "$2" == "user" ]]; then
			printf ".width %d\nselect id,name,slug,email,status from users;" 24 | sqlite3 "${DB}" -header -column
			exit
		fi
	fi
	if [[ "$param" == "--search" ]]; then
		if [[ "$(get_ghost_version)" > "1" ]]; then
			where_post="where mobiledoc like '%$2%'"
		else
			where_post="where markdown like '%$2%'"
		fi
		sqlite3 "${DB}" -header -column "select id,slug,created_at,title from posts ${where_post}"
		exit
	fi
done

## proess arguments
for param; do
	declare $(echo ${param%%=*} | tr '[a-z]' '[A-Z]' | sed 's/^--*//; s/-/_/g')=$(expr "$param" : '.*=\(.*\)' \| true)
done

## import saved data
if [[ -f "./.sqlitedb" ]]; then
	source .sqlitedb
fi

function wget_static {
	wget -N -e robots=off --force-html --no-host-directories --force-directories --directory-prefix="${STATIC_PATH}" $@ 2>&1 |\
		tee -a monster.log |\
		cut -c 1-70 | while read -r LINE; do printf '> %-73s\r' "$LINE"; done
}

function wget_static_deep {
	wget_static -l inf --recursive --page-requisites --no-parent --adjust-extension $@
}

function join {
	local IFS="$1"; shift; echo "$*"
}

# arg1: startFrom
# arg2: allElements
# ret: nextPostion joinedString
function join_e {
	local count=$1; shift $count;
	local size=0 num=0;
	for arg; do
		let size+=${#arg}+1
		if (( size > 1950 )); then break; fi # the max-size is 2048 of sed's patten
		let num++
	done
	echo $((count+num)) $(join "|" ${@:1:$num})
}

function no_paged {
	return $(sqlite3 "${DB}" "select count(*) from posts where page=1 and slug=\"$1\" and status=\"published\" and visibility=\"public\"")
}

FORCEINDEX_LIST_STR=" ${FORCEINDEX_LIST[@]} "
function force_paged_filename {
	if [[ "${FORCEINDEX_LIST_STR}" =~ " $1 " ]]; then
		mkdir -p "${STATIC_PATH}/$1" >/dev/null 2>&1
		echo "${STATIC_PATH}/$1/index.html"
	else
		echo "${STATIC_PATH}/$1"
	fi
}

## read db and pick files
create_ids=()
if $DEPLOY_ONLY; then
	if [ ! -d "${STATIC_PATH}" ]; then
		echo -e "\033[0;32mTry deploy but none '${STATIC_PATH}' directory...\033[0m"
		exit
	fi
else
	if [[ -n "$update_at" ]]; then ## first only?
		where_post="where status=\"published\" and visibility=\"public\" and created_at > \"${update_at}\""
		read -a create_ids < <(sqlite3 "${DB}" "select slug from posts ${where_post} order by created_at" | xargs)
	fi

	if $ALWAYS_SYNC_SLUG; then
		echo -e "\033[0;32mTry sync slug for new posts ...\033[0m"
		if [[ -z "$update_at" ]]; then ## first/full-generate only
			try_sync_slug  ## sync all once
		elif (( ${#create_ids[@]} > 0 )); then ## sync one by one
			for (( i=0; i<${#create_ids[@]}; i++ )); do
				try_sync_slug "${create_ids[$i]}"
			done
		fi
	fi

	echo -e "\033[0;32mPick updated or new files ...\033[0m"
	rx_acceptlist=$(join "|" "${ACCEPT_LIST[@]}")
	where_post="where status=\"published\" and visibility=\"public\" and updated_at > \"${update_at}\""
	read -a update_ids < <(sqlite3 "${DB}" "select slug from posts ${where_post} order by updated_at" | xargs)
	for (( i=0; i<${#update_ids[@]}; i++ )); do
		## pick all update files and all asset
		##	ignore '--convert-links'?
		if no_paged "${update_ids[$i]}"; then ## auto set filename
			wget_static_deep --accept-regex="/(${rx_acceptlist})/" "${SITE}/${update_ids[$i]}"
		else  ## force save as without deep
			wget_static -O "$(force_paged_filename ${update_ids[$i]})" "${SITE}/${update_ids[$i]}"
		fi
	done
fi

## check files
##	- filter all versioning files in your site
##	> find . -name '*.html' | xargs -n1 grep -Eoe '"[^"]*?v=[0-9a-f]*"' |\
##		sed 's|\.\./||g; s|\./||g; s|\?v=[0-9a-f]*||g' | sort | uniq
if $DEPLOY_ONLY; then
	checksums=(`get_checksums`)
else
	if (( ${#update_ids[@]} > 0 )); then
		checksums=(`get_checksums`)
		if [[ "${last_checksums[*]}" == "${checksums[*]}" ]]; then
			rm -rf "${STATIC_PATH}/assets" 2>/dev/null
			rm -rf "${STATIC_PATH}/shared" 2>/dev/null
			rm -rf "${STATIC_PATH}/public" 2>/dev/null
		fi
	fi
fi

## check files and pick more...
if ! $DEPLOY_ONLY; then
	## skip re-pick aside links for new files when full generate
	if (( ${#create_ids[@]} > 0 )); then
		## re-pick last post at last time
		wget_static --adjust-extension "${SITE}/${last_create_id}"
		## pick prev and next for new files
		for (( i=0; i<${#create_ids[@]}; i++ )); do
			if no_paged "${create_ids[$i]}"; then
				new_post="${STATIC_PATH}/${create_ids[$i]}.html"
			else
				new_post="$(force_paged_filename ${create_ids[$i]})"
			fi

			read -a aside_links < <(awk '/<aside /,/<\/aside>/' "${new_post}" |\
				grep -Eoe 'prev|next|href="[^"]*"' | xargs -n2 | sed -E 's|^.*/([^/]{1,})/{0,1}|\1|' | xargs)
			for (( j=0; j<${#aside_links[@]}; j++ )); do
				if [[ ! -f "${STATIC_PATH}/${aside_links[$j]}.html" ]]; then
					wget_static --adjust-extension "${SITE}/${aside_links[$j]}"
				fi
			done
		done
	fi

	# refresh all tag pages
	tag_summary=(`sqlite3 "${DB}" -separator ' ' 'select id, count(*) from posts_tags order by id desc limit 1'`)
	if [[ "${tag_summary[*]}" != "${last_tag[*]}" ]]; then
		echo
		echo -e "\033[0;32mRefresh all tag pages ...\033[0m"

		if $PICK_STATIC_TAGCLOUD; then
			wget_static "${SITE}/tag-cloud"
		fi
		while read -r tag; do
			wget_static_deep --accept-regex='/tag/[^/]*/page/[^/]*/$' "${SITE}/tag/${tag}/"
		done < <(sqlite3 "${DB}" 'select slug from tags')
	fi

	echo
	echo -e "\033[0;32mTry refresh author's pages ...\033[0m"

	## when create new, pick all profile pages for per-author
	create_new=false
	where_user="where id in (select distinct author_id from posts where\
		status=\"published\" and visibility=\"public\" and page=0 and created_at > \"${update_at}\" order by created_at)"
	function pick_author_pages {
		if [[ -n "$1" ]]; then
			where_user="where email=\"${1}\"" ## reset where_user, chekc author's email
		fi
		while read -r author_id; do
			create_new=true
			if $PICK_STATIC_PROFILE; then
				wget_static "${SITE}/profile-${author_id}"
			fi
			wget_static_deep --accept-regex='/author/[^/]*/page/[^/]*/$' "${SITE}/author/${author_id}/"
		done < <(sqlite3 "${DB}" "select slug from users ${where_user}")	
	}
	if ! $SYNC_REMOVED; then
		pick_author_pages # pick and dont check email
	else
		if (( ${#EMAIL[@]} > 1 )); then
			for AUTHOR in ${EMAIL[@]}; do pick_author_pages "$AUTHOR"; done
		else
			pick_author_pages "$EMAIL"
		fi
	fi

	## pick all index pages
	if $create_new || $FORCE; then
		echo
		echo -e "\033[0;32mRefresh index pages ...\033[0m"

		# all sitemap files
		if $PICK_SITEMAP; then
			wget_static "${SITE}/sitemap.xsl"
			wget_static "${SITE}/sitemap.xml"
			wget_static "${SITE}/sitemap-pages.xml"
			wget_static "${SITE}/sitemap-posts.xml"
			wget_static "${SITE}/sitemap-authors.xml"
			wget_static "${SITE}/sitemap-tags.xml"
		fi

		# robots
		if $PICK_ROBOTS_TXT; then
			wget_static "${SITE}/robots.txt"
		fi

		# archives-post
		if $PICK_ARCHIVES_POST; then
			wget_static "${SITE}/archives-post/"
		fi

		# profiles
		if $PICK_STATIC_PROFILE; then
			wget_static "${SITE}/profile-site"
		fi

		if $FORCE; then
			for (( i=0; i<${#FORCEPAGE_LIST[@]}; i++ )); do
				wget_static "${SITE}/${FORCEPAGE_LIST[$i]}"
			done
		fi

		# index and home pages
		wget_static_deep --accept-regex='/page/[^/]*/$' "${SITE}/"

		## other static pages
		wget_static "${SITE}/favicon.ico" >/dev/null
		mkdir -p "${STATIC_PATH}/rss" >/dev/null 2>&1
		wget_static -O "${STATIC_PATH}/rss/index.rss" "${SITE}/rss/" >/dev/null
	else
		echo '> Skiped.'
	fi

	## quick to short path
	if $SHORT_PATH && [ -d "${STATIC_PATH}" ]; then
		echo
		echo -e "\033[0;32mConvert to short filename ...\033[0m"

		# total=$(sqlite3 "${DB}" "select count(*) from posts")
		where_post="where status=\"published\" and visibility=\"public\" and page=0"
		all_posts=($(sqlite3 "${DB}" "select slug from posts ${where_post}" | xargs))
		position=1
		while true; do
			last_position=$position
			read -r position posts < <(join_e $position "${all_posts[@]}")
			echo "> To short post $last_position..$position"
			while read -r INPLACE_FILE; do
				printf '\r> %-73s' "$INPLACE_FILE"
				sed_inplace_E "$INPLACE_FILE" "s#([\"\'/](${posts}))(\.[0-9]*)*(/index\\.html|/*)([\"\'\\?\\#\s>])#\\1.html\\5#g"
			done < <(find "${STATIC_PATH}" \( -name '*.html' -o -name 'profile*' \) -type f)
			printf "\n"
			if (( position > ${#all_posts[@]} )); then break; fi
		done
	fi
fi

## Reset DEPLOY_NOW
if $DEPLOY_ONLY; then
	DEPLOY_NOW=true
fi

## and, try call makesite
if $DEPLOY_NOW || $RESET_DOMAIN; then
	bash "$(dirname $0)/makesite.sh" --site="${SITE}" --domain="${DOMAIN:-${GITHUB_USER}.github.io}" --static-path="${STATIC_PATH}" \
		--generate=false --pick-sitemap=false --reset-domain="${RESET_DOMAIN}" --short-path=false --deploy-now="${DEPLOY_NOW}"
	if [[ "$?" != "0" ]]; then exit; fi

	if $DEPLOY_NOW; then
		## init again, '.sqlitedb' saved
		if (( ${#checksums[@]} == 2 )); then
			bash $0 --init "${checksums[*]}"
		else
			bash $0 --init "${last_checksums[*]}"
		fi
	fi
else
	echo Done.
fi
