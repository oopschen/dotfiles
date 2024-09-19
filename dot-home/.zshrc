#### fixes
# zplug fixes crtl+z not work: rm ~/.zplug/log/job.lock

# zplug
source ~/.zplug/init.zsh

zplug 'zplug/zplug', hook-build:'zplug --self-manage'

zplug "zsh-users/zsh-syntax-highlighting", use:"zsh-syntax-highlighting.zsh", defer:2

# fzf
zplug "junegunn/fzf", from:gh-r, as:command, hook-build: "sh install --no-fish --no-update-rc" 

# z
zplug "plugins/z", from:oh-my-zsh

zplug load

# source config files
for zsh_conf_file in $(find "$HOME/.config/zsh.d/" -mindepth 1 -type f -iname '*.sh' | sort -n); do
    source $zsh_conf_file
done
