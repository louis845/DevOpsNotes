Reference: https://raw.githubusercontent.com/rook/rook/master/deploy/examples/cluster.yaml
```yaml
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  cephVersion:
    image: quay.io/ceph/ceph:v19.2.1 # CHOOSE CEPH VERSION COMPATIBLE WITH INSTALLED ROOK VERSION
    allowUnsupported: false
  dataDirHostPath: /var/lib/rook
  skipUpgradeChecks: false
  continueUpgradeAfterChecksEvenIfNotHealthy: false
  waitTimeoutForHealthyOSDInMinutes: 10
  mon:
    count: 3
    allowMultiplePerNode: false
  mgr:
    count: 2
    allowMultiplePerNode: false
    modules:
      - name: rook
        enabled: true
  dashboard:
    enabled: true
    ssl: true
  monitoring:
    enabled: false
    metricsDisabled: false
  network:
    connections:
      encryption:
        enabled: true
      compression:
        enabled: false
      requireMsgr2: false
  crashCollector:
    disable: false
  logCollector:
    enabled: true
    periodicity: daily # one of: hourly, daily, weekly, monthly
    maxLogSize: 500M # SUFFIX may be 'M' or 'G'. Must be at least 1M.
  cleanupPolicy:
    confirmation: ""
    sanitizeDisks:
      method: complete
      dataSource: random
      iteration: 1
    allowUninstallWithVolumes: false
  annotations:
  labels:
  resources:
  removeOSDsIfOutAndSafeToRemove: true
  priorityClassNames:
    mon: system-node-critical
    osd: system-node-critical
    mgr: system-cluster-critical
  storage:
    useAllNodes: false
    useAllDevices: false
    nodes: # REPLACE THESE with actual configuration
    - name: "node1"
      devices:
      - name: "sdb" # its possible to use the full path /dev/sdb instead of a single device name. This allows luks partitions and so on.
    - name: "node2"
      devices:
      - name: "sdb" # also possible to use mutliple devices (repeat the -name: "sdX") per node
    - name: "node3"
      devices:
      - name: "sdb"
    config:
    onlyApplyOSDPlacement: false
    allowDeviceClassUpdate: false
    allowOsdCrushWeightUpdate: false
  disruptionManagement:
    managePodBudgets: true
    osdMaintenanceTimeout: 30
    pgHealthCheckTimeout: 0
  csi:
    readAffinity:
      enabled: false
    cephfs:
  healthCheck:
    daemonHealth:
      mon:
        disabled: false
        interval: 45s
      osd:
        disabled: false
        interval: 60s
      status:
        disabled: false
        interval: 60s
    livenessProbe:
      mon:
        disabled: false
      mgr:
        disabled: false
      osd:
        disabled: false
    startupProbe:
      mon:
        disabled: false
      mgr:
        disabled: false
      osd:
        disabled: false
```