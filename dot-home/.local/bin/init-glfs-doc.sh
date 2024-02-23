#!/usr/bin/env bash
#

pic_files="*.jpg  *.png  *.jpeg *.gif *.webp"
archive_files="*.zip  *.rar  *.7z *.tar *.tar.* *.ar *.iso *.gz *.lz *.jar"
office_files="*.ppt *.pptx *.doc *.docx *.xls *.xlsx *.et *.wps *.pdf"
misc_files="*.xmind *.rp *.edx *.eddx"

track_file_list="$pic_files $archive_files $office_files $misc_files"

for fl in $track_file_list
do
    git lfs track "$fl"
done
