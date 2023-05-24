#!/usr/bin/env bash

# find all dot files in 1 depth including hidden
# for each direcoty, find 1 depth directory including hidden
# if direcoty has populate-dotfiles.sh:
# then 
#   execute
# else
#   make link to dot directory

get_real_config_name() {
    name_after_remove_dot=${1#dot-}
    if [[ "home" =~ "$name_after_remove_dot" ]]; then
        echo "$HOME"
    else
        echo "$HOME/.$name_after_remove_dot"
    fi
}

get_real_config_filename() {
    relative_path=$(realpath --relative-to="$2" "$3")
    echo "$1/$relative_path"
}

check_file_exists() {
    [[ -e "$1" || -h "$1" ]] && return 0
    return 1
}

prompt4_removal() {
    echo "File($1) exists, remove it [y|n]?"
    read op
    [[ "y" =~ "$op" ]] && return 0
    return 1
}
## end

repo_dir=$(dirname $0)/..
workdir=$(pwd)

dot_dirs=$(find $repo_dir -maxdepth 1 -mindepth 1 -type d  -name 'dot-*')

if [ 0 -ne $? ]; then
    echo "No dotfiles found."
    exit 1
fi

for dot_dir in $dot_dirs
do
    dest_dir=$(get_real_config_name "$(basename $dot_dir)")
    
    dot_file_or_dirs=$(find $dot_dir -maxdepth 1  -mindepth 1 ! -path '*tmp*' ! \
                        -iname '.gitignore' ! -iname 'populate-dotfiles.sh' )
    if [ 0 -ne $? ]; then
        echo "No dotfiles found at \"$cur_dir\"."
        continue
    fi

    for dotfile_path in $dot_file_or_dirs
    do
        if [[ -d "$dotfile_path" ]]; then
            dest_filename=$(get_real_config_filename "$dest_dir" "$dot_dir" "$dotfile_path")
            if [[ -f "$dotfile_path/populate-dotfiles.sh" ]]; then
                echo "Exec $dotfile_path/populate-dotfiles.sh"
                sh $dotfile_path/populate-dotfiles.sh
                continue

            elif [[ -d "$dest_filename" ]]; then
                prompt4_removal "$dest_filename"
                if [[ 0 -eq $? ]]; then
                    rm -i "$dest_filename"
                else
                    continue
                fi

            fi

            echo "Link from $dotfile_path to $dest_filename"
            ln -sv $(realpath $workdir/$dotfile_path) $dest_filename

        elif [[ -f "$dotfile_path" ]]; then
            dest_filename=$(get_real_config_filename "$dest_dir" "$dot_dir" "$dotfile_path")
            check_file_exists $dest_filename
            if [[ 0 -eq $? ]]; then
                prompt4_removal "$dest_filename"
                if [[ 0 -eq $? ]]; then
                    rm -i "$dest_filename"
                else
                    continue
                fi
            fi

            echo "Link from $dotfile_path to $dest_filename"
            ln -sv $(realpath $workdir/$dotfile_path) $dest_filename
        fi
    done

done

echo "Populate dotfiles done, enjoy yourself."
