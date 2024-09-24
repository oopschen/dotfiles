# respect ignore in global .gitignore .rgignore .fdignore files

export FZF_DEFAULT_COMMAND="rg --files -L -i"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type d -L"

export FZF_DEFAULT_OPTS="--history=$HOME/.fzf_history --history-size=10000 --cycle --wrap -m --no-mouse --tabstop=4"
export FZF_CTRL_T_OPTS="--preview 'fzf-preview.sh {}' --preview-window='right,60%'"
export FZF_ALT_C_OPTS="--preview 'tree -C -L 7 {}' --preview-window='right,60%'"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
