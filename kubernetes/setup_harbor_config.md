There are a few things to be set, search it up by the string `THINGS_TO_SET`. The first is the login credentials to push and pull and access the Harbor service. The username is `admin` and the password will be the one set in the YAML. The second is a randomly generated key string used internally. The third is a randomly generated `(username, password)` pair for Harbor to be used internally (not used externally for pull/push).

```yaml
expose:
  type: clusterIP
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-cert-secret
  clusterIP:
    name: harbor
    staticClusterIP: "10.152.183.59"
    ports:
      httpPort: 80
      httpsPort: 443
    annotations: {}
    labels: {}

externalURL: https://10.152.183.59

persistence:
  enabled: true
  resourcePolicy: "keep"
  persistentVolumeClaim:
    registry:
      existingClaim: ""
      storageClass: ""
      subPath: ""
      accessMode: ReadWriteOnce
      size: 5Gi
      annotations: {}
    jobservice:
      jobLog:
        existingClaim: ""
        storageClass: ""
        subPath: ""
        accessMode: ReadWriteOnce
        size: 1Gi
        annotations: {}
    database:
      existingClaim: ""
      storageClass: ""
      subPath: ""
      accessMode: ReadWriteOnce
      size: 1Gi
      annotations: {}
    redis:
      existingClaim: ""
      storageClass: ""
      subPath: ""
      accessMode: ReadWriteOnce
      size: 1Gi
      annotations: {}
    trivy:
      existingClaim: ""
      storageClass: ""
      subPath: ""
      accessMode: ReadWriteOnce
      size: 5Gi
      annotations: {}
  imageChartStorage:
    disableredirect: false
    type: filesystem
    filesystem:
      rootdirectory: /storage

# change the password here. THINGS_TO_SET
harborAdminPassword: "Harbor12345"

internalTLS:
  enabled: true
  strong_ssl_ciphers: false
  certSource: "auto"

ipFamily:
  ipv6:
    enabled: false
  ipv4:
    enabled: true

imagePullPolicy: IfNotPresent
imagePullSecrets:
updateStrategy:
  type: RollingUpdate
logLevel: info # THINGS_TO_SET
secretKey: "not-a-secure-key" # randomly generate a string of 16 chars `openssl rand -base64 12 | tr -d '=+/' | head -c 16`
proxy:
  httpProxy:
  httpsProxy:
  noProxy: 127.0.0.1,localhost,.local,.internal
  components:
    - core
    - jobservice
    - trivy
enableMigrateHelmHook: false
metrics:
  enabled: false
  core:
    path: /metrics
    port: 8001
  registry:
    path: /metrics
    port: 8001
  jobservice:
    path: /metrics
    port: 8001
  exporter:
    path: /metrics
    port: 8001
  serviceMonitor:
    enabled: false
    additionalLabels: {}
    interval: ""
    metricRelabelings:
      []
    relabelings:
      []

trace:
  enabled: false
  provider: jaeger
  sample_rate: 1
  jaeger:
    endpoint: http://hostname:14268/api/traces
  otel:
    endpoint: hostname:4318
    url_path: /v1/traces
    compression: false
    insecure: true
    timeout: 10

cache:
  enabled: true
  expireHours: 120 # expire after 5 days

containerSecurityContext:
  privileged: false
  allowPrivilegeEscalation: false
  seccompProfile:
    type: RuntimeDefault
  runAsNonRoot: true
  capabilities:
    drop:
      - ALL

nginx:
  image:
    repository: goharbor/nginx-photon
    tag: v2.12.2
  serviceAccountName: ""
  automountServiceAccountToken: false
  replicas: 1
  revisionHistoryLimit: 10
  resources:
   requests:
     memory: 256Mi
     cpu: 100m
  extraEnvVars: []
  nodeSelector: {}
  tolerations: []
  affinity: {}
  topologySpreadConstraints: []
  podAnnotations: {}
  podLabels: {}
  priorityClassName:

portal:
  image:
    repository: goharbor/harbor-portal
    tag: v2.12.2
  serviceAccountName: ""
  automountServiceAccountToken: false
  replicas: 1
  revisionHistoryLimit: 10
  extraEnvVars: []
  nodeSelector: {}
  tolerations: []
  affinity: {}
  topologySpreadConstraints: []
  podAnnotations: {}
  podLabels: {}
  serviceAnnotations: {}
  priorityClassName:
  initContainers: []

core:
  image:
    repository: goharbor/harbor-core
    tag: v2.12.2
  serviceAccountName: ""
  automountServiceAccountToken: false
  replicas: 1
  revisionHistoryLimit: 10
  startupProbe:
    enabled: true
    initialDelaySeconds: 10
  extraEnvVars: []
  nodeSelector: {}
  tolerations: []
  affinity: {}
  topologySpreadConstraints: []
  podAnnotations: {}
  podLabels: {}
  serviceAnnotations: {}
  priorityClassName:
  initContainers: []
  configureUserSettings:
  quotaUpdateProvider: db
  secretName: ""

jobservice:
  image:
    repository: goharbor/harbor-jobservice
    tag: v2.12.2
  serviceAccountName: ""
  automountServiceAccountToken: false
  replicas: 1
  revisionHistoryLimit: 10
  extraEnvVars: []
  nodeSelector: {}
  tolerations: []
  affinity: {}
  topologySpreadConstraints:
  podAnnotations: {}
  podLabels: {}
  priorityClassName:
  initContainers: []
  maxJobWorkers: 10
  jobLoggers:
    - file
  loggerSweeperDuration: 14 #days
  notification:
    webhook_job_max_retry: 3
    webhook_job_http_client_timeout: 3 # in seconds
  reaper:
    max_update_hours: 24
    max_dangling_hours: 168
  existingSecretKey: JOBSERVICE_SECRET

registry:
  registry:
    image:
      repository: goharbor/registry-photon
      tag: v2.12.2
    resources:
     requests:
       memory: 256Mi
       cpu: 100m
    extraEnvVars: []
  controller:
    image:
      repository: goharbor/harbor-registryctl
      tag: v2.12.2
    resources:
     requests:
       memory: 256Mi
       cpu: 100m
    extraEnvVars: []
  serviceAccountName: ""
  automountServiceAccountToken: false
  replicas: 1
  revisionHistoryLimit: 10
  nodeSelector: {}
  tolerations: []
  affinity: {}
  topologySpreadConstraints: []
  podAnnotations: {}
  podLabels: {}
  priorityClassName:
  initContainers: []
  existingSecretKey: REGISTRY_HTTP_SECRET
  relativeurls: false
  credentials: # THINGS_TO_SET
    username: "harbor_registry_user"
    password: "harbor_registry_password"
  middleware:
    enabled: false
    type: cloudFront
    cloudFront:
      baseurl: example.cloudfront.net
      keypairid: KEYPAIRID
      duration: 3000s
      ipfilteredby: none
      privateKeySecret: "my-secret"
  upload_purging:
    enabled: true
    age: 168h
    interval: 24h
    dryrun: false

trivy:
  enabled: true
  image:
    repository: goharbor/trivy-adapter-photon
    tag: v2.12.2
  serviceAccountName: ""
  automountServiceAccountToken: false
  replicas: 1
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1
      memory: 1Gi
  extraEnvVars: []
  nodeSelector: {}
  tolerations: []
  affinity: {}
  topologySpreadConstraints: []
  podAnnotations: {}
  podLabels: {}
  priorityClassName:
  initContainers: []
  debugMode: false
  vulnType: "os,library"
  severity: "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"
  ignoreUnfixed: false
  insecure: false
  gitHubToken: ""
  skipUpdate: false
  skipJavaDBUpdate: false
  offlineScan: false
  securityCheck: "vuln"
  timeout: 5m0s

database:
  type: internal
  internal:
    image:
      repository: goharbor/harbor-db
      tag: v2.12.2
    serviceAccountName: ""
    automountServiceAccountToken: false
    livenessProbe:
      timeoutSeconds: 1
    readinessProbe:
      timeoutSeconds: 1
    extraEnvVars: []
    nodeSelector: {}
    tolerations: []
    affinity: {}
    priorityClassName:
    extrInitContainers: []
    password: "changeit"
    shmSizeLimit: 512Mi
    initContainer:
      migrator: {}
      permissions: {}
  maxIdleConns: 100
  maxOpenConns: 900
  podAnnotations: {}
  podLabels: {}

redis:
  type: internal
  internal:
    image:
      repository: goharbor/redis-photon
      tag: v2.12.2
    serviceAccountName: ""
    automountServiceAccountToken: false
    extraEnvVars: []
    nodeSelector: {}
    tolerations: []
    affinity: {}
    priorityClassName:
    initContainers: []
    jobserviceDatabaseIndex: "1"
    registryDatabaseIndex: "2"
    trivyAdapterIndex: "5"
  podAnnotations: {}
  podLabels: {}

exporter:
  image:
    repository: goharbor/harbor-exporter
    tag: v2.12.2
  serviceAccountName: ""
  automountServiceAccountToken: false
  replicas: 1
  revisionHistoryLimit: 10
  extraEnvVars: []
  podAnnotations: {}
  podLabels: {}
  nodeSelector: {}
  tolerations: []
  affinity: {}
  topologySpreadConstraints: []
  priorityClassName:
  cacheDuration: 23
  cacheCleanInterval: 14400
```