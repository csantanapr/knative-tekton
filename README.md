# Open Source Summit NA 2020 - Knative + Tekton Tutorial

<details><summary>1. Setup Environment</summary>

## 1. Setup Environment

### Tools
- Kubernetes Cluster
    - Get a free Kubernetes cluster on [IBM Cloud](https://cloud.ibm.com), also check out the booth at OSS-NA IBM booth during the conference how to get $200 credit.
    - You can use other kubernetes cluster like [minikube](https://minikube.sigs.k8s.io) or [kind](https://kind.sigs.k8s.io/)
- [Kubernetes CLI]() `kubectl`
- [Knative CLI](https://knative.dev/docs/install/install-kn/) `kn`
- [Tekton CLI](https://github.com/tektoncd/cli#installing-tkn) `tkn`

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

1. Fork this repository https://github.com/csantanapr/knative-tekton
1. Set the environment variable `GIT_REPO_URL` to the url of your fork, not mine. And your Git username `GIT_USERNAME`
    ```sh
    GIT_REPO_URL='https://github.com/REPLACEME/knative-tekton'
    GIT_USERNAME='REPLACE_WITH_USERNAME_FOR_AUTH'
    ```
1. Clone the repository and change directory
    ```sh
    git clone $GIT_REPO_URL
    cd knative-tekton
    ```
1. Generate [GitHub new token](https://github.com/settings/tokens). 
1. Make sure that **repo** and **admin:repo_hook** are seleted 
    <!--TODO: double check what are the minimum access for this tutorial -->
1. Set the following environment variables
    ```sh
    GIT_ACCESS_TOKEN='REPLACEME_TOKEN_VALUE'
    ```

### Setup Container Registry

1. Set the environment variables `REGISTRY_SERVER`, `REGISTRY_NAMESPACE` and `REGISTRY_PASSWORD`, The `REGISTRY_NAMESPACE` most likely would be your dockerhub username. For Dockerhub use `docker.io` as the value for ` 
    ```sh
    REGISTRY_SERVER='docker.io'
    REGISTRY_NAMESPACE='REPLACEME_DOCKER_USERNAME_VALUE'
    REGISTRY_PASSWORD='REPLACEME_DOCKER_PASSWORD'
    ```
</details>

<details><summary>2. Install Knative Serving</summary>

## 2. Install Knative Serving

1. Install Knative Serving in namespace `knative-serving`
    ```sh
    kubectl apply --filename https://github.com/knative/serving/releases/download/v0.15.1/serving-crds.yaml

    kubectl apply --filename https://github.com/knative/serving/releases/download/v0.15.1/serving-core.yaml
    ```
1. Install Knative Layer kourier in namespace `kourier-system`
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

<details><summary>3. Using Knative to Run Serverless Applications</summary>

## Using Knative to Run Serverless Applications

1. Set the environment variable `BASE_URL` to the kubernetes namespace with Domain name `<namespace>.<domainname>`
    ```sh
    SUB_DOMAIN="$(kubectl config view --minify --output 'jsonpath={..namespace}').$KNATIVE_DOMAIN"
    echo SUB_DOMAIN=$SUB_DOMAIN
    ```
1. Using the Knative CLI `kn` deploy an application usig a Container Image
    ```sh
    kn service create hello --image gcr.io/knative-samples/helloworld-go
    ```
1. You can see list your service
    ```sh
    kn service list hello
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
1. By using tags the custom urls with tag prefix are still available, in case you want to access an old revision of the application
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
1. Now that you have your service configure and deploy, you want to reproduce this using a kubernetes manifest using YAML in a different namespace or cluster. You can define your Knative service using the following YAML you can use the command `kn service export`
    <details><summary>Show me the YAML</summary>

    ```yaml
    ---
    apiVersion: serving.knative.dev/v1
    kind: Service
    metadata:
      name: hello
    spec:
      template:
        metadata:
          name: hello-v1
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
          name: hello-v2
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
          name: hello-v3
        spec:
          containers:
            - env:
                - name: TARGET
                  value: OSS NA 2020 from v3
              image: gcr.io/knative-samples/helloworld-go
      traffic:
        - latestRevision: false
          percent: 0
          revisionName: hello-v1
          tag: v1
        - latestRevision: false
          percent: 0
          revisionName: hello-v2
          tag: v2
        - latestRevision: true
          percent: 100
          tag: v3
    ```
    </details>

    If you want to deploy usign YAML, delete the Application with `kn` and redeploy with `kubectl`
    ```sh
    kn delete service hello
    kubectl apply -f ./knative/v1v2v3.yaml
    ```
1. Delete the Application and all it's revisions
    ```sh
    kn service delete hello
    ```

</details>

<details><summary>4. Install Tekton Pipelines</summary>

## 4. Install Tekton

1. Install Tekton Pipelines in namespace `tekton-pipelines`
    ```sh
    kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.13.2/release.yaml
    ```

1. Install Tekton Dashboard in namespace `tekton-pipelines` (Optional)
    ```sh
    kubectl apply --filename https://github.com/tektoncd/dashboard/releases/download/v0.7.0/tekton-dashboard-release.yaml
    ```
    To access the dashboard you can configure a service with `NodePort`
    ```sh
    kubectl expose service tekton-dashboard --name tekton-dashboard-ingress --type=NodePort -n tekton-pipelines
    ```
    Set an environment variable `TEKTON_DASHBOARD_URL` with the url to access the Dashboard
    ```sh
    EXTERNAL_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
    TEKTON_DASHBOARD_NODEPORT=$(kubectl get svc tekton-dashboard-ingress -n tekton-pipelines -o jsonpath='{.spec.ports[0].nodePort}')
    TEKTON_DASHBOARD_URL=http://$EXTERNAL_IP:$TEKTON_DASHBOARD_NODEPORT
    echo TEKTON_DASHBOARD_URL=$TEKTON_DASHBOARD_URL
    ```

</details>

<details><summary>5. Using Tekton to Build and Deploy Applications</summary>

## Using Tekton to Build Applications

- Tekton helps create composable DevOps Automation by putting together **Tasks**, and **Pipelines**

<details><summary>5.1 Configure Access for Tekton</summary>

### 5.1 Configure Access for Tekto

1. In this repository we have a sample application, you can see the source code in [src/app.js](./src//app.js) This application is using JavaScript to implement a web server, but you can use any language you want.
    ```javascript
    const app = require("express")()
    const server = require("http").createServer(app)
    const port = process.env.PORT || "8080"
    const message = process.env.MESSAGE || 'Hello World'

    app.get('/', (req, res) => res.send(message))
    server.listen(port, function () {
        console.log(`App listening on ${port}`)
    });
    ```
1. We need to package our application in a Container Image and store this Image in a Container Registry. Since we are going to need to create secrets with the registry credentials we are going to create a ServiceAccount `pipelines` with the associated secret `regcred`. Make sure you setup your container credentials as environment variables. Checkout the [Setup Container Registry](#setup-container-registry) in the Setup Environment section on this tutorial. This commands will print your credentials make sure no one is looking over, the printed command is what you need to run.
    ```sh
    echo kubectl create secret docker-registry regcred \
      --docker-server=\'${REGISTRY_SERVER}\' \
      --docker-username=\'${REGISTRY_NAMESPACE}\' \
      --docker-password=\'${REGISTRY_PASSWORD}\'
    echo "Run the previous command manually ^ this avoids problems with charaters in the shell"
    ```
    NOTE: If you password have some characters that are interpreted by the shell, then do NOT use environment variables, explicit enter your values in the command wrapped by single quotes `'`
1. Create a ServiceAccount `pipeline` that contains the secret `regsecret` that we just created
    ```yaml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: pipeline
    secrets:
      - name: regcred
    ```
    Run the following command with the provided `YAML`
    ```sh
    kubectl apply -f tekton/sa.yaml
    ```
1. We are going to be using Tekton to deploy the Knative Service, we need to configure RBAC to provide edit access to the current namespace `default` to the ServiceAccount `pipeline` if you are using a different namespace than `default` edit the file `tekton/rbac.yaml` and provide the namespace where to create the `Role` and the `RoleBinding` fo more info check out the [RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) docs. Run the following command to grant access to sa `pipelines`
    ```sh
    kubectl apply -f tekton/rbac.yaml
    ```

</details>

<details><summary>5.2 The Build Tekton Task</summary>

### 5.2 The Build Tekton Task

1. I provided a Tekton Task that can download source code from git, build and push the Image to a registry. Install the task _build_ like this
    ```sh
    kubectl apply -f tekton/task-build.yaml
    ```
1. You can list the task that we just created using the `tkn` CLI
    ```sh
    tkn task ls
    ```
1. We can also get more details about the _build_ **Task** using `tkn task describe`
    ```
    tkn task describe build
    ```
1. Let's use the Tekton CLI to test our _build_ **Task** you need to pass the ServiceAccount `pipeline` to be use to run the Task. You will need to pass the GitHub URL to your fork or use this repository. You will need to pass the directory within the repository where the application in our case is `nodejs`. The repository image name is `knative-tekton`
    ```sh
    tkn task start build --showlog \
      -p repo-url=${GIT_REPO_URL} \
      -p image=${REGISTRY_SERVER}/${REGISTRY_NAMESPACE}/knative-tekton \
      -p CONTEXT=nodejs \
      -s pipeline 
    ```
1. You can check out the container registry and see that the image was pushed to repository a minute ago, it should return status Code `200`
    ```sh
    curl -s -o /dev/null -w "%{http_code}\n" https://index.$REGISTRY_SERVER/v1/repositories/$REGISTRY_NAMESPACE/knative-tekton/tags/latest
    ```
</details>

<details><summary>5.3 The Deploy Tekton Task</summary>

### 5.3 The Deploy Tekton Task

1. I provided a Tekton Task that can run `kubectl` to deploy the Knative Application using a YAML manifest. Install the task _deploy_ like this
    ```sh
    kubectl apply -f tekton/task-deploy.yaml
    ```
1. I provided a Task YAML that defines our Knative Application in [knative/service.yaml](./knative/service.yaml)
    ```yaml
    apiVersion: serving.knative.dev/v1
    kind: Service
    metadata:
      name: demo
    spec:
      template:
        spec:
          containers:
            - image: docker.io/csantanapr/knative-tekton
              imagePullPolicy: Always
              env:
                - name: MESSAGE
                  value: Welcome to OSS NA 2020 !
    ```
1. Let's use the Tekton CLI to test our _deploy_ **Task** you need to pass the ServiceAccount `pipeline` to be use to run the Task. You will need to pass the GitHub URL to your fork or use this repository. You will need to pass the directory within the repository where the application yaml manifest is located and the file name in our case is `knative` and `service.yaml` .
    ```sh
    tkn task start deploy --showlog \
      -p image=${REGISTRY_SERVER}/${REGISTRY_NAMESPACE}/knative-tekton \
      -p repo-url=${GIT_REPO_URL} \
      -p dir=knative \
      -p yaml=service.yaml \
      -s pipeline 
    ```
1. You can check out that the Knative Application was deploy
    ```sh
    kn service list demo
    ```

</details>

<details><summary>5.4 The Build and Deploy Pipeline</summary>

### 5.4 The Build and Deploy Pipeline

1. If we want to build the application image and then deploy the application, we can run the Tasks **build** and **deploy** by defining a **Pipeline** that contains the two Tasks, deploy the Pipeline `build-deploy`
    ```sh
    kubectl apply -f tekton/pipeline-build-deploy.yaml
    ```
1. You can list the pipeline that we just created using the `tkn` CLI
    ```sh
    tkn pipeline ls
    ```
1. We can also get more details about the _build-deploy_ **Pipeline** using `tkn pipeline describe`
    ```
    tkn pipeline describe build-deploy
    ```
1. Let's use the Tekton CLI to test our _build-deploy_ **Pipeline** you need to pass the ServiceAccount `pipeline` to be use to run the Tasks. You will need to pass the GitHub URL to your fork or use this repository. You will also pass the Image location where to push in the the registry and where Kubernetes should pull the image for the Knative Application. The directory and filename for the Kantive yaml are already specified in the Pipeline definition.
    ```sh
    tkn pipeline start build-deploy --showlog \
      -p image=${REGISTRY_SERVER}/${REGISTRY_NAMESPACE}/knative-tekton \
      -p repo-url=${GIT_REPO_URL} \
      -s pipeline 
    ```
1. You can inpect the results and duration by describing the last **PipelineRun**
    ```sh
    tkn pipelinerun describe --last
    ```
1. Check that the latest Knative Application revision is ready
    ```sh
    kn service list demo
    ```
1. Run the Application using the url
    ```sh
    curl http://demo.$SUB_DOMAIN
    ```
    It shoudl print
    ```
    Welcome to OSS NA 2020  🎉 🌮 🔥 🤗!
    ```
</details>

</details>



<details><summary>6. Automate the Tekton Pipeline using Git Web Hooks Triggers</summary>

## 6. Automate the Tekton Pipeline using Git Web Hooks

### 6.1 Install Tekton Triggers

1. Install Tekton Triggers in namespace `tekton-pipelines`
    ```sh
    kubectl apply --filename  https://storage.googleapis.com/tekton-releases/triggers/previous/v0.5.0/release.yaml
    ``` 

### 6.2 Create TriggerTemplate, TriggerBinding

1. When the Webhook invokes we want to start a Pipeline, we will a `TriggerTemplate` to use a specification on which Tekton resources should be created, in our case will be creating a new `PipelineRun` this will start a new `Pipeline` install
    ```sh
    kubectl apply -f tekton/trigger-template.yaml
    ```
1. When the Webhook invokes we want to extract information from the Web Hook http request sent by the Git Server, we will use a `TriggerBinding` this information is what gets passed to the `TriggerTemplate`
    ```sh
    kubectl apply -f tekton/trigger-binding.yaml
    ```

### 6.3 Create Trigger EventListener

1. To be able to handle the http request sent by the GitHub Webhook, we need a webserver. Tekton provides a way to define this listeners that takes the `TriggerBinding` and the `TriggerTemplate` as specification. We can specify Interceptors to handle any customization for example I only want to start a new **Pipeline** only when push happens on the main branch.
    ```sh
    kubectl apply -f tekton/trigger-listener.yaml
    ```
1. The Eventlister creates a deployment and a service you can list both using this command
    ```sh
    kubectl get deployments,eventlistener,svc -l eventlistener=cicd
    ```

### 6.4 Get URL for Git Hook

- It will depend on your cluster and how traffic is configured into your Kubernetes Cluster, you would need to configure an Application Load Balancer (ALB), Ingress, or in case of OpenShift a Route. If you are running the Kubernetes cluster on your local workstation using something minikube, kind, docker-desktop, or k3s then you I recommend a Cloud Native Tunnel solution like [inlets](https://docs.inlets.dev/#/) a by the open source contributor [Alex Ellis](https://twitter.com/alexellisuk) 

1. Expose the EventListener as `NodePort`
    ```sh
    kubectl expose service el-cicd --name el-cicd-ingress --type=NodePort
    ```
1. Get the url using the external IP of the worker node and the `NodePort` assign. Set an environment variable `GIT_WEBHOOK_URL`
    ```sh
    EXTERNAL_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
    GIT_WEBHOOK_NODEPORT=$(kubectl get svc el-cicd-ingress -o jsonpath='{.spec.ports[0].nodePort}')
    GIT_WEBHOOK_URL=http://$EXTERNAL_IP:$GIT_WEBHOOK_NODEPORT
    echo GIT_WEBHOOK_URL=$GIT_WEBHOOK_URL
    ```
    **WARNING:** Take into account that this URL is insecure is using http and not https, this means you should not use this type of URL for real work environments, In that case you would need to expose the service for the eventlistener using a secure connection using *https** 
1. Add the Git Web Hook url to your Git repository
    1. Open Settings in your Github repository
    1. Click **Webhooks**
    1. Click **Add webhook**
    1. Copy and paste the `$GIT_WEBHOOK_URL` value into the **Payload URL**
    1. Select Content type **application/json**
    1. Click **Add webhook**
1. (Optional) Another option instead of doing it manually you can use the following to create the git webhook programatically
    ```sh
    curl -v -X POST -u $GIT_USERNAME:$GIT_ACCESS_TOKEN \
    -d "{\"name\": \"web\",\"active\": true,\"events\": [\"push\"],\"config\": {\"url\": \"$GIT_WEBHOOK_URL\",\"content_type\": \"json\",\"insecure_ssl\": \"1\"}}" \
    -L https://api.github.com/repos/$GIT_USERNAME/knative-tekton/hooks
    ```
1. Now make a change to application manifest such like changing the message in [knative/service.yaml](./knative/service.yaml) to something like `My First Serveless App @ OSS NA 2020  🎉 🌮 🔥 🤗!` and push the change to the default branch
1. A new Tekton **PipelineRun** gets created starting a new **Pipeline** Instance. You can check in the Tekton Dashboard for progress of use the tkn CLI
    ```sh
    tkn pipeline logs -f --last
    ```
1. To see the details of the execution of the PipelineRun use the tkn CLI
    ```sh
    tkn pipelinerun describe --last
    ```
1. The Knative Application Application is updated with the new Image built using the tag value of the 7 first characters of the git commit sha, describe the service using the kn CLI
    ```sh
    kn service describe demo
    ```
1. Invoke your new built revision for the Knative Application
    ```sh
    curl http://demo.$SUB_DOMAIN
    ```
    It should print
    ```
    My First Serveless App @ OSS NA 2020  🎉 🌮 🔥 🤗!
    ```

</details>
