export XMODIFIERS=@im=fcitx
export QT_IM_MODULE=fcitx
export GTK_IM_MODULE=fcitx

[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources
[[ -f ~/.Xmodmap ]] && xmodmap ~/.Xmodmap
xsetroot -cursor_name left_ptr

machineid=$(cat /etc/machine-id)

## nvidia setting
#xrandr --setprovideroutputsource modesetting NVIDIA-0
#xrandr --auto
hdmi-hotplug.sh

## start desktop env
exec dbus-launch --auto-syntax --autolaunch=$machineid --exit-with-session i3
