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

# Help

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

# History

```
2017.09.19	v1.0.1 released, fix minor bugs
2017.09.17	v1.0.0 released
```
