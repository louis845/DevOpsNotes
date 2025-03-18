# Setting up Harbor
Harbor is a locally hosted registry server to work with K8S, so that K8S can execute locally built Docker images. Along with kaniko, this allows for a "Docker desktop" like experience of creating and caching layered docker images.

## Setting up the namespace(s) and the TLS cert

```sh
microk8s kubectl create namespace harbor
microk8s kubectl create namespace harbor-jobs
microk8s kubectl create namespace harbor-runner
microk8s kubectl create secret tls harbor-cert-secret -n harbor --key SECRET.key --cert CERT.pem
microk8s kubectl create secret generic -n harbor-runner self-administered-ca-cert --from-file=gitlab.example.local.crt=rootCA.crt
microk8s kubectl create secret generic -n harbor-jobs self-administered-ca-cert --from-file=harbor.example.local.crt=rootCA.crt
```

## Install harbor via helm
Use helm to install harbor. A reference values configuration is given in [Harbor's Github repo](https://github.com/goharbor/harbor-helm/blob/main/values.yaml). 

```sh
microk8s helm3 install -n harbor harbor harbor/harbor -f values.yaml
```

Get the internal clusterIP of the NGINX ingress controller using the command
```sh
kubectl get service -n harbor harbor
```
and mark it down in **PARAMETERS_TO_PREPARE** as *HARBOR_CLUSTER_IP*.

## Setting up namespace for harbor jobs
Here is the YAML to setup the role for the Gitlab Harbor runner ([reference](https://docs.gitlab.com/runner/executors/kubernetes/#configure-runner-api-permissions)):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: gitlab-runner
  namespace: harbor-jobs # references the harbor-jobs namespace
rules:
- apiGroups: [""]
  resources: ["events"]
  verbs:
  - "list"
  - "watch" # Required when `FF_PRINT_POD_EVENTS=true`
- apiGroups: [""]
  resources: ["pods"]
  verbs:
  - "create"
  - "delete"
  - "get"
  - "list" # Required when using Informers (https://docs.gitlab.com/runner/executors/kubernetes/#informers)
  - "watch" # Required when `FF_KUBERNETES_HONOR_ENTRYPOINT=true`, `FF_USE_LEGACY_KUBERNETES_EXECUTION_STRATEGY=false`, using Informers (https://docs.gitlab.com/runner/executors/kubernetes/#informers)
- apiGroups: [""]
  resources: ["pods/attach"]
  verbs:
  - "create" # Required when `FF_USE_LEGACY_KUBERNETES_EXECUTION_STRATEGY=false`
  - "delete" # Required when `FF_USE_LEGACY_KUBERNETES_EXECUTION_STRATEGY=false`
  - "get" # Required when `FF_USE_LEGACY_KUBERNETES_EXECUTION_STRATEGY=false`
  - "patch" # Required when `FF_USE_LEGACY_KUBERNETES_EXECUTION_STRATEGY=false`
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs:
  - "create"
  - "delete"
  - "get"
  - "patch"
- apiGroups: [""]
  resources: ["pods/log"]
  verbs:
  - "get" # Required when `FF_KUBERNETES_HONOR_ENTRYPOINT=true`, `FF_USE_LEGACY_KUBERNETES_EXECUTION_STRATEGY=false`, `FF_WAIT_FOR_POD_TO_BE_REACHABLE=true`
  - "list" # Required when `FF_KUBERNETES_HONOR_ENTRYPOINT=true`, `FF_USE_LEGACY_KUBERNETES_EXECUTION_STRATEGY=false`
- apiGroups: [""]
  resources: ["secrets"]
  verbs:
  - "create"
  - "delete"
  - "get"
  - "update"
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs:
  - "get"
- apiGroups: [""]
  resources: ["services"]
  verbs:
  - "create"
  - "get"
```

### YAML for Gitlab Runner service account and bindings
Create a service account and namespace for Gitlab Harbor runner and bind the role:
```sh
microk8s kubectl create serviceaccount harbor-runner-svc-acct -n harbor-runner # create empty service account
```

Now apply the YAML to bind the role to the service account:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gitlab-runner-binding
  namespace: harbor-jobs
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: gitlab-runner
subjects:
- kind: ServiceAccount
  name: harbor-runner-svc-acct
  namespace: harbor-runner
```

## Create a Gitlab runner for compiling Harbor jobs
It is necessary to generate a runner token using the Admin panel in the Gitlab web UI. For instructions, see [Gitlab's website](https://docs.gitlab.com/ci/runners/runners_scope/#create-an-instance-runner-with-a-runner-authentication-token). Use the `harbor` tag so Gitlab stages with the `harbor` tag will specifically use this runner. After getting the runner token, set the value below in the Helm chart YAML.

Things to replace: `<generated runner token>`, `INGRESS_CLUSTER_IP`, `HARBOR_CLUSTER_IP`.
```yaml
image:
  registry: registry.gitlab.com
  image: gitlab-org/gitlab-runner
imagePullPolicy: IfNotPresent
useTini: false
gitlabUrl: http://gitlab-webservice-default.gitlab.svc.cluster.local:8080 # connect locally to gitlab from within the cluster
runnerToken: <your runner token>
rbac:
  create: false
  clusterWideAccess: false
serviceAccount:
  name: harbor-runner-svc-acct
unregisterRunners: true
runners:
  executor: kubernetes
  config: |
    [[runners]]
      url = "https://gitlab.example.local"
      clone_url = "https://gitlab.example.local"
      pre_get_sources_script = "git config --global http.https://gitlab.example.local.sslVerify false"
      [runners.kubernetes]
        namespace = "harbor-jobs"
        image = "gcr.io/kaniko-project/executor:debug"
        privileged = false
        [[runners.kubernetes.host_aliases]]
          ip = "<replace with INGRESS_CLUSTER_IP>"
          hostnames = ["gitlab.example.local"]
        [[runners.kubernetes.host_aliases]]
          ip = "<replace with HARBOR_CLUSTER_IP>"
          hostnames = ["harbor.example.local"]
        [[runners.kubernetes.volumes.secret]]
          name = "self-administered-ca-cert"
          mount_path = "/etc/harbor/certs"
          readonly = true
# for k8s runner config, see https://docs.gitlab.com/runner/executors/kubernetes/#add-extra-host-aliases
# note that we disable TLS only for gitlab.example.local. there is a problem of verifying self-signed certs
certsSecretName: self-administered-ca-cert
metrics:
  enabled: false
service:
  enabled: false
```

Now install the gitlab-runner with:
```sh
microk8s helm3 install gitlab-runner gitlab/gitlab-runner -n harbor-runner -f <file>.yaml
```
