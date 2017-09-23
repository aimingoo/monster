# Monster

Full or incremental static site generator for Ghost.

# Features

- Full static site generator for Ghost and other blog or sites
- Incremental generator for new or updated blogs on Ghost
- Preview at localhost with static files
- Support GitHub Pages(host on github.io), and standalone domain
- Integration git deploy on github.io or your standalone domain
- Single client, multi site alone configuration
- Support simplify url(very short slug as title) for Ghost
- Support multi-author for Ghost
- Some expert features for git-comments(use github issues as blog comments, ex: gitment)


# Install

```bash
> brew install aimingoo/repo/monster

# OR, manual install with git
> git clone https://github.com/aimingoo/monster
> install monster/libexec/monster.sh /usr/local/bin/monster
```

# Usage

**Init work directory**

```bash
# Pull your xxxx.github.io
> git clone https://github.com/xxxx/xxxx.github.io
...

# Initialization as work directory
> cd xxxx.github.io
> monster --init
Your Github name or domain : xxxx
...
```

**Generate full site**

```bash
# Launch your Ghost site first(default on localhost:2368), and
> monster --generate
```

**Preview the ./static directory**

```bash
> monster preview
Serving HTTP on 0.0.0.0 port 8000 ...
```


**Deploy to xxxx.github.io**


```bash
> monster --deploy-now
```


**Incremental update**

```bash
# generate incremental files only
> monster update

# OR, update and deploy
> monster update --deploy-now
```

**Deploy incremental files**

```bash
# execute 'monster update' first, and
> monster update --deploy-only
```



# Quick Help

Normal help information:

```bash
> monster --help
```

More:

```bash
> monster generate --help

# and
> monster update --help
```



# Manual

### Base command format

```bash
> monster <mode> [paraments]
```

default mode is `generate`.

### Paraments for `generate` mode

```bash
#
# Switch paraments
#	ex: --paramName=true/false
# use --paramName will set to 'true'
#

## Four main steps
# - GENERATE: full site generate with Buster
--generate
# - RESET_DOMAIN: reset DOMAIN in static pages, default is true
--reset-domain
# - SHORT_PATH: shortening path in url in static pages
--short-path
# - DEPLOY_NOW: deploy with Git client
--deploy-now

## Processes before 'RESET_DOMAIN' step
# - enable pick file sitemap file /sitemap-*
--pick-sitemap
# - enable remove '?xxxxx' postfix of filename in static directory
--patch-version

## Processes before 'DEPLOY_NOW' step
# - enable check DOMIAN replaced in pages in static directory before deploy
--check-static

## enable show more information in GENERATE step of 'generate' mode
--generate-info

#
# String paraments
#

## Github domain or 3rd domain without protocol
--domain="..."

## Ghost site or general address, will pull offline files
--site="http://..."

## Default directory of static files
--static-path="..."

#
# Other paraments
#

## Show help
--help

## Show version
--version
```


### Paraments for `update` mode

```bash
#
# Switch paraments
#	ex: --paramName=true/false
# use --paramName will set to 'true'
#


## In Fetch and Deploy processing
# - RESET_DOMAIN: reset DOMAIN in static pages, default is true
--reset-domain
# - SHORT_PATH: shortening path in url in static pages, default is true
--short-path
# - DEPLOY_NOW: deploy with Git client
--deploy-now
# - try refresh index pages for remove posts in Fetch processing
--sync-removed
# - deploy only, skip Fetch processing
--deploy-only

## Try pick files
# - enable pick file /tag-cloud
--pick-static-tagcloud
# - enable pick file /profile-xxx
--pick-static-profile
# - enable pick file /archive-post
--pick-archive-post
# - enable pick file /robot.txt
--pick-robot-txt
# - enable pick file sitemap file /sitemap-*
--pick-sitemap
# - force try PICK_xxxx options
--force


#
# String paraments
#

## Github domain or 3rd domain without protocol
--domain="..."

## Ghost site or general address, will pull offline files
--site="http://..."

## Default directory of static files
--static-path="..."

#- write url with the protocol as issue body when use '--sync-issue', default is 'https'
--protocol="..."

## path of sqlite .db file for Ghost blog on localhost
--db="..."

## login account for Ghost blog on localhost
# (please use 'monster --list user' to view a list)
--email="..."
```

