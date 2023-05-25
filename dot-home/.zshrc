#### fixes
# zplug fixes crtl+z not work: rm ~/.zplug/log/job.lock

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

# theme
zplug romkatv/powerlevel10k, as:theme, depth:1

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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
