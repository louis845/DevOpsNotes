# Microk8s setup

Here are step by step instructions on how to setup microk8s cluster in Ubuntu with rook-ceph enabled to distribute volumes across nodes. On a setup with physical nodes that are connected to multiple physical subnets, follow additional instructions marked with the **`Multiple physical subnets`** tag.

Prepare a **`PARAMETERS_TO_PREPARE.txt`** file to store some of the parameters that are generated by some components, while they will be reused by other components. When you see **PARAMETERS_TO_PREPARE**, this signals the parameters is to be written down.

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

## Prepare TLS certificates
To create self-signed TLS certificates (e.g for an org), see [the encryption README](../encryption.md). It is expected there are `rootCA.crt`, `SECRET.key` and `CERT.pem`. Here, `rootCA.crt` is the self-signed cert for rootCA for clients to verify the identity of the server. `SECRET.key` and `CERT.pem` are used by the server to prove itself. Make sure create the signing request to include the following IPs and domains:

```
127.0.0.1
10.152.183.59 # static cluster IP used from within Harbor. 
gitlab.example.local
registry.example.local
minio.example.local
kas.example.local
harbor.example.local
grafana.example.local
```

**PARAMETERS_TO_PREPARE** Store the `SECRET.key`, `CERT.pem` and `rootCA.crt` as files, they are to be reused.

## Install microk8s and build the cluster

Use the following command to install microk8s
```sh
sudo snap install microk8s --classic
sudo microk8s stop # stop the microk8s to configure stuff first
```

### Multiple physical subnets

**`Multiple physical subnets`** 
Set the bind addresses to the in each node to the physical subnet desired for K8S operations. See Canonical's [microk8s document](https://microk8s.io/docs/configure-host-interfaces). Set the NodePort bind addresses and the Calico/VXLAN CLI to use the desired internal subnet for routing IP packets via VXLAN and accepting connections for NodePort, as per [here](concepts_networking.md#nodeport) and [here](concepts_networking.md#internal-cluster-routing-on-which-physical-subnet).

To replace all references to the K8S API with the node's IP on the correct subnet (from `127.0.0.1` to `<IP>`) use the following command, where it is not necessary to escape characters in `<IP>` (e.g. just write `192.168.1.100` plainly).
```sh
find /var/snap/microk8s/current/credentials -type f -exec sed -i 's/127\.0\.0\.1:16443/<IP>:16443/g' {} +
```

After testing, fixing the subnet doesn't quite work well and has problems with Microk8s for now. Do not do this until some updates for microk8s officially support this feature, or use another K8S installation.
**`End`**

### Setting CA for custom registry

For reference, look at [official microk8s docs](https://microk8s.io/docs/registry-private). In each of the nodes, create a file `/var/snap/microk8s/current/args/certs.d/10.152.183.59/hosts.toml` with the contents:
```toml
# /var/snap/microk8s/current/args/certs.d/10.152.183.59/hosts.toml
server = "https://10.152.183.59"

[host."https://10.152.183.59"]
capabilities = ["pull", "resolve"]
ca = "/var/snap/microk8s/current/args/certs.d/10.152.183.59/ca.crt"
```

and copy the `rootCA.crt` to `/var/snap/microk8s/current/args/certs.d/10.152.183.59/ca.crt` in every node. Write `snap restart microk8s` afterwards.

## Connecting nodes

To connect additional nodes to microk8s, use the following (in sudo). Note that the `microk8s add-node` command has to be run in the control plane node for every worker node.

```sh
microk8s add-node # run in control plane node
microk8s join <params> --worker # run in worker nodes
```

To verify whether the nodes have joined as workers, use the following command:

```sh
microk8s kubectl get nodes
```

## Enable RBAC for multiple developer access


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

Choose the correct version of rook-ceph, and install rook-ceph-tools so administration configuration is possible:
```sh
# for example
microk8s kubectl apply -f https://raw.githubusercontent.com/rook/rook/release-1.16/deploy/examples/toolbox.yaml
```

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

Using the previously created TLS configurations (see [the encryption README](../encryption.md) and above), and use the following command to establish a secret in the K8S cluster:
```sh
microk8s kubectl create namespace gitlab # create an empty gitlab namespace, so the TLS keys can be added
microk8s kubectl create secret tls selfsigned-cert-tls -n gitlab --key SECRET.key --cert CERT.pem
```

Now install gitlab and gitlab web service with the following Helm YAML:
```yaml
global:
  hosts:
    domain: example.local # domain name
  edition: ce # community addition of gitlab
  ingress:
    configureCertmanager: false
    class: nginx # default github-nginx, set to be compatible with ingress-nginx
  minio:
    enabled: true
gitlab:
  webservice:
    ingress:
      tls:
        secretName: selfsigned-cert-tls
  toolbox:
    backups:
      objectStorage:
        enabled: true
nginx-ingress:
  enabled: false
installCertmanager: false
certmanager:
  install: false
certmanager-issuer:
  install: false
gitlab-runner: # gitlab-runner for CI/CD is installed separately
  install: false
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
    type: NodePort
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

Get the internal clusterIP of the NGINX ingress controller using the command
```sh
kubectl get service -n ingress-nginx ingress-nginx-controller
```
and mark the ClusterIP down in **PARAMETERS_TO_PREPARE** as *INGRESS_CLUSTER_IP*. This will be used by Gitlab runner pods to connect to Gitlab (since Gitlab is accessible by the ingress controller).

## Blocking off container's access to physical devices on host nodes' subnets
To block off container's access to physical devices on the host nodes' subnets, refer to the following [section](concepts_networking.md#block-off-podcontainer-access-to-physical-devices-on-host).

# Allowing kubectl access from elsewhere
In the node with the microk8s control plane, the (client) settings for `kubectl` is stored inside `/var/snap/microk8s/current/credentials/client.config`, which contains complete TLS (client key, client cert, CA cert) pair for mTLS. Copy the file to another device's `~/.kube/config` and modify the IP to point to the K8S cluster (usually port 16443) to allow connections from outside.

# Gitlab configuration
Now setup Gitlab using the Gitlab web UI. See [this document](setup_gitlab.md).

# Harbor configuration
Now setup Harbor to create a Gitlab runner for compiling Docker images (using kaniko). See [this document](setup_harbor.md).

# NVIDIA GPU and Grafana installation
```sh
microk8s enable nvidia
```

Afterwards, install Grafana and Prometheus to look at the metrics. See [this document](setup_grafana.md).
