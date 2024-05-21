#!/usr/bin/env bash

USAGE="$0 command options.\n\tcommand list:\n\t\t1. usb-p passthrough usb device to vm \n\t\t2. usb-d del usb device from vm"

cmd=$1
qmp_sock=${QMP_SERVER:=/tmp/qmp-shell.sock}

if [ ! -e $qmp_sock ]; then
    echo -e "QMP sock path not found: $qmp_sock"
    exit 100
fi

## arg1: result
## arg2: command
function call_qmp() {
    declare -n res=$1
    res=$(echo "$2" | qmp-shell -H $qmp_sock)
}

function gen_random_value() {
    val=$(echo "$RANDOM % 10000 + 1" | awk '{printf "%.4d", $0}')
    echo -n $val
}

function fetch_usb_info_from_vm() {
    declare -n res=$1
    
    dev_info=
    call_qmp dev_info "info usbhost"
    ## vendorid:productid, name
    ## vendorid:productid
    ## 2 formats
    res=$(echo -en "$dev_info" | grep -iE "usb\s+device" | sed -r 's/^.+usb\s+device\s+(.+)$/\1/ig' | sort -d -b -f)
}

## param: one raw device info line
## vendorid:productid, name
## vendorid:productid
function get_device_vendorid() {
    declare -n res=$1

    info_line=$(echo $2 | tr -d '\r\n' )
    res=$(echo -en ${info_line%%:*})
}

## param: one raw device info line
## vendorid:productid, name
## vendorid:productid
function get_device_productid() {
    declare -n res=$1

    info_line=$(echo "$2" | tr -d '\r\n' | cut -d ',' -f 1)
    res=$(echo -en ${info_line#*:})
}

## param: one raw device info line
## vendorid:productid, name
## vendorid:productid
function get_device_name() {
    declare -n res=$1

    pname=$(echo "$2" | tr -d '\r\n')
    name_part=$(echo -e "$pname" | cut -d ',' -f 2)
    if [ -z $(echo -e $pname | grep -i ',') ]; then
        res="unamed[${pname}]"
    else
        trimed_name=$(echo -en "$name_part" | sed -r 's/^\s+//ig')
        res="$trimed_name"
    fi
}

case $cmd in
    ### usb passthrough
    usb-p)
        ## vendorid:productid
        dev_vendor_product_info=
        fetch_usb_info_from_vm dev_vendor_product_info

        # prompt device
        i=1
        IFS=$'\n'
        prompt_text=
        for usb in $dev_vendor_product_info
        do
            dev_name=
            get_device_name dev_name "$usb"

            if [ -z "$prompt_text" ]; then
                prompt_text="\t$i. $dev_name"
            else
                prompt_text="${prompt_text}\n\t$i. $dev_name"
            fi
            i=$(echo "$i + 1" | bc)
        done
        echo -e $prompt_text
        # choose
        read -p "Please input device number: " chosen_index

        chosen_item=
        i=1
        IFS=$'\n'
        for usb in $dev_vendor_product_info
        do
            if [ $i -eq $chosen_index ]; then
                chosen_item=$usb
            fi
            i=$(echo "$i + 1" | bc)
        done

        if [ -z "$chosen_item" ]; then
            echo "No device chosen."
            exit 1
        fi

        chosen_dev_name=
        get_device_name chosen_dev_name "$chosen_item"

        ## remove name part in line
        chosen_item=${chosen_item%%,*}

        vendor_id=
        get_device_vendorid vendor_id "$chosen_item"

        product_id=
        get_device_productid product_id "$chosen_item"

        dev_id="d$(gen_random_value)"

        echo -e "Add device: dev-name=$chosen_dev_name, vendor-product=$vendor_id:$product_id, device-id=$dev_id."
        # call api
        call_res=
        call_qmp call_res "device_add id=$dev_id,driver=usb-host,vendorid=0x$vendor_id,productid=0x$product_id"
        echo $call_res
        ;;

    usb-d)
        # list usb 
        raw_dev_list=
        call_qmp raw_dev_list "info usb"
        ## vm usb id list, format name,id
        dev_id_list=$( echo "$raw_dev_list" | grep -i "id:" \
            | sed -r 's/.+product\s*([^,]+).+id:\s*([^\s]+)/\1,\2/ig' | tr -d '\r' |sort -d -b -f)
        if [ -z "$dev_id_list" ]; then
            echo -e "No usb device found"
            exit 0
        fi
        # prompt device
        echo -e "VM usb devices:"
        i=1
        IFS=$'\n'
        for usb in $dev_id_list
        do
            echo "$i. $usb"
            i=$(echo "$i + 1" | bc)
        done
        # choose
        read -p "Please input device number: " chosen_index

        i=1
        chosen_item=
        for dev in $dev_id_list
        do
            if [ $i -eq $chosen_index ]; then
                chosen_item=$dev
                break
            fi
            i=$(echo "$i + 1" | bc)
        done

        if [ -z "$chosen_item" ]; then
            echo "No device chosen."
            exit 1
        fi

        # call api
        call_res=
        call_qmp call_res "device_del ${chosen_item##*,}" 
        echo -e $call_res
        ;;
    *)
        echo -e $USAGE
        exit 1
esac
