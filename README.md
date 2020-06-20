# Open Source Summit 2020 - Knative + Tekton Tutorial

<details><summary>Setup</summary>

## Setup

### Tools
- Kubernetes Cluster
    - Get a free Kubernetes cluster on [IBM Cloud](https://cloud.ibm.com), also check out the booth at OSS-NA IBM booth during the conference how to get $200 credit.
    - You can use other kubernetes cluster like minikube or kind
- [Kubernetes CLI]() `kubectl`
- [Knative CLI](https://knative.dev/docs/install/install-kn/) `kn`
- [Tekton CLI]() `tkn`
- [Hey CLI]() `hey`
- [YAML Editor](https://github.com/redhat-developer/vscode-yaml)

### Accounts
- [GitHub](https://github.com/)
- [Dockerhub](https://hub.docker.com/)

### Setup kubectl access

If using IBM Kubernetes FREE cluster
1. Select cluster from IBM Cloud console
1. Click the drop down Action menu on the top right and select **Connect via CLI** and follow the commands.
1. Log in to your IBM Cloud account
    ```sh
    ibmcloud login -a cloud.ibm.com -r <REGION> -g <IAM_RESOURCE_GROUP>
    ```
1. Set the Kubernetes context
    ```sh
    ibmcloud ks cluster config -c mycluster
    ```
1. Verify that you can connect to your cluster.
    ```sh
    kubectl version 
    ```
    Output should show the version of Kubernetes like this:
    ```
    kubectl version --short
    Client Version: v1.18.3
    Server Version: v1.18.3+IKS
    ```

### Setup Git

1. Fork this repository
1. Set the environment variable `GITHUB_REPO_URL` to the url of your fork, not mine.
    ```sh
    GITHUB_REPO_URL=`https://github.com/REPLACEME/knative-tekton`
    ```
1. Clone the repository and change directory
    ```sh
    git clone $GITHUB_REPO_URL
    cd knative-tekton
    ```
1. Generate [GitHub new token](https://github.com/settings/tokens). 
1. Make sure that **repo** and **admin:repo_hook** are seleted 
    <!--TODO: double check what are the minimum access for this tutorial -->
1. Set the following environment variables
    ```sh
    GITHUB_ACCESS_TOKEN='REPLACEME_TOKEN_VALUE'
    ```

### Setup Container Registry

1. Set the environment variables `REGISTRY_NAMESPACE` and `REGISTRY_PASSWORD`, The `REGISTRY_NAMESPACE` most likely would be your dockerhub username.
    ```sh
    REGISTRY_NAMESPACE='REPLACEME_DOCKER_USERNAME_VALUE'
    REGISTRY_PASSWORD='REPLACEME_DOCKER_PASSWORD'
    ```
</details>

<details><summary>Install Knative</summary>

## Install Knative

1. Install Knative Serving
    ```sh
    kubectl apply --filename https://github.com/knative/serving/releases/download/v0.15.1/serving-crds.yaml

    kubectl apply --filename https://github.com/knative/serving/releases/download/v0.15.1/serving-core.yaml
    ```
1. Install Knative Layer kourier
    ```
    kubectl apply --filename https://github.com/knative/net-kourier/releases/download/v0.15.0/kourier.yaml
    ```
1. Set the environment variable `EXTERNAL_IP` to External IP Address of the Worker Node
    ```sh
    EXTERNAL_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
    echo EXTERNAL_IP=$EXTERNAL_IP
    ```
2. Set the environment variable `KNATIVE_DOMAIN` as the DNS domain using `nip.io`
    ```sh
    KNATIVE_DOMAIN="$EXTERNAL_IP.nip.io"
    echo KNATIVE_DOMAIN=$KNATIVE_DOMAIN
    ```
1. Configure DNS for Knative Serving
    ```sh
    kubectl patch configmap -n knative-serving config-domain -p "{\"data\": {\"$KNATIVE_DOMAIN\": \"\"}}"
    ```
1. Configure Kourier to listen on External IP
    ```sh
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: Service
    metadata:
      name: kourier-ingress
      namespace: kourier-system
      labels:
        networking.knative.dev/ingress-provider: kourier
    spec:
      ports:
      - name: http2
        port: 80
        protocol: TCP
        targetPort: 8080
      - name: https
        port: 443
        protocol: TCP
        targetPort: 8443
      selector:
        app: 3scale-kourier-gateway
      type: NodePort
      externalIPs:
        - $EXTERNAL_IP
    EOF
    kubectl get svc -n kourier-system kourier-ingress
    ```
1. Configure Knative to use Kourier
    ```sh
    kubectl patch configmap/config-network \
      --namespace knative-serving \
      --type merge \
      --patch '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'
    ```

</details>

<details><summary>Deploy Applications</summary>

## Deploy Knative Applications

1. Set the environment variable `BASE_URL` to the kubernetes namespace with Domain name `<namespace>.<domainname>`
    ```sh
    SUB_DOMAIN="$(kubectl config view --minify --output 'jsonpath={..namespace}').$KNATIVE_DOMAIN"
    echo SUB_DOMAIN=$SUB_DOMAIN
    ```
1. Using the Knative CLI `kn` deploy an application usig a Container Image
    ```sh
    kn service create hello --image gcr.io/knative-samples/helloworld-go
    ```
1. Use curl to invoke the Application
    ```sh
    curl hello.$SUB_DOMAIN
    ```
    It should print
    ```
    Hello World!
    ```
1. You can watch the pods and see how they scale down to zero after http traffic stops to the url
    ```
    kubectl get pod -l serving.knative.dev/service=hello -w
    ```

    Output should look like this:
    ```
    NAME                                     READY   STATUS
    hello-r4vz7-deployment-c5d4b88f7-ks95l   2/2     Running
    hello-r4vz7-deployment-c5d4b88f7-ks95l   2/2     Terminating
    hello-r4vz7-deployment-c5d4b88f7-ks95l   1/2     Terminating
    hello-r4vz7-deployment-c5d4b88f7-ks95l   0/2     Terminating
    ```

    Try to access the url again, and you will see the new pods running again.
    ```
    NAME                                     READY   STATUS
    hello-r4vz7-deployment-c5d4b88f7-rr8cd   0/2     Pending
    hello-r4vz7-deployment-c5d4b88f7-rr8cd   0/2     ContainerCreating
    hello-r4vz7-deployment-c5d4b88f7-rr8cd   1/2     Running
    hello-r4vz7-deployment-c5d4b88f7-rr8cd   2/2     Running
    ```
    Some people call this **Serverless** 🎉 🌮 🔥

## Using the kn CLI

1. Update the service hello with a new environment variable `TARGET`
    ```sh
    kn service update hello --env TARGET="World from v1" 
    ```
1. Now invoke the service
    ```sh
    curl hello.$SUB_DOMAIN
    ```
    It should print
    ```
    Hello World from v1!
    ```

## Traffic Splitting

1. Update the service hello by updating the environment variable `TARGET`, tag the previous version `v1`, send 25% traffic to this new version and leaving 75% of the traffic to `v1`
    ```sh
    kn service update hello \
     --env TARGET="Knative from v2" \
     --tag $(kubectl get ksvc hello --template='{{.status.latestReadyRevisionName}}')=v1 \
     --traffic v1=75,@latest=25
    ```
1. Describe the service to see the traffic split details
    ```sh
    kn service describe  hello
    ```
    Should print this
    ```
    Name:       hello
    Namespace:  debug
    Age:        6m
    URL:        http://hello.$SUB_DOMAIN

    Revisions:  
      25%  @latest (hello-mshgs-3) [3] (26s)
            Image:  gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
      75%  hello-tgzmt-2 #v1 [2] (6m)
            Image:  gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)

    Conditions:  
      OK TYPE                   AGE REASON
      ++ Ready                  21s 
      ++ ConfigurationsReady    24s 
      ++ RoutesReady            21s 
    ```
1. Invoke the service usign a while loop you will see the message `Hello Knative from v2` 25% of the time
    ```sh
    while true; do
    curl hello.$SUB_DOMAIN 
    done
    ```
    Should print this
    ```
    Hello World from v1!
    Hello Knative from v2!
    Hello World from v1!
    Hello World from v1!
    ```
1. Update the service this time dark launch new version `v3` on a specific url, zero traffic will go to this version from the main url of the service
    ```sh
    kn service update hello \
        --env TARGET="OSS NA 2020 from v3" \
        --tag $(kubectl get ksvc hello --template='{{.status.latestReadyRevisionName}}')=v2 \
        --tag @latest=v3 \
        --traffic v1=75,v2=25,@latest=0
    ```
1. The latest version of the service is only available url prefix `v3-`, go ahead and invoke the latest directly.
    ```sh
    curl v3-hello.$SUB_DOMAIN
    ```
    It shoud print this
    ```
    Hello OSS NA from v3!
    ```
1. We are happy with our secret new version of the application, latest make it live to 100% of the user on the default url
    ```sh
    kn service update hello --traffic @latest=100
    ```
1. If we invoke the service in a loop you will see that 100% of the traffic is directed to version `v3` of our application
    ```sh
    while true; do
    curl hello.$SUB_DOMAIN 
    done
    ```
    Should print this
    ```
    Hello OSS NA 2020 from v3!
    Hello OSS NA 2020 from v3!
    Hello OSS NA 2020 from v3!
    Hello OSS NA 2020 from v3!
    ```
2. By using tags the custom urls with tag prefix are still available, in case you want to access an old revision of the application
    ```sh
    curl v1-hello.$SUB_DOMAIN 
    curl v2-hello.$SUB_DOMAIN 
    curl v3-hello.$SUB_DOMAIN 
    ```
    It should print
    ```
    Hello World from v1!
    Hello Knative from v2!
    Hello OSS NA 2020 from v3!
    ```
3. Now that you have your service configure and deploy, you want to reproduce this using a kubernetes manifest using YAML in a different namespace or cluster. You can define your Knative service usign the following YAML
    ```yaml
    ---
    apiVersion: serving.knative.dev/v1
    kind: Service
    metadata:
      name: hello
    spec:
      template:
        metadata:
          name: hello-tgzmt-1
        spec:
          containers:
            - env:
                - name: TARGET
                  value: World from v1
              image: gcr.io/knative-samples/helloworld-go
    ---
    apiVersion: serving.knative.dev/v1
    kind: Service
    metadata:
      name: hello
    spec:
      template:
        metadata:
          name: hello-mshgs-2
        spec:
          containers:
            - env:
                - name: TARGET
                  value: Knative from v2
              image: gcr.io/knative-samples/helloworld-go
    ---
    apiVersion: serving.knative.dev/v1
    kind: Service
    metadata:
      name: hello
    spec:
      template:
        metadata:
          name: hello-pxgxx-3
        spec:
          containers:
            - env:
                - name: TARGET
                  value: OSS NA 2020 from v3
              image: gcr.io/knative-samples/helloworld-go
      traffic:
        - latestRevision: true
          percent: 100
          tag: v3
        - latestRevision: false
          percent: 0
          revisionName: hello-tgzmt-1
          tag: v1
        - latestRevision: false
          percent: 0
          revisionName: hello-mshgs-2
          tag: v2
    ```

</details>
