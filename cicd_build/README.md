# General instructions and scripts for Gitlab CI/CD on K8S

## Gitlab runners

For Gitlab's CI/CD pipelines, jobs have to be executed by Gitlab runners. Gitlab runners initiate a connection to the Gitlab web service, so the runner can be registered. To abide by the principle of least permissions, a K8S namespace is usually created specifically for hosting the runner, and then the runner can manipulate specifically another namespace. One such possibility is for the runner be installed in `<name>-runner` namespace, while the jobs are run in the `<name>-ci` namespace. The runner will then have a ServiceAccount with a RoleBinding to the `<name>-ci` namespace so it only has permissions to modify that. 

An example of setting up such Gitlab runners is given by [the setup document](../kubernetes/setup_gitlab_runner_role.md), and one can use convenience scripts to directly execute a chain of helm charts with other additional TOML options for the Kubernetes runner, specified in [script for runner](script.md) and [script for runner with TOML](script_toml_only.md).

**K8S Job Configuration** It is often necessary to set additional parameters for K8S in the Gitlab runner jobs, such as using a PVC to load stored language models, or using some Kubernetes secrets to access an external API and so on. To enable this, add additional configuration under the `[runners.kubernetes]` section of the TOML, which allows extra settings to be configured. The list of settings is available in [Gitlab's documentation for Kubernetes runner](https://docs.gitlab.com/runner/executors/kubernetes/). The [script for runner with TOML](script_toml_only.md) deploys a Gitlab runner with the aforementioned TOML settings.

## Choosing Gitlab runners

In a generic MLOps pipeline, there are multiple jobs which may have to run in different physical nodes (due to different GPU capabilities etc). The runners themselves have [options to specify which node to run in](https://docs.gitlab.com/runner/executors/kubernetes/#other-configtoml-settings) (see node_selector). To select which runner to use in each Gitlab job, it is possible to specify a Gitlab CI/CD tag to the runner, and Gitlab will only assign the tagged job to the specific runner.

Gitlab also supports giving multiple tag(s) to runners and jobs. In this case, Gitlab will assign jobs only to runners that have tags that are a superset of the job's tags. In the case that the job has no tags, any runner *that is configured to run untagged jobs* can run the job (an exception to the superset rule).

## Building images and pushing to local registry

We document here how to build images and push images to a local registry. The general principle is to use [Kaniko](https://github.com/GoogleContainerTools/kaniko) (Docker in Docker requires privileged containers) to build images from a Dockerfile, and push to a corresponding registry. One can use the following Gitlab CI job:
```yaml
build:
  tags:
     - harbor # specify the Harbor gitlab runner - a runner that is preconfigured to run Kaniko building jobs
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug # Use the Kaniko image from Google's repository
    entrypoint: [""]
  script: # runs the build script. Assumes that a /kaniko/.docker/config.json file is available for login credentials for multiple registries (e.g index.docker.io/v1, or a local repo)
    - >-
      /kaniko/executor
      --context "${CI_PROJECT_DIR}"
      --dockerfile "${CI_PROJECT_DIR}/Dockerfile"
      --destination "10.152.183.59/${IMAGE_NAME}:${CI_COMMIT_SHORT_SHA}"
      --destination "10.152.183.59/${IMAGE_NAME}:latest"
      --registry-certificate 10.152.183.59=/etc/harbor/certs/harbor.example.local.crt
      --cache=true
      --cache-repo="10.152.183.59/kaniko-cache/cache"
```

This assumes the local Harbor registry is `10.152.193.59`. One has to setup Kubernetes secrets to store the local registry's certificate and [login credentials for registries](../kubernetes/setup_harbor.md#create-a-gitlab-runner-for-compiling-harbor-jobs). To login to Dockerhub for additional pulls, use Docker's usage tokens and specify it in `/kaniko/.docker/config.json`. Notice that the `cache-repo` has to be constant, to allow images in different projects to use the same cache.

**IMPORTANT** Currently, there is probably a problem where Kaniko has to repush the base image for two different destination images, even if the base image is the same. Therefore, it is advisable to use a small base image. For instance, do not use the `pytorch` images (as they are quite large ~3GB), use the CUDA images from NVIDIA and then install python and PyTorch on it.

## Running local images

To run local images, simply do the following:
```yaml
run:
  tags:
    - myrunner
  stage: run
  image:
    name: 10.152.183.59/${IMAGE_NAME}:latest
    entrypoint: [""] # overrides the Dockerfile CMD entrypoint, if given
  script:
    - script1 # scripts are run after the entrypoint
    - script2
```

## Conditionally running jobs

To run jobs conditionally, one can use the only configuration to run jobs in specified branches:
```yaml
run:
  tags:
    - myrunner
  stage: run
  image:
    name: 10.152.183.59/${IMAGE_NAME}:latest
    entrypoint: [""] # overrides the Dockerfile CMD entrypoint, if given
  script:
    - script1 # scripts are run after the entrypoint
    - script2
  only:
    - main # this job will only be run in some branches
    - somebranch # OR condition
```

or to run jobs using some flags:
```yaml
variables:
  RUN_BUILD: "true"
run:
  tags:
    - myrunner
  stage: run
  image:
    name: 10.152.183.59/${IMAGE_NAME}:latest
    entrypoint: [""] # overrides the Dockerfile CMD entrypoint, if given
  script:
    - script1 # scripts are run after the entrypoint
    - script2
  rules:
    - if: $RUN_BUILD == "true"
      when: always
    - when: never
```

## Preparing interactive access with Jupyter
It is often beneficial for ML/Data science to access an interactive notebook with Jupyter. One can install Jupyter with relevant packages using the following:
```Dockerfile
# note: better to use smaller base image, this is just for demo
FROM pytorch/pytorch:2.6.0-cuda12.4-cudnn9-runtime

RUN pip install --no-cache-dir numpy
RUN pip install --no-cache-dir pandas
RUN pip install --no-cache-dir jupyter_server
RUN pip install --no-cache-dir ipykernel

# create a non-root user
RUN groupadd -r jupyter && useradd -r -g jupyter jupyter

# set work dir and let jupyter notebook access that
WORKDIR /app
RUN chown jupyter:jupyter /app

# set home directory and switch to it
ENV HOME=/home/jupyter
RUN mkdir -p $HOME && chown -R jupyter:jupyter $HOME
USER jupyter
RUN mkdir -p $HOME/.jupyter

CMD ["sh", "-c", "jupyter server --ip=0.0.0.0 --ServerApp.token=${JUPYTER_TOKEN}"]
```

and use Gitlab CI to run the image. In the above, set the environment variable using the `variables` tag in the job:
```yaml
notebook:
  image:
    name: compiled-jupyter-image
  variables:
    JUPYTER_TOKEN: "some-interactive-secure-token"
  stage: run
```

To connect to the Jupyter notebook, open up an `.ipynb` file in VSCode, and press `Select Kernel -> Existing Jupyter Server`. Use some tools like `kubectl port-forward` to forward into the pod hosting the Jupyter server.

## Interactive access with VSCode Remote Extension + SSH

Sometimes, its better to have a full-fledged interactive development experience with Jupyter Notebook and with access to the datasets/repo as if the environment were open locally. [See this file](interactive.md). However all contents in the VSCode extension development environment is expected to be temporary (resets when the pod shuts down)!

## Fast CI/CD testing pipeline

For fast environment setup and testing, it is best to **not have to compile the Docker image** every time a push is done. This is because compiling a Docker image takes time (Kaniko has to interact with Harbor, and afterwards the kubelet has to pull the image from Harbor). It is best to switch off the image compilation pipelines using a flag (and the `rules` tag). Gitlab runners automatically download and update the latest repository contents. So the best behaviour is to set the Docker image up once, and then add the `src/` folder (which will be updated everytime a Gitlab runner job is dispatched). For example:

```yaml
test:
  tags:
      - kubernetes # run using the generic Kubernetes gitlab runner
  stage: test
  image:
    name: 10.152.183.59/${IMAGE_NAME}-basic-env:latest # base environment (without Jupyter or SSH daemon), only with relevant Python packages
  script:
     - export PYTHONPATH="${PYTHONPATH}:${PWD}/src" # export the `src/` folder, will be updated everytime
     - cd tests/ # cd to tests folder
     - python -m unittest discover -s tests -v # add unit tests
```

## Shared and reusable data from PVs
It is often the case one has to re-use data from PVs and create PVCs to mount into different namespaces. Even if "Retain" reclaim policy is set, the data may be unreclaimable due to the PV already having a claim ref, so new PVCs that reference the PV cannot reuse it.

To tackle this problem, one has to modify the PV to delete the claimRef from it, so it is Available. To do so, use `kubectl edit pv <pv name>` and delete the entire `claimRef` section from `spec`. One can delete an entire line using `dd` in `vi`. 

To mass delete all claimRef(s) from the PVs, use the following script, which deletes all `claimRefs` belonging to the `rook-cephfs` storageClass.
```sh
#!/bin/bash

# Get all PVs with storageClass rook-cephfs
PVS=$(kubectl get pv -o json | jq -r '.items[] | select(.spec.storageClassName == "rook-cephfs") | .metadata.name')

# Loop through each PV and remove the claimRef if it exists
for PV in $PVS; do
  echo "Processing PV: $PV"
  
  # Check if claimRef exists for this PV - fixed jq query
  CLAIM_REF_EXISTS=$(kubectl get pv $PV -o json | jq -r 'if .spec.claimRef then "true" else "false" end')
  
  if [ "$CLAIM_REF_EXISTS" = "true" ]; then
    echo "  Removing claimRef from PV: $PV"
    kubectl patch pv $PV --type json -p '[{"op": "remove", "path": "/spec/claimRef"}]'
    echo "  ClaimRef removed successfully"
  else
    echo "  No claimRef found for PV: $PV"
  fi
done

echo "Done processing all rook-cephfs PVs"
```