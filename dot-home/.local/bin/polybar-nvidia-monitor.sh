#!/usr/bin/env bash
#

## run nvidia cmd status
output_file="/tmp/.polybar.nvidia.output"
nvidia-smi -q -f $output_file > /dev/null 2>&1

if [ $? -ne 0 ];
then
  echo -e "%{T1}%{F##FF2171}ERR%{F-}%{T-}"
  exit 0
fi

cmd_status="cat $output_file"

function cal_gpu_memory_usage() {
    status_memoery_used=$($cmd_status | grep -A4 "FB Memory Usage" | grep -i used | sed -r 's/[^0-9]+([0-9]+).+/\1/ig')
    status_memoery_total=$($cmd_status | grep -A4 "FB Memory Usage" | grep -i total  | sed -r 's/[^0-9]+([0-9]+).+/\1/ig')

    echo $(python -c "print(round($status_memoery_used/$status_memoery_total * 100,1))")
}

status_process_num=$($cmd_status | grep -iE "process\s+id" | cut -d ':' -f 2 | tr -d ' ' | wc -l)
status_gpu_temp=$($cmd_status | grep -iE "GPU Current Temp" | cut -d ':' -f 2 | sed -r 's/^\s+(.+)\s*$/\1/ig')
status_memoery_use_percentage=$(cal_gpu_memory_usage)


#temp
output="%{T2}%{F#F0C674}NV%{F-}%{T-} %{T4}%{F#F0C674}\uf2c8%{F-}%{T-}"
output="$output%{T1} $status_gpu_temp %{T-}"

#usage percentage
output="$output%{T3}%{F#F0C674}󰍛%{F-}%{T-}"
output="$output%{T1} $status_memoery_use_percentage% %{T-}"
#process num
output="$output%{T3}%{F#F0C674}\uf03a%{F-}%{T-}"
output="$output%{T1} $status_process_num%{T-}"

echo -e $output
