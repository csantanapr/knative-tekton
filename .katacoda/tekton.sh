#!/bin/bash

# Install tkn CLI
curl -sLO https://github.com/tektoncd/cli/releases/download/v0.10.0/tkn_0.10.0_Linux_x86_64.tar.gz
tar -xf  tkn_0.10.0_Linux_x86_64.tar.gz -C /usr/local/bin

kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.13.2/release.yaml
kubectl apply --filename https://github.com/tektoncd/dashboard/releases/download/v0.7.0/tekton-dashboard-release.yaml
kubectl wait pod --all --for=condition=Ready -n tekton-pipelines

kubectl expose service tekton-dashboard --name tekton-dashboard-ingress --type=NodePort -n tekton-pipelines

EXTERNAL_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo EXTERNAL_IP=$EXTERNAL_IP
TEKTON_DASHBOARD_NODEPORT=$(kubectl get svc tekton-dashboard-ingress -n tekton-pipelines -o jsonpath='{.spec.ports[0].nodePort}')
TEKTON_DASHBOARD_URL=http://$EXTERNAL_IP:$TEKTON_DASHBOARD_NODEPORT
echo TEKTON_DASHBOARD_URL=$TEKTON_DASHBOARD_URL

kubectl get pods -n tekton-pipelines
kubectl get svc tekton-dashboard-ingress -n tekton-pipelines

kubectl apply -f tekton/sa.yaml
kubectl apply -f tekton/rbac.yaml
