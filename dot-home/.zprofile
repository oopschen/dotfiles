### setup enviroment variables
export PIPENV_PYPI_MIRROR=https://mirrors.aliyun.com/pypi/simple/
export SASS_BINARY_SITE=http://npm.taobao.org/mirrors/node-sass
export PUPPETEER_DOWNLOAD_HOST=https://npm.taobao.org/mirrors
export ELECTRON_MIRROR=http://npm.taobao.org/mirrors/electron/
export WORKON_HOME=$HOME/.virtualenvs

#####  local bin path
path+=($HOME/.local/bin)

#### node bin
NODE_HOME=~/opt/nodejs
path+=($NODE_HOME/bin)


export PATH



### pipewire startup, check at https://wiki.gentoo.org/wiki/PipeWire

# Ensure XDG_RUNTIME_DIR is set
if test -z "$XDG_RUNTIME_DIR"; then
    export XDG_RUNTIME_DIR=$(mktemp -d /tmp/$(id -u)-runtime-dir.XXX)
fi

