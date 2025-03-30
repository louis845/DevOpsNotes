# Developer kubectl Accounts

To allow development for different developers, one has to allow them to access with the `kubectl` command (and/or `helm` command) using public/private key encryption. Here, we reference the [Kubernetes official documents on role binding](https://kubernetes.io/docs/reference/kubernetes-api/authorization-resources/role-binding-v1/) and [client-certificates](https://kubernetes.io/docs/reference/access-authn-authz/authentication/) on how this can be done.

## Basic concepts
The core concept is that in [role binding](concepts.md/#k8s-accounts), apart from binding to ServiceAccounts (which is used by internal K8S programs to access the K8S API), it is also possible to bind to [Users or Groups (see subjects)](https://kubernetes.io/docs/reference/kubernetes-api/authorization-resources/role-binding-v1/). The Users and Groups are "subjects" for the developers, which grant them access to cluster operations with `kubectl`.

## Creating a developer's Client certificate

A key pair has to first be created. Refer to the [encryption documents](../encryption.md) for reference. In the certificate signing request, the `/CN` field will be the username of the account, and the `/O` field(s) will be the groups that they belong to. Here are a chain of commands that could be used to create a key pair and a certificate signing request:

```sh
openssl genpkey -algorithm RSA -out developer.key -pkeyopt rsa_keygen_bits:4096
openssl req -new -key developer.key -subj "/CN=<username>/O=[group 1]/O=[group 2]" -out developer.csr # create certificate signing request on the developer's private key
```

Note that group1 and group2 are optional. This creates a certificate signing request `developer.csr`. This CSR can be passed to the K8S administrator to bind the developer's public key to some roles.

## Adding the developer's public key to K8S

**IMPORTANT** Verify the developer's CSR contains the right fields. K8S uses the `/CN` and `/O` options to authorize permissions to the developer (through RoleBinding and ClusterRoleBinding subject). Use the following command to look at the subject

```sh
openssl req -text -noout -verify -in developer.csr
```

and scroll to the `Subject` field. Check that the username `/CN` and groups `/O` are as expected. Afterwards, the certificate signing request can be added to the K8S cluster. Add the certificate signing request to the cluster as such (look at [K8S CSR management](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/) and [K8S CSR docs](https://kubernetes.io/docs/reference/kubernetes-api/authentication-resources/certificate-signing-request-v1/) for reference):

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: developer-name
spec:
  request: "<csr file contents>"
  signerName: "kubernetes.io/kube-apiserver-client" # this indicates its a client that connects to K8S API Server (e.g kubectl). See https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/#kubernetes-signers.
  usages:
  - client auth # the https://kubernetes.io/docs/reference/kubernetes-api/authentication-resources/certificate-signing-request-v1/ gives more values
```

The `<csr file contents>` can be obtained via `cat developer.csr | base64 | tr -d "\n"`. To approve the csr, use

```sh
kubectl certificate approve developer-name
```

Now it is possible to extract the signed certificate (in base64 format) using the following:
```sh
kubectl get csr/developer-name -o jsonpath="{.status.certificate}"
```

To directly decode into a CRT file, one can use `base64` to decode it:
```sh
kubectl get csr/developer-name -o jsonpath="{.status.certificate}" | base64 -d > developer.crt
```

## Configuring developer's kubectl to add the credentials

A method is to directly modify `~/.kube/config` and copy the base64 encoded versions of `developer.key` and `developer.crt` to the `users` field. Alternatively, use the following commands on the non-base64 encoded version of `developer.key` and `developer.crt`:

```sh
kubectl config set-credentials developer-name \
  --client-certificate=developer.crt \
  --client-key=developer.key \
  --embed-certs=true
```

## Adding permission to the developer account

Here, we assume the subject line (subj) of the CSR to be `/CN=developer1/O=group1/O=group2`. To add role binding or cluster role bindings to the user, one can set the subject as following:


```yaml
# reference by the username (CN)
subjects:
 - kind: User
   name: developer1
   apiGroup: rbac.authorization.k8s.io

# reference by group (O)
subjects:
 - kind: Group
   name: group1
   apiGroup: rbac.authorization.k8s.io

# reference by the other group (O)
subjects:
 - kind: Group
   name: group2
   apiGroup: rbac.authorization.k8s.io
```

In K8S, the (cluster) role bindings allow multiple subjects to be set (as a list). This simutaneously gives permission to multiple user(s) or groups. A (cluster) role binding applies to a user with corresponding CSR iff there exist a subject in the subject list with kind `user` and the name exactly matches, or there exist a subject in the subject list with kind `Group` and the name matches one of the `O` values in the CSR.