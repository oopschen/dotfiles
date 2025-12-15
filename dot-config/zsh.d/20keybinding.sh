list_recently_modified_files() {
	_list_recently_modified_files "$(pwd)"
}

list_temp_recently_modified_files() {
	_list_recently_modified_files  ~/Downloads /tmp
}

_list_recently_modified_files() {
	for sel_file in "$(rg --files -L -i  --sortr modified $@ \
		| fzf --preview-window=top,20%,wrap  --preview \
		'file -b {};ls -lh {};' \
		)";
		do
			if [ ! -z "$sel_file" ];then 
				BUFFER="$BUFFER $sel_file"
			fi

		done

	CURSOR=$#BUFFER
}

zle -N list_recently_modified_files
bindkey '^[w' list_recently_modified_files

zle -N list_temp_recently_modified_files
bindkey '^[q' list_temp_recently_modified_files