And you can use some direct commands in `update` mode:
```bash
#
# direct commands
#

## generate .sqlitedb to align data from current .db file
# - 'checksums' is internal parament only
--init [checksums]

## update to 'authorId-postId' format for all slugs of post
# - direct generate short-path for all posts
# - call me before 'monster update'
--sync-slug

## generate issues for all posts in github repo of current git pages
# - for Gitment only
# - write issue with two tags: '${slug}' and 'gitment'
# - check issue exist, no duplicate
--sync-issue

## list un-comment's post, or user, or more...
# - unment: un-comment's posts, for gitment only
# - user: users for Ghost blog on localhost
--list <unment|user>]

## Show help
--help

## Show version
--version
```

### Paraments for `preview` mode
```bash
## one PORT parament only, ex:
# - default is 8000
> monster preview [port]
```


### Configuration items in `.monster`

```bash
## Github domain or 3rd domain without protocol, ex:
#	- "xxxx.github.io", Or "www.yoursite.com"
#	- prefix "xxxx" only when input from console by command 'monster update --init'
DOMAIN="..."


## Ghost .db file path
#	- 'update' mode depend
DB="/User/..."


## Ghost site or general address, will pull offline files
# - default is "http://localhost:2368"
SITE="http://..."


## Github account, and rate of api access
# - Your github account name, ex: "xxxx" of 'xxxx.github.io'
GITHUB_USER="Your name"
# - Access token from your github management page
GITHUB_TOKEN="Access token"
# - limited rate, seconds of github api calls, default 1 of one call per second
GITHUB_APIRATE=1
# - limited page size of read github list, default 100 items per page
GITHUB_PAGESIZE=100


## Other
# - login account in local ghost
EMAIL="..."
# - protocol for 'DOMAIN', require when support Gitment and non git pages
PROTOCOL="https"


## Advertisement token string when your site supported 
AD_TOKEN=""


## Default directory of static files
STATIC_PATH="./static"


## Default behavior
# - enable show more information in GENERATE step of 'generate' mode
GENERATE_INFO=false
# - enable force sync removed posts in index or list pages of 'update' mode
SYNC_REMOVED=false
# - enable remove '?xxxxx' postfix of filename in static directory
PATCH_VERSION=true
# - enable RESET_DOMAIN step
RESET_DOMAIN=true
# - enable SHORT_PATH step
SHORT_PATH=false
# - enable check DOMIAN replaced in pages in static directory before deploy
CHECK_STATIC=true


## Pick more files
# - enable pick file /tag-cloud
PICK_STATIC_TAGCLOUD=false
# - enable pick file /profile-xxx
PICK_STATIC_PROFILE=false
# - enable pick file /archive-post
PICK_ARCHIVES_POST=false
# - enable pick file /robots.txt
PICK_ROBOTS_TXT=true
# - enable pick file sitemap file /sitemap-*
PICK_SITEMAP=true
# - force try PICK_xxxx options in 'update' mode
FORCE=false


## Other override
# - ignore directories in SHORT_PATH step
IGNORE_LIST=("archives-post" "author" "page" "rss" "tag" "assets" "content" "shared")
# - accept directories of static file when pick post pages in 'update' mode
ACCEPT_LIST=("assets" "content" "rss" "shared")
# - process directories in PATCH_VERSION step
VERDIR_LIST=("assets" "shared" "public")
```
### About configuration file `.sqlitedb`

the `.sqlitedb` include database database last `update`. next command to align current database:

```bash
> monster update --init
```

The file will update when execute `monster update` with `--deploy-now` or `--deploy-only`。

If the file lost or removed, then will `monster update` command will fetch all posts, and you can make/rewrite it by `monster update --init` anytime.

# History

```
2017.09.23	v1.0.4 released, GNU sed supported, and update manual.
2017.09.20	v1.0.3 released
2017.09.19	v1.0.2 released, fix minor bugs
2017.09.17	v1.0.0 released
```
