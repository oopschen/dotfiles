#### fixes
# zplug fixes crtl+z not work: rm ~/.zplug/log/job.lock

# zplug
source ~/.zplug/init.zsh

zplug 'zplug/zplug', hook-build:'zplug --self-manage'

# history
zplug "zsh-users/zsh-syntax-highlighting", use:"zsh-syntax-highlighting.zsh"
zplug "zsh-users/zsh-history-substring-search", use:"zsh-history-substring-search.zsh"

# fzf
zplug "junegunn/fzf", as:command, hook-build: "sh install --no-fish" 

# z
zplug "plugins/z", from:oh-my-zsh

# gradle completion
zplug "gradle/gradle-completion", from:github, depth:1, as:command

zplug load

# source config files
for zsh_conf_file in $(find "$HOME/.config/zsh.d/" -mindepth 1 -type f -iname '*.sh' | sort -n); do
    source $zsh_conf_file
done
