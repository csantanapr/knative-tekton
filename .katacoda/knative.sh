#!/bin/bash

# Install kn cli
curl -sL -o /usr/local/bin/kn https://github.com/knative/client/releases/download/v0.15.2/kn-linux-amd64
chmod +x /usr/local/bin/kn

kubectl apply --filename https://github.com/knative/serving/releases/download/v0.15.1/serving-crds.yaml
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.15.1/serving-core.yaml
kubectl apply --filename https://github.com/knative/net-kourier/releases/download/v0.15.0/kourier.yaml
EXTERNAL_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo EXTERNAL_IP=$EXTERNAL_IP
KNATIVE_DOMAIN="$EXTERNAL_IP.nip.io"
echo KNATIVE_DOMAIN=$KNATIVE_DOMAIN
kubectl patch configmap -n knative-serving config-domain -p "{\"data\": {\"$KNATIVE_DOMAIN\": \"\"}}"
export SUB_DOMAIN="default.$KNATIVE_DOMAIN"
echo SUB_DOMAIN=$SUB_DOMAIN

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: kourier-ingress
  namespace: kourier-system
  labels:
    networking.knative.dev/ingress-provider: kourier
spec:
  selector:
    app: 3scale-kourier-gateway
  ports:
    - name: http2
      port: 80
      protocol: TCP
      targetPort: 8080
  externalIPs:
    - $EXTERNAL_IP
EOF

kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'
kubectl get pods -n knative-serving
kubectl get pods -n kourier-system
kubectl get svc  -n kourier-system kourier-ingress


