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
