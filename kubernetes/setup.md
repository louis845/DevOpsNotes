# Microk8s setup

Here are step by step instructions on how to setup microk8s cluster in Ubuntu with rook-ceph enabled to distribute volumes across nodes. On a setup with physical nodes that are connected to multiple physical subnets, follow additional instructions marked with the **`Multiple physical subnets`** tag.

## Change kernel parameters (in each node)

Kubernetes requires the following parameters to be set (where these are the recommended parameters for Linux):
```
vm.overcommit_memory = 1
kernel.panic_on_oops = 1 # when a deviation from Linux kernel expected behavior occurs, create a kernel panic
kernel.panic = 10 # automatically restart after 10 seconds after kernel panic
```

Simply add the above three lines to `/etc/sysctl.conf`.

## Node settings
Disable any firewall settings, as kubernetes modifies `iptables` internally to make routing possible, and make sure the device names of each node are unique. Make sure to have an extra drive / partition on `/dev/sdX` for rook-ceph.

## Install microk8s and build the cluster

Use the following command to install microk8s
```sh
sudo snap install microk8s --classic
```

**`Multiple physical subnets`** 
Set the bind addresses to the in each node to the physical subnet desired for K8S operations. See Canonical's [microk8s document](https://microk8s.io/docs/configure-host-interfaces).
**`End`**

To connect additional nodes to microk8s, use the following (in sudo). Note that the `microk8s add-node` command has to be run in the control plane node for every worker node.

```sh
microk8s add-node # run in control plane node
microk8s join <params> --worker # run in worker nodes
```

To verify whether the nodes have joined as workers, use the following command:

```sh
microk8s kubectl get nodes
```

## Install kubernetes dashboard

Use the following command on the control plane node to install the dashboard
```sh
microk8s enable dashboard
```

Initially, one has to create an account for the dashboard-admin to allow logging in. Use the following commands:
```sh
microk8s kubectl create -n kube-system serviceaccount dashboard-admin
microk8s kubectl create -n kube-system clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin
```

No login tokens are attached to this account. One has to create a token for logging in to the dashboard everytime.
```sh
microk8s kubectl create token dashboard-admin -n kube-system # default expiry 1 hour
```

To login to the kubernetes dashboard, one has to forward a port from the developer's device to the container that runs the K8S dashboard.
```sh
kubectl port-forward -n kube-system service/kubernetes-dashboard 8080:443
```

One then can connect through `https://127.0.0.1:8080`.
## Install rook-ceph

