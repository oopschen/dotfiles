alias ll='ls -lh --color'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
#alias dkc-db='dkc exec ${DBSERVICE:-db} mysql -h ${DBHOST:-127.0.0.1} -u ${DBUSER:-dev} -p${DBPWD:-123456} ${DBNAME:-dev}'
#alias dkc-reup='dkc stop $p; dkc rm -v $p; dkc up -d $p; dkc logs -f $p;'
alias g='git'
alias x='startx'
#alias wip='watch -n 1 ip addr show dev wlan0'

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
  log=vim \
  mov=mpv \
  mp4=mpv \
  avi=mpv \
  rmvb=mpv \
  mp3=mpv \
  zip="unzip -l" \
  tar.xz="tar -tf" \
  tar.gz="tar -tf" \
  tar="tar -tf" \


#alias swf="sudo rc-service net.wlan0 start"
#alias rswf="sudo rc-service net.wlan0 restart"

alias vpntoggle="v2ray-nft T"
alias vpnoff="v2ray-nft D"

alias hdoff="hdmi-hotplug.sh off"
alias hdm="hdmi-hotplug.sh mirror"
alias hdauto="hdmi-hotplug.sh"

alias gw="./gradlew"
alias unzip-cn="unzip -O cp936"
alias mt="sudo mount"
alias mt8="sudo mount -o uid=work,iocharset=utf8"
alias ut="sudo umount"

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
#alias dingfix="pgrep -f com.alibabainc.dingtalk | xargs -I{} kill -9 {};rm -rf /home/work/.config/DingTalk/userdata/dump"
#alias dingfix='kill -3 $(pgrep -f com.alibabainc.dingtalk -P $(pgrep -f Elevator.sh))'
alias dingfix='kill -3 $(pgrep -f com.alibabainc.dingtalk)'

#### fix zsh can not suspend(ctrl+z) after zplug update
alias zsusfix="rm ~/.zplug/log/job.lock"
alias pdm="podman"

### system tool alias
#alias sys-upworld="sudo emerge -uDNq @world"
#alias sys-cln-aftup="sudo emerge -q --depclean"
#alias sys-rm="sudo emerge --depclean -q"

### python virtual env management
alias activenv="source /usr/bin/virtualenvwrapper.sh"

### rdp 
alias rdpc="xfreerdp  /cert:ignore /dynamic-resolution /scale:100 /scale-desktop:192 +async-update +async-input  +clipboard /video /network:auto"

### local vm win11
alias vm-win11-usb="QMP_SERVER='/tmp/.vmwrk-w11.current/qmp-shell.sock' qemu-wrapper.sh"
