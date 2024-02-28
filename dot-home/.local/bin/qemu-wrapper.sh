#!/usr/bin/env bash

USAGE="$0 command options.\n\tcommand list:\n\t\t1. usb-p passthrough usb device to vm \n\t\t2. usb-d del usb device from vm"

cmd=$1
qmp_cmd="qmp-shell -H ${QMP_SERVER:=/tmp/qmp-shell.sock}"

gen_random_value() {
    val=$(echo "$RANDOM % 10000 + 1" | awk '{printf "%.4d", $0}')
    echo $val
}

case $cmd in
    ### usb passthrough
    usb-p)
        # list usb 
        dev_info=$(echo "info usbhost" | $qmp_cmd)
        ## vendorid:productid
        dev_vendor_product_info=$(echo -e "$dev_info" | grep -i "usb device" | sed -r 's/^.*class.+device\s+([^ ,]+).+/\1/i' | sort -d -b -f)
        # prompt device
        echo -e "Host usb devices:"
        i=1
        for usb in $dev_vendor_product_info
        do
            dev_name=$(echo -e "$dev_info" | grep -i "$usb" | sed -r "s/^.+${usb},*\s*//i")
            if [ -z "$dev_name" ]; then
                dev_name=$usb
            fi
            echo -e "\t$i. $dev_name"
            i=$(echo "$i + 1" | bc)
        done
        # choose
        read -p "Please input device number: " chosen_index

        chosen_item=$(echo -e "$dev_vendor_product_info" | head -n $chosen_index | tail -1)
        if [ -z "$chosen_item" ]; then
            echo "No device chosen."
            exit 1
        fi

        chosen_dev_name=$(echo -e "$dev_info" | grep -i "$chosen_item" | sed -r "s/^.+${usb},*\s*//i")
        echo -e "Choose $chosen_item, $chosen_dev_name"

        # call api
        vendor_id="$(echo "$chosen_item" | cut -d ':' -f 1)"
        product_id="$(echo "$chosen_item" | cut -d ':' -f 2)"
        dev_id="d$(gen_random_value)"

        echo "device_add id=$dev_id,driver=usb-host,vendorid=0x$vendor_id,productid=0x$product_id" | $qmp_cmd
        ;;

    usb-d)
        # list usb 
        dev_info=$(echo "info usb" | $qmp_cmd | grep -i "id:") 
        ## vm usb id list
        dev_id_list=$(echo -e "$dev_info" | sed -r 's/.+id:\s*([^\s]+)/\1/ig' | sort -d -b -f)
        # prompt device
        echo -e "VM usb devices:"
        i=1
        for usb in $dev_id_list
        do
            echo "$i. $usb"
            i=$(echo "$i + 1" | bc)
        done
        # choose
        read -p "Please input device number: " chosen_index

        chosen_item=$(echo "info usb" | $qmp_cmd | grep -i "id:"| sed -r 's/.+id:\s*([^\s]+)/\1/ig' | sort -d -b -f | head -n $chosen_index | tail -1)
        chosen_item=$(echo "info usb" | $qmp_cmd | grep -i "id:"| sed -r 's/.+id:\s*([^\s]+)/\1/ig' | sort -d -b -f | head -n $chosen_index | tail -1)

        if [ -z "$chosen_item" ]; then
            echo "No device chosen."
            exit 1
        fi

        # call api
        echo "device_del $chosen_item" | $qmp_cmd
        ;;
    *)
        echo -e $USAGE
        exit 1
esac
