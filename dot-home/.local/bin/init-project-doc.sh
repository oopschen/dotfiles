#!/usr/bin/env bash
#
# init doc repo layout for project document!!

mkdir 01开发文档 02业务资料 03实施资料

mkdir 01开发文档/{01方案文档,02设计文档,03用户文档,04验收文档}

touch 01开发文档/.gitkeep 02业务资料/.gitkeep 03实施资料/.gitkeep
touch 01开发文档/{01方案文档,02设计文档,03用户文档,04验收文档}/.gitkeep

cat>.gitignore<<EOF
.*
!.gitkeep
!.gitattributes
!.gitignore
EOF


readmefile=$(ls $(dirname $0) | grep -i readme | head -1)

if [ -z "$readmefile" ];then
    readmefile="README.md"
fi

cat>$readmefile<<EOF

## 目录说明

**按照目录存储文件！！！**

- 01开发文档/01方案文档, 存储建设方案相关文档
- 01开发文档/02设计文档，存储UI设计、产品设计(需求调研、需求分析等)或其他过程设计文档
- 01开发文档/03用户文档，存储交接给用户的相关文档
- 01开发文档/04验收文档，存储验收相关文档
- 02业务资料，存储客户提供业务相关文档
- 03实施资料，存储实施过程中的相关文档
EOF
