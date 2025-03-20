#!/bin/bash
set -e
openssl genpkey -algorithm RSA -out rootCA.key -pkeyopt rsa_keygen_bits:4096
openssl req -x509 -new -key rootCA.key -sha256 -days 3650 -out rootCA.pem
openssl genpkey -algorithm RSA -out endEntity.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key endEntity.key -out endEntity.csr
openssl x509 -extfile config.cnf -extensions customIPAndDomains -req -in endEntity.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -sha256 -days 3650 -out server.pem
openssl verify -CAfile rootCA.pem server.pem

mv server.pem CERT.pem
mv rootCA.pem rootCA.crt
mv endEntity.key SECRET.key
rm endEntity.csr
rm rootCA.srl
rm rootCA.key
