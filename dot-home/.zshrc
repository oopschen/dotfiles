# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# zplug
source ~/.zplug/init.zsh

zplug 'zplug/zplug', hook-build:'zplug --self-manage'

# history
zplug "zsh-users/zsh-syntax-highlighting", use:"zsh-syntax-highlighting.zsh"
zplug "zsh-users/zsh-history-substring-search", use:"zsh-history-substring-search.zsh"
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# theme
zplug romkatv/powerlevel10k, as:theme, depth:1
####### end

# fzf
zplug "junegunn/fzf", as:command, hook-build: "sh install --no-fish" 

# z
zplug "plugins/z", from:oh-my-zsh

# gradle completion
zplug "gradle/gradle-completion", from:github, depth:1, as:command

zplug load

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
####### end

# options for zsh
setopt extendedglob 
DIRSTACKSIZE=7
setopt autopushd pushdminus pushdsilent pushdtohome
setopt autolist
setopt appendhistory histignorealldups incappendhistory
SAVEHIST=10000
HISTSIZE=10000
HISTFILE=~/.zsh_history
bindkey -v
## enable builtin completion
compinit

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

####### end


#alias
# thanks to z plugin: alias ds='dirs -v'
alias ll='ls -lh --color'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias dkc-db='dkc exec ${DBSERVICE:-db} mysql -h ${DBHOST:-127.0.0.1} -u ${DBUSER:-dev} -p${DBPWD:-123456} ${DBNAME:-dev}'
alias dkc-reup='dkc stop $p; dkc rm -v $p; dkc up -d $p; dkc logs -f $p;'
alias g='git'
alias x='startx'
alias wip='watch -n 1 ip addr show dev wlan0'
## alias suffix
alias -s html=google-chrome-stable \
  docx=wps \
  doc=wps \
  xlsx=et \
  xls=et \
  ppt=wpp \
  pptx=wpp \
  pdf=mupdf \
  png=sxiv \
  jpeg=sxiv \
  jpg=sxiv \
  gif=sxiv \
  bmp=sxiv \
  md=vim \
  conf=vim \
  svg=google-chrome-stable \
  log=vim

alias swf="sudo rc-service net.wlan0 start"
alias rswf="sudo rc-service net.wlan0 restart"
# depend on rc-service ipset
alias vpntoggle="v2ray-nft T"
alias vpnoff="v2ray-nft D"
alias hdof="monitor-op hdmi-off"
alias hdw="monitor-op hdmi-on; i3-msg '[workspace=\"[^5]\"] move workspace to output primary' > /dev/null"
alias hdo="monitor-op hdmi-on"
alias hdm="monitor-op hdmi-mirror"
alias gw="./gradlew"
alias cuzp="unzip -O cp936"
alias mnt="sudo mount"
alias mntw="sudo mount -o uid=work,iocharset=utf8"
alias umt="sudo umount"
### wpa_cli commands alias
alias ws="sudo wpa_cli -i wlan0"
alias wsl="sudo wpa_cli -i wlan0 list_networks"
alias wss="sudo wpa_cli -i wlan0 select_network"
alias alx="alsamixer"
alias netw="watch -n5 \"ip a\""
alias v="vim"
alias ffcp="fzf -m --print0 --prompt=\"search: >\" | xargs -I{} --null cp {}"
alias ffmv="fzf -m --print0 --prompt=\"search: >\" | xargs -I{} --null mv {}"
alias rcs="sudo rc-service"
### dingtalk
alias dingfix="pgrep -f com.alibabainc.dingtalk | xargs -I{} kill -9 {};rm -rf /home/work/.config/DingTalk/userdata/dump"
#### fix zsh can not suspend(ctrl+z) after zplug update
alias zsusfix="rm ~/.zplug/log/job.lock"
alias pdm="podman"
### system tool alias
alias sys-upworld="sudo emerge -uDNq @world"
alias sys-cln-aftup="sudo emerge -q --depclean"
alias sys-rm="sudo emerge --depclean -q"

export PATH="$SOLANA_HOME/bin:$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

### environment
export JAVA_HOME=~/opt/openjdk/jdk-11
export NODE_HOME=~/opt/node-v14.15.1-linux-x64
export PATH=$NODE_HOME/bin:$HOME/.local/bin:$JAVA_HOME/bin:$HOME/.poetry/bin:$HOME/.cargo/bin:$PATH
#export DISABLE_AUTO_TITLE='true'
#export TERM=screen-256color
export FZF_DEFAULT_COMMAND="rg --files -L -i"
export FZF_DEFAULT_OPTS="--history=$HOME/.fzf_history --history-size=200 --cycle --bind 'ctrl-r:reload($FZF_DEFAULT_COMMAND)'"
export PIPENV_PYPI_MIRROR=https://mirrors.aliyun.com/pypi/simple/
export SOLANA_HOME=~/opt/solana-release
#export LD_PRELOAD=/home/wzga/source_codes/wcwidth-icons/libwcwidth-icons.so
##### node js
export SASS_BINARY_SITE=http://npm.taobao.org/mirrors/node-sass
export PUPPETEER_DOWNLOAD_HOST=https://npm.taobao.org/mirrors
export ELECTRON_MIRROR=http://npm.taobao.org/mirrors/electron/
export WORKON_HOME=$HOME/.virtualenvs

####### end

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

#### fixes
# zplug fixes crtl+z not work: rm ~/.zplug/log/job.lock

# To customize prompt, run `p10k configure` or edit ~/project/repo/linuxmisc/zsh/.p10k.zsh.
[[ ! -f ~/project/repo/linuxmisc/zsh/.p10k.zsh ]] || source ~/project/repo/linuxmisc/zsh/.p10k.zsh
