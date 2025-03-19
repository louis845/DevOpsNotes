# Rook ceph
This document tells how to shutdown and restart rook-ceph on a K8S cluster. Before shutting down, other applications that uses PV should be first shutdown. When starting, rook-ceph should be started before other applications. For reference, refer to [rook-ceph's official document](https://www.rook.io/docs/rook/latest-release/Upgrade/node-maintenance/#2-set-ceph-flags).

# Shutting down rook-ceph
## Set Ceph flags
```sh
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- bash
ceph osd set noout # inside the rook-ceph-tools pod
```

## Scaling down operator
```sh
kubectl -n rook-ceph scale deployment rook-ceph-operator --replicas=0
```

## Scaling down other deployments
```sh
for _category in rook-ceph-rgw csi-cephfsplugin-provisioner csi-rbdplugin-provisioner rook-ceph-osd rook-ceph-mon rook-ceph-mgr rook-ceph-exporter rook-ceph-crashcollector; do
    for _item in $(kubectl get deployment -n rook-ceph | awk '/^'"${_category}"'/{print $1}'); do
        kubectl -n rook-ceph scale deployment ${_item} --replicas=0;
        while [[ $(kubectl get deployment -n rook-ceph ${_item} -o jsonpath='{.status.readyReplicas}') != "" ]]; do
            sleep 5;
        done;
    done;
done
```

# Starting back rook-ceph
## Scaling up deployments
```sh
# rook ceph mons
for _item in $(kubectl get deployment -n rook-ceph | awk '/^rook-ceph-mon/{print $1}'); do
    kubectl -n rook-ceph scale deployment ${_item} --replicas=1;
    while [[ $(kubectl get deployment -n rook-ceph ${_item} -o jsonpath='{.status.replicas}') != "1" ]]; do
        sleep 5;
    done;
done
sleep 60;

# rook ceph OSD and MGR
for _category in rook-ceph-mgr rook-ceph-osd; do
    for _item in $(kubectl get deployment -n rook-ceph | awk '/^'"${_category}"'/{print $1}'); do
        kubectl -n rook-ceph scale deployment ${_item} --replicas=1;
        while [[ $(kubectl get deployment -n rook-ceph ${_item} -o jsonpath='{.status.replicas}') != "1" ]]; do
            sleep 5;
        done;
    done;
done
sleep 60;

# others
for _category in rook-ceph-exporter rook-ceph-crashcollector; do
    for _item in $(kubectl get deployment -n rook-ceph | awk '/^'"${_category}"'/{print $1}'); do
        kubectl -n rook-ceph scale deployment ${_item} --replicas=1;
        while [[ $(kubectl get deployment -n rook-ceph ${_item} -o jsonpath='{.status.replicas}') != "1" ]]; do
            sleep 5;
        done;
    done;
done
sleep 60;

# operator
kubectl -n rook-ceph scale deployment rook-ceph-operator --replicas=1
```

## Setting rook-ceph flags
```sh
kubectl -n $ROOK_CLUSTER_NAMESPACE exec -it deploy/rook-ceph-tools -- bash
ceph osd unset noout # inside the rook-ceph-tools pod
```