Use the following commands to install rook-ceph using helm3, and refer to the [official YAML file](https://github.com/rook/rook/blob/release-1.16/deploy/charts/rook-ceph/values.yaml) to create values.yaml.
```sh
microk8s helm3 repo add rook-release https://charts.rook.io/release
microk8s helm3 install --create-namespace --namespace rook-ceph rook-ceph rook-release/rook-ceph -f values.yaml
```

Look at the node's device names, and the particular storage devices paths in `/dev` (usually `/dev/sdX`). Check the rook version with
```sh
microk8s helm3 list -n rook-ceph
```
Note that the rook-ceph version is the rook version. Navigate to the official [rook documentation](https://rook.io/docs/rook/v1.11/Upgrade/ceph-upgrade/) and view the Ceph upgrade page for the correct rook version. It lists the compatible Ceph version to be used with rook. View the list of available Ceph versions in the `quay.io` [image repository](https://quay.io/repository/ceph/ceph?tab=tags), and select a version.


Create a [YAML file](setup_rook_ceph_yaml.md) and use `microk8s kubectl apply -f <file>.yml`. Things to set in the YAML:
  * Ceph version. `spec -> ceph version -> image`
  * Particulars of k8s nodes. `spec -> storage -> nodes`
Create another [YAML file to set the contents of the rook-ceph operator](setup_rook_ceph_operator.md) and use `microk8s kubectl apply -f <file>.yml`.

Now set rook-ceph to replicate data across the clusters, so the data can be automatically be distributed with the CRUSH algorithm.
```yaml
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: mypool # name my the Ceph block pool
  namespace: rook-ceph
spec:
  failureDomain: host
  replicated:
    size: 3 # how many replications
```

We can now create a StorageClass named `rook-ceph-block`, so that subsequent persistent volumes can reference the storage class by name `rook-ceph-block` to create a rook-ceph backed persistent volume.
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: rook-ceph-block # name of the storage class
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  pool: mypool # references the Ceph block pool above
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
  csi.storage.k8s.io/fstype: ext4
reclaimPolicy: Delete # note that data is automatically deleted when the PVC is deleted
allowVolumeExpansion: true
mountOptions:
  - debug
```

Set the block as the default storage class
```
microk8s kubectl patch storageclass rook-ceph-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Create another storage class to supported distributed access for multiple nodes (e.g ML dataset access across different nodes). Similarly we create a Ceph pool for it:
```yaml
apiVersion: ceph.rook.io/v1
kind: CephFilesystem
metadata:
  name: myfs
  namespace: rook-ceph
spec:
  metadataPool:
    replicated:
      size: 3
      requireSafeReplicaSize: true
  dataPools:
    - name: mycephpool
      replicated:
        size: 3
        requireSafeReplicaSize: true
  preserveFilesystemOnDelete: true
  metadataServer:
    activeCount: 1
    activeStandby: true
    resources:
      limits:
        cpu: "2"
        memory: "4Gi"
      requests:
        cpu: "1"
        memory: "2Gi"
```

And then create a StorageClass for it:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-cephfs
provisioner: rook-ceph.cephfs.csi.ceph.com
parameters:
  clusterID: rook-ceph
  fsName: myfs
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-cephfs-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
  mounter: fuse # FUSE is a bit slower, but the kernel mounter for CephFS is now bugged (gives libceph: mon1 (1)192.168.100.100:3300 socket closed (con state V1_BANNER), probably version problem, mon uses V2)
reclaimPolicy: Delete # note that data is automatically deleted when the PVC is deleted
allowVolumeExpansion: true
```

To look at the status of rook-ceph and verify the installation, forward with the following command:
```sh
# get the password, default username is admin
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode
kubectl port-forward -n rook-ceph services/rook-ceph-mgr-dashboard 8000:8443
```

## Install gitlab
Now one can install gitlab for CI/CD. Add the gitlab repo to the helm charts.

```sh
microk8s helm3 repo add gitlab https://charts.gitlab.io/
microk8s helm3 repo update
```

Create the server's certificate and key pair (see [the encryption README](../encryption.md)), and use the following command to establish a secret in the K8S cluster:
```sh
microk8s kubectl create namespace gitlab # create an empty gitlab namespace, so the TLS keys can be added
microk8s kubectl create secret tls selfsigned-cert-tls -n gitlab --key SECRET.key --cert CERT.pem
```

Setup the `gitlab-ci` namespace so all CI/CD deployments will be run there, and setup a service account to restrict gitlab to there. See [here](setup_gitlab_runner_role.md) for instructions. Create a YAML file to update the configuration, so that helm can install gitlab with the correct configurations.
```yaml
global:
  hosts:
    domain: example.local # domain name
  edition: ce # community addition of gitlab
  ingress:
    configureCertmanager: false
    class: nginx # default github-nginx, set to be compatible with ingress-nginx
gitlab:
  webservice:
    ingress:
      tls:
        secretName: selfsigned-cert-tls
nginx-ingress:
  enabled: false
certmanager:
  install: false
certmanager-issuer:
  install: false
gitlab-runner: # gitlab-runner for CI/CD
  install: true
  gitlabUrl: http://gitlab-webservice-default.gitlab.svc.cluster.local:8080
  rbac:
    create: false
    clusterWideAccess: false
  serviceAccount:
    name: gitlab-runner-svc-acct
  runners:
    executor: kubernetes
    config: |
      [[runners]]
        [runners.kubernetes]
          namespace = "gitlab-ci"
          image = "alpine"
          privileged = false
# namespace of runner must match that of the roles and so on, see above
postgresql:
  install: true
redis:
  install: true
```

Install now:
```sh
microk8s helm3 install gitlab gitlab/gitlab -f <file>.yaml -n gitlab
```

## Install NGINX Ingress controller
Add the repos for nginx ingress to helm:
```sh
microk8s helm3 repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
microk8s helm3 repo update
```

Configure the Nginx ingress controller so that it doesn't expose any ports (only accessible from within the cluster/kubectl port forwarding).
```yaml
controller:
  service:
    type: ClusterIP
    ports:
      http: 80
      https: 443
  hostPort:
    enabled: false # change to true if allow hostport
  daemonset:
    useHostPort: false # change to true if allow hostport
```

Install the NGINX Ingress controller on the kubernetes cluster:
```bash
microk8s helm install ingress-nginx ingress-nginx/ingress-nginx -f <file>.yaml -n ingress-nginx --create-namespace
```

It is now possible to use the NGINX ingress controller to access the gitlab service. The command is
```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 8443:443
```

This allows the NGINX ingress controller to be accessible from the developer's device. Note that gitlab configures the ingresses to forward
connections to its services using the HTTP host name headers, so that NGINX forwards the HTTP requests to the corresponding Gitlab services when
the domain written in the browser is something like `gitlab.example.local` (or `gitlab.<setting>` set by the `hosts.domain` of gitlab Helm YAML).
To allow correct DNS resolution, add the domain names to `/etc/hosts`
```
127.0.0.1 gitlab.example.local
127.0.0.1 registry.example.local
127.0.0.1 minio.example.local
127.0.0.1 kas.example.local
```
To connect to the Gitlab web UI, connect to `gitlab.example.local:8443` in the browser.

## Blocking off container's access to physical devices on host nodes' subnets
To block off container's access to physical devices on the host nodes' subnets, refer to the following [section](concepts_networking.md#block-off-podcontainer-access-to-physical-devices-on-host).

**`Multiple physical subnets`** 
Set the NodePort bind addresses and the Calico/VXLAN CLI to use the desired internal subnet for routing IP packets via VXLAN and accepting connections for NodePort, as per [here](concepts_networking.md#nodeport) and [here](concepts_networking.md#internal-cluster-routing-on-which-physical-subnet).
**`End`**

# Allowing kubectl access from elsewhere
In the node with the microk8s control plane, the (client) settings for `kubectl` is stored inside `/var/snap/microk8s/current/credentials/client.config`, which contains complete TLS (client key, client cert, CA cert) pair for mTLS. Copy the file to another device's `~/.kube/config` and modify the IP to point to the K8S cluster (usually port 16443) to allow connections from outside.

# Gitlab configuration
Now setup Gitlab using the Gitlab web UI. See [this document](setup_gitlab.md).