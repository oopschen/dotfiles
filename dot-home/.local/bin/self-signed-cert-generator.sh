#!/usr/bin/env bash

### Self Signed Certificate generator script.
### Usage:
### sh script donmain server-ip


# args checks

if [ $# -lt 2 ];then
	echo -e "Usage:\n\t sh script domain server-ip"
	exit 1
fi

### variables
#### should changed relating to cert
CN=$1

#### predefined variable, may changed
expireddays=1825
rootcafile=rootCA
serverfile=srv-$CN
serverip=$2

### Steps to generate certs:
#### create root ca

echo -e "Create root ca."
openssl req -x509 \
            -sha512 -days $expireddays \
            -nodes \
            -newkey rsa:4096 \
            -subj "/CN=$CN/C=CN/L=Wenzhou" \
            -keyout $rootcafile.key -out $rootcafile.crt 
echo -e "Root ca created, check file $rootcafile.key."


### create private key
echo -e "Create private key."
openssl genrsa -out $serverfile.key 4096
echo -e "Private key created, check file $serverfile.key."

### create csr config file
cat > csr.conf <<EOF
[ req ]
default_bits = 4096
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = CN
ST = JiangZhe
L = Wenzhou
O = Ray
OU = Ray
CN = $CN

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $CN
IP.1 = $serverip

EOF

### generate csr
echo "Create csr."
openssl req -new -key $serverfile.key -out $serverfile.csr -config csr.conf
echo "CSR created, check file $serverfile.csr."

### generate external file
cat > cert.conf <<EOF

authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $CN

EOF

### generate ssl certs

echo "Create ssl certificate."
openssl x509 -req \
    -in $serverfile.csr \
    -CA $rootcafile.crt -CAkey $rootcafile.key \
    -CAcreateserial -out $serverfile.crt \
    -days $expireddays \
    -sha256 -extfile cert.conf
echo "SSL certificate created, check file $rootcafile.crt/$serverfile.key/$serverfile.crt."
