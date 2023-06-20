res=$(grep Xft.dpi ~/.Xresources | grep -Eo '[0-9]+')

if [[ $res -gt 96 ]]; then
  export GDK_SCALE=2
  export GDK_DPI_SCALE=0.5
else
  export GDK_SCALE=1
  export GDK_DPI_SCALE=1
fi
