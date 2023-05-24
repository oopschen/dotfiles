#!/usr/bin/env bash
# @Depressed by Notion App
# #Since 2023/05/08

#### create note command
### create-note [note name]

title=

if [ $# -ge 1 ]; then
  title=$1
fi

cat >> $(date +%d)-${title:=def}.md <<EOF
# 会议标题

## 与会人员

## 会议摘要

## 会议总结
EOF
