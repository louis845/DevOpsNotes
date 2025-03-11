Reference: https://github.com/rook/rook/blob/release-1.16/deploy/examples/operator.yaml
```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: rook-ceph-operator-config
  namespace: rook-ceph
data:
  ROOK_LOG_LEVEL: "INFO"
  ROOK_OPERATOR_METRICS_BIND_ADDRESS: "0"
  ROOK_CEPH_ALLOW_LOOP_DEVICES: "false"
  ROOK_USE_CSI_OPERATOR: "false"
  ROOK_CSI_ENABLE_CEPHFS: "true"
  ROOK_CSI_ENABLE_RBD: "true"
  ROOK_CSI_ENABLE_NFS: "false"
  ROOK_CSI_DISABLE_DRIVER: "false"
  CSI_ENABLE_ENCRYPTION: "false"
  CSI_PROVISIONER_REPLICAS: "2"
  CSI_ENABLE_CEPHFS_SNAPSHOTTER: "true"
  CSI_ENABLE_NFS_SNAPSHOTTER: "true"
  CSI_ENABLE_RBD_SNAPSHOTTER: "true"
  CSI_ENABLE_VOLUME_GROUP_SNAPSHOT: "true"
  CSI_FORCE_CEPHFS_KERNEL_CLIENT: "true"
  CSI_RBD_FSGROUPPOLICY: "File"
  CSI_CEPHFS_FSGROUPPOLICY: "File"
  CSI_NFS_FSGROUPPOLICY: "File"
  CSI_PLUGIN_ENABLE_SELINUX_HOST_MOUNT: "false"
  CSI_PLUGIN_PRIORITY_CLASSNAME: "system-node-critical"
  CSI_PROVISIONER_PRIORITY_CLASSNAME: "system-cluster-critical"
  ROOK_CSI_KUBELET_DIR_PATH: "/var/snap/microk8s/common/var/lib/kubelet" # set to match microk8s kubelet directory
  CSI_ENABLE_LIVENESS: "false"
  ROOK_OBC_WATCH_OPERATOR_NAMESPACE: "true"
  ROOK_ENABLE_DISCOVERY_DAEMON: "true"
  ROOK_CEPH_COMMANDS_TIMEOUT_SECONDS: "15"
  CSI_ENABLE_CSIADDONS: "false"
  ROOK_WATCH_FOR_NODE_FAILURE: "true"
  CSI_GRPC_TIMEOUT_SECONDS: "150"
  CSI_ENABLE_TOPOLOGY: "false"
  CSI_CEPHFS_ATTACH_REQUIRED: "true"
  CSI_RBD_ATTACH_REQUIRED: "true"
  CSI_NFS_ATTACH_REQUIRED: "true"
  ROOK_DISABLE_DEVICE_HOTPLUG: "false"
  ROOK_DISCOVER_DEVICES_INTERVAL: "60m"
  ROOK_ENFORCE_HOST_NETWORK: "false"
  ROOK_CUSTOM_HOSTNAME_LABEL: ""
---
# OLM: BEGIN OPERATOR DEPLOYMENT
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rook-ceph-operator
  namespace: rook-ceph
  labels:
    operator: rook
    storage-backend: ceph
    app.kubernetes.io/name: rook-ceph
    app.kubernetes.io/instance: rook-ceph
    app.kubernetes.io/component: rook-ceph-operator
    app.kubernetes.io/part-of: rook-ceph-operator
spec:
  selector:
    matchLabels:
      app: rook-ceph-operator
  strategy:
    type: Recreate
  replicas: 1
  template:
    metadata:
      labels:
        app: rook-ceph-operator
    spec:
      tolerations:
        - effect: NoExecute
          key: node.kubernetes.io/unreachable
          operator: Exists
          tolerationSeconds: 5
      serviceAccountName: rook-ceph-system
      containers:
        - name: rook-ceph-operator
          image: docker.io/rook/ceph:v1.16.5
          args: ["ceph", "operator"]
          securityContext:
            runAsNonRoot: true
            runAsUser: 2016
            runAsGroup: 2016
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - mountPath: /var/lib/rook
              name: rook-config
            - mountPath: /etc/ceph
              name: default-config-dir
          env:
            - name: ROOK_CURRENT_NAMESPACE_ONLY
              value: "false"
            - name: ROOK_HOSTPATH_REQUIRES_PRIVILEGED
              value: "false"
            - name: DISCOVER_DAEMON_UDEV_BLACKLIST
              value: "(?i)dm-[0-9]+,(?i)rbd[0-9]+,(?i)nbd[0-9]+"
            - name: ROOK_UNREACHABLE_NODE_TOLERATION_SECONDS
              value: "5"
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
      volumes:
        - name: rook-config
          emptyDir: {}
        - name: default-config-dir
          emptyDir: {}
```