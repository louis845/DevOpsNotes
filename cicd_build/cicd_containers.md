Temp md file for Gitlab CI/CD

```
stages:
   - build
   - run

variables:
  CI_REGISTRY_USER: "admin"
  CI_REGISTRY_PASSWORD: "Harbor12345"
  IMAGE_NAME: library/data-processor

build:
  tags:
     - harbor
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"10.152.183.59\":{\"username\":\"${CI_REGISTRY_USER}\",\"password\":\"${CI_REGISTRY_PASSWORD}\"}}}" > /kaniko/.docker/config.json
    - >-
      /kaniko/executor
      --context "${CI_PROJECT_DIR}"
      --dockerfile "${CI_PROJECT_DIR}/Dockerfile"
      --destination "10.152.183.59/${IMAGE_NAME}:${CI_COMMIT_SHORT_SHA}"
      --destination "10.152.183.59/${IMAGE_NAME}:latest"
      --registry-certificate 10.152.183.59=/etc/harbor/certs/harbor.example.local.crt
      --cache=true
      --cache-repo="10.152.183.59/${IMAGE_NAME}/cache"
  only:
    - main

buildInteractive:
  tags:
     - harbor
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"10.152.183.59\":{\"username\":\"${CI_REGISTRY_USER}\",\"password\":\"${CI_REGISTRY_PASSWORD}\"}}}" > /kaniko/.docker/config.json
    - >-
      /kaniko/executor
      --context "${CI_PROJECT_DIR}"
      --dockerfile "${CI_PROJECT_DIR}/Dockerfile2"
      --destination "10.152.183.59/${IMAGE_NAME}_interactive:${CI_COMMIT_SHORT_SHA}"
      --destination "10.152.183.59/${IMAGE_NAME}_interactive:latest"
      --registry-certificate 10.152.183.59=/etc/harbor/certs/harbor.example.local.crt
      --cache=true
  only:
    - main

buildInteractiveGPU:
  tags:
     - harbor
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"10.152.183.59\":{\"username\":\"${CI_REGISTRY_USER}\",\"password\":\"${CI_REGISTRY_PASSWORD}\"}}}" > /kaniko/.docker/config.json
    - >-
      /kaniko/executor
      --context "${CI_PROJECT_DIR}"
      --dockerfile "${CI_PROJECT_DIR}/Dockerfile3"
      --destination "10.152.183.59/${IMAGE_NAME}-gpu_interactive:${CI_COMMIT_SHORT_SHA}"
      --destination "10.152.183.59/${IMAGE_NAME}-gpu_interactive:latest"
      --registry-certificate 10.152.183.59=/etc/harbor/certs/harbor.example.local.crt
      --cache=true
  only:
    - main

run:
  tags:
     - kubernetes
  stage: run
  image: 
    name: 10.152.183.59/${IMAGE_NAME}:${CI_COMMIT_SHORT_SHA}
  script:
    - python app.py
  only:
    - main
```