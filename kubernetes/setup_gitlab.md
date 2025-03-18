# Gitlab setup
Now we have to setup development accounts on Gitlab, and for Gitlab to access the kubernetes cluster, and register SSH keys so development devices can access the Gitlab server. Here are the steps.

## Access Gitlab admin account
In Gitlab, there is always a `root` admin account that has the highest privileges and can access everything. To get access to it, use the command
```sh
kubectl get -n gitlab secret/gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 --decode
```

where the password of it is initially stored as a K8S secret. Update the `root` password by logging into the root web UI, and go to `Edit Profile -> Password`. Set a new secure password, and the password of the root account will be decoupled with the K8S secret `gitlab-gitlab-initial-root-password`. 

To adjust the settings of the Gitlab instance, go to `Search or Go to -> Admin Area`, and the settings can be adjusted in that section. For instance, `Admin Area -> Settings -> General -> Visibility and access controls` allows one to only allow SSH access for Git.

## Setup SSH access
Now add tokens to the Gitlab accounts via the Gitlab Web UI. To allow SSH access, upgrade the `gitlab-gitlab-shell` service from ClusterIP to NodePort that exposes the port `32222`. The command is
```sh
microk8s kubectl patch service gitlab-gitlab-shell -n gitlab -p '{"spec": {"type": "NodePort", "ports": [{"port": 22, "nodePort": 32222, "protocol": "TCP"}]}}'
```

## Setup Gitlab runner
For basic concepts of Gitlab for CI/CD, refer to [this document](gitlab.md). Setup the `gitlab-ci` namespace so all CI/CD deployments will be run there, and setup a service account in a new `gitlab-runner` namespace to restrict gitlab to only use `gitlab-ci`. See [here](setup_gitlab_runner_role.md) for instructions. Create a YAML file to update the configuration, so that helm can install gitlab with the correct configurations. [View the official YAML reference](https://gitlab.com/gitlab-org/charts/gitlab-runner/blob/main/values.yaml).

It is necessary to generate a runner token using the Admin panel in the Gitlab web UI. For instructions, see [Gitlab's website](https://docs.gitlab.com/ci/runners/runners_scope/#create-an-instance-runner-with-a-runner-authentication-token). After getting the runner token, set the value below in the Helm chart YAML. Also, find the internal cluster IP the NGINX ingress controller is listening to, so the Gitlab runner can simulate connecting from outside the cluster.

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
  name: gitlab-runner-svc-acct
unregisterRunners: true
runners:
  executor: kubernetes
  config: |
    [[runners]]
      url = "https://gitlab.example.local"
      clone_url = "https://gitlab.example.local"
      pre_get_sources_script = "git config --global http.https://gitlab.example.local.sslVerify false"
      [runners.kubernetes]
        namespace = "gitlab-ci"
        image = "alpine"
        privileged = false
        [[runners.kubernetes.host_aliases]]
          ip = "<replace with found cluster IP>"
          hostnames = ["gitlab.example.local"]
        [[runners.kubernetes.volumes.secret]]
          name = "self-administered-ca-cert"
          mount_path = "/etc/gitlab/certs"
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
microk8s helm3 install gitlab-runner gitlab/gitlab-runner -n gitlab-runner -f <file>.yaml
```

Using the `rootCA.crt`, create a secret within the`gitlab-runner` namespace so the gitlab runner knows to trust the locally hosted server:
```sh
microk8s kubectl create secret generic -n gitlab-runner self-administered-ca-cert --from-file=gitlab.example.local.crt=<root CA file path>.crt
```