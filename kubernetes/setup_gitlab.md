# Gitlab setup
Now we have to setup development accounts on Gitlab, and for Gitlab to access the kubernetes cluster, and register SSH keys so development devices can access the Gitlab server. Here are the steps.

## Access Gitlab admin account
In Gitlab, there is always a `root` admin account that has the highest privileges and can access everything. To get access to it, use the command
```sh
kubectl get -n gitlab secret/gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 --decode
```

where the password of it is initially stored as a K8S secret. Update the `root` password by logging into the root web UI, and go to `Edit Profile -> Password`. Set a new secure password, and the password of the root account will be decoupled with the K8S secret `gitlab-gitlab-initial-root-password`. 

To adjust the settings of the Gitlab instance, go to `Search or Go to -> Admin Area`, and the settings can be adjusted in that section. For instance, `Admin Area -> Settings -> General -> Visibility and access controls` allows one to only allow SSH access for Git.

## Setup Gitlab runner
For basic concepts of Gitlab for CI/CD, refer to [this document](gitlab.md). 