# Monster

full once upon or incremental static site generator for Ghost.

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
> monster --init
Your Github name or domain : xxxx
...
```


**Generate full site**

```bash
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

2017.09.17	v1.0.0 released
```
