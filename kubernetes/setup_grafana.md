Use the following YAML for Grafana:

```yaml
prometheus:
  prometheusSpec:
    additionalScrapeConfigs:
      - job_name: 'nvidia-dcgm-exporter'
        scrape_interval: 5s
        kubernetes_sd_configs:
          - role: service
            namespaces:
              names:
                - gpu-operator-resources
        relabel_configs:
          - source_labels: [__meta_kubernetes_service_name]
            action: keep
            regex: nvidia-dcgm-exporter
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: kubernetes_service_name

grafana:
  enabled: true
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - grafana.example.local
    tls:
      - hosts:
          - grafana.example.local
        secretName: self-administered-ca-cert
  service:
    type: ClusterIP
  persistence:
    enabled: true
    size: 10Gi
  plugins:
    - grafana-piechart-panel
    - grafana-clock-panel
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: 'nvidia'
          orgId: 1
          folder: 'NVIDIA Dashboards'
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/nvidia
  dashboards:
    nvidia:
      nvidia-dcgm:
        gnetId: 12239 # refer to https://docs.nvidia.com/launchpad/infrastructure/openshift-it/latest/openshift-it-step-05.html
        revision: 1
        datasource: Prometheus
```

Afterwards, install it via the commands, and add the secret to the namespace:
```sh
helm3 repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm3 repo update
kubectl create namespace monitoring
kubectl create secret tls selfsigned-cert-tls -n monitoring --key SECRET.key --cert CERT.pem
helm3 install prometheus prometheus-community/kube-prometheus-stack -n monitoring -f values.yaml
```