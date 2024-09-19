ignore_rules=("node_modules" "target" "build")

rg_ignores=
fd_ignores="! -ipath './.*'"
for ig in "${ignore_rules[@]}"
do
    rg_ignores=" $rg_ignores --iglob='!$ig'"
    fd_ignores="$fd_ignores ! -ipath './*$ig*'"
done

base_opts="-L -i"
export FZF_DEFAULT_COMMAND="rg --files $base_opts $rg_ignores"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="find . $fd_ignores -type d -print"

export FZF_DEFAULT_OPTS="--history=$HOME/.fzf_history --history-size=10000 --cycle -m"
export FZF_CTRL_T_OPTS="--preview 'fzf-preview.sh {}'"
export FZF_ALT_C_OPTS="--preview 'tree -C -L 7 {}'"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
