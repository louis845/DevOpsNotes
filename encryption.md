# TLS encryption

## General concepts
The general concept is that TCP connection consists of communication between two "sides", where a side can verify the identity of another side. Lets temporarily call side that proves its own identity the "presenter", and the side that requires to verify the other's identity the "verifier". The verifier has a (list of) rootCA certificates, which can be used to confirm whether the "presenter" is to be trusted. The presenter should have its own private key and a certificate, where the certificate is signed from the root CA to the presenter's public key (and also contains the presenter's public key). The presenter will send the certificate to the verifier, and the verifier confirms the presenter's public key indeed matches and is signed by (a certificate chain) starting from the root CA's certificate public key.

In usual TLS, the client verifies the identity of the server. The server's certificate should also contain the domain name/IP address of the server, so the client only proceeds with connections when the domain name matches the list of ones presented in the certificates. These are the necessary files:
```
  * client
    * root CA certificate
  * server
    * server's certificate (server's public key signed by some intermediate/root CA)
    * server's private key (to be kept private for initializing TLS)
```

In mTLS (mutual TLS), both client and server verify the identity of each other. So these are the necessary files:
```
  * client
    * root CA certificate
    * client's certificate (client's public key signed by some intermediate/root CA)
    * client's private key (kept private)
  * server
    * root CA certificate (doesn't have to be the same root CA as client, to indicate which clients to trust)
    * server's certificate (signed server's public key)
    * server's private key (kept private)
```

## CA and CA chains
A CA determines who can be trusted by signing public keys using its own private key. A higher level (where root CA is the highest level) CA can sign a lower level intermediate CA's public key to indicate the intermediate CA is to be trusted. The intermediate CA can then sign other CAs, or sign a end user (e.g server/client)'s public key. This creates a certificate chain, so that when a root CA's public key is to be trusted, the tree paths represented by the certificate chains is to be trusted.

## 1. Generating the Root CA Private Key and Self-Signed Certificate
Here is a step by step guide on how to use the `openssl` command to generate the corresponding private key and signed certificate files.

### 1.1. Generate the Root CA Private Key
Use the `openssl genpkey` command to generate a 4096-bit RSA private key for the Root CA:
```
openssl genpkey -algorithm RSA -out rootCA.key -pkeyopt rsa_keygen_bits:4096
```

### 1.2. Create a Self-Signed Root CA Certificate
Create a self-signed certificate for the Root CA valid for 365 days using the `openssl req` command:
```
openssl req -x509 -new -key rootCA.key -sha256 -days 365 -out rootCA.pem
```

## 2. Generating Intermediate CA Private Key and Certificate

### 2.1. Generate the Intermediate CA Private Key
Generate a 4096-bit RSA private key for the Intermediate CA:
```
openssl genpkey -algorithm RSA -out intermediateCA.key -pkeyopt rsa_keygen_bits:4096
```

### 2.2. Create a Certificate Signing Request (CSR) for the Intermediate CA
Create a CSR for the Intermediate CA:
```
openssl req -new -key intermediateCA.key -out intermediateCA.csr
```

### 2.3. Sign the Intermediate CA CSR with the Root CA to Create the Intermediate Certificate
Use the `openssl x509` command to sign the Intermediate CA's CSR with the Root CA's key, making the Intermediate CA certificate valid for 365 days:
```
openssl x509 -req -in intermediateCA.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -sha256 -days 365 -out intermediateCA.pem
```

## 3. Generating End-Entity (Server/User) Private Key and Certificate

### 3.1. Generate the End-Entity Private Key
Generate a 2048-bit RSA private key for the end-entity:
```
openssl genpkey -algorithm RSA -out endEntity.key -pkeyopt rsa_keygen_bits:2048
```

### 3.2. Create a Certificate Signing Request (CSR) for the End-Entity
Create a CSR for the end-entity:
```
openssl req -new -key endEntity.key -out endEntity.csr
```

### 3.3. Sign the End-Entity CSR with the Intermediate CA to Create the End-Entity Certificate
Use the `openssl x509` command to sign the end-entity's CSR with the Intermediate CA's key, making the certificate valid for 365 days:
```
openssl x509 -req -in endEntity.csr -CA intermediateCA.pem -CAkey intermediateCA.key -CAcreateserial -sha256 -days 365 -out endEntity.pem
```

## 4. Commands with Default Options (Optional)

### 4.1. Example Configuration File (.cnf)
Below is an example of a configuration file used with the `openssl req` command:
```
[ customIPAndDomains ]
subjectAltName          = @alt_names

[ client_auth_ext ]
extendedKeyUsage = clientAuth

[ alt_names ]
DNS.1 = example.com
DNS.2 = www.example.com
DNS.3 = api.example.com
IP.1  = 127.0.0.1
IP.2  = 192.168.1.100
IP.3  = 192.168.1.101
IP.4  = 192.168.1.102
IP.5  = 192.168.1.103
IP.6  = 192.168.1.104
IP.7  = 192.168.100.100
IP.8  = 192.168.100.101
IP.9  = 192.168.100.102
IP.10 = 192.168.100.103
```

### 4.2. Creating a Server Certificate
Create a server certificate using the configuration file with appropriate extensions:
```
openssl x509 -extfile example.cnf -extensions customIPAndDomains -req -in endEntity.csr -CA intermediateCA.pem -CAkey intermediateCA.key -CAcreateserial -sha256 -days 365 -out server.pem
```

### 4.3. Creating a Client Certificate
Create a client certificate using the configuration file with client authentication extensions:
```
openssl x509 -extfile example.cnf -extensions client_auth_ext -req -in endEntity.csr -CA intermediateCA.pem -CAkey intermediateCA.key -CAcreateserial -sha256 -days 365 -out client.pem
```

## 5. Verifying the Certificate Chain

### 5.1. Verify the Intermediate CA Certificate
Ensure that the Intermediate CA certificate is signed by the Root CA:
```
openssl verify -CAfile rootCA.pem intermediateCA.pem
```

### 5.2. Verify the End-Entity Certificate
Ensure that the end-entity certificate is signed by the Intermediate CA:
```
openssl verify -CAfile intermediateCA.pem endEntity.pem
```

### 5.3. Viewing the details in text (IP etc) of a Certificate
Using a preexisting certificate (already signed), view the miscellaneous information that is built into the certificate, such as the IP addresses, domain names, emails, and so on.
```
openssl x509 -in cert.pem -noout -text
```

## References
- https://docs.openssl.org/3.0/man1/openssl-genpkey/
- https://docs.openssl.org/3.0/man1/openssl-req
- https://docs.openssl.org/3.0/man1/openssl-x509
- https://docs.openssl.org/3.0/man5/config/