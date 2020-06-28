# Minikube: Open Source Summit NA 2020 - Knative + Tekton Tutorial

<details><summary>1. Setup Environment</summary>


<details><summary>1.1 Setup Kubernetes Clusters</summary>

<details><summary>1.1.1 Kubernetes with Minikube</summary>

1. Install [minikube](https://minikube.sigs.k8s.io) Linux, MacOS, Windows. This tutorial was tested with version `v1.11.0`. You can verify version with
    ```
    minkube update-check
    ```
1. Configure your cluster 2 CPUs, 2 GB Memory, and version of kubernetes `v1.18.5`. If you already have a minikube with different config, you need to delete it for new configuration to take effect or create a new profile.
    ```
    minikube delete
    minikube config set cpus 2
    minikube config set memory 2048
    minikube config set kubernetes-version v1.18.5
    ```
1. Start your minikube cluster
    ```
    minikube start
    ```
1. Verify versions if the `kubectl`, the cluster, and that you can connect to your cluster.
    ```bash
    kubectl version --short
    ```

</details>

</details>

<details><summary>1.2 Setup Command Line Interface (CLI) Tools</summary>

- [Kubernetes CLI](https://kubernetes.io/docs/tasks/tools/install-kubectl) `kubectl`
- [Knative CLI](https://knative.dev/docs/install/install-kn/) `kn`
- [Tekton CLI](https://github.com/tektoncd/cli#installing-tkn) `tkn`

</details>

<details><summary>1.3 Setup Container Registry</summary>

- Get access to a container registry such as quay, dockerhub, or your own private registry instance from a Cloud provider such as IBM Cloud 😉. On this tutorial we are going to use [Dockerhub](https://hub.docker.com/)

- Set the environment variables `REGISTRY_SERVER`, `REGISTRY_NAMESPACE` and `REGISTRY_PASSWORD`, The `REGISTRY_NAMESPACE` most likely would be your dockerhub username. For Dockerhub use `docker.io` as the value for `REGISTRY_SERVER`
    ```bash
    REGISTRY_SERVER='docker.io'
    REGISTRY_NAMESPACE='REPLACEME_DOCKER_USERNAME_VALUE'
    REGISTRY_PASSWORD='REPLACEME_DOCKER_PASSWORD'
    ```

</details>

<details><summary>1.4 Setup Git</summary>

- Get access to a git server such as gitlab, github, or your own private git instance from a Cloud provider such as IBM Cloud 😉. On this tutorial we are going to use [GitHub](https://github.com/)

1. Fork  this repository
1. Clone the repository and change directory
    ```bash
    git clone https://github.com/<REPLACE_YOUR_GIT_USER_OR_ORG>/knative-tekton
    cd knative-tekton
    ```

</details>

</details>
