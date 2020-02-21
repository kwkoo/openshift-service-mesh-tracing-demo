#!/bin/bash

# Operator YAML artefacts copied from:
# https://github.com/vpavlin/odh-kf-manifests/tree/rhservicemesh/istio/service-mesh-cluster/base

set -e

echo "Installing Elasticsearch operator..."
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: elasticsearch-operator
  namespace: openshift-operators 
spec:
  channel: "4.3"
  name: elasticsearch-operator
  source: redhat-operators 
  sourceNamespace: openshift-marketplace
EOF

echo "Installing Jaeger operator..."
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: jaeger-product
  namespace: openshift-operators 
spec:
  channel: "stable"
  name: jaeger-product
  source: redhat-operators 
  sourceNamespace: openshift-marketplace
EOF

echo "Installing Kiali operator..."
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kiali-ossm
  namespace: openshift-operators 
spec:
  channel: "stable"
  name: kiali-ossm
  source: redhat-operators 
  sourceNamespace: openshift-marketplace
EOF

echo "Installing Service Mesh operator..."
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: servicemeshoperator
  namespace: openshift-operators 
spec:
  channel: "1.0"
  name: servicemeshoperator
  source: redhat-operators 
  sourceNamespace: openshift-marketplace
EOF

echo "Deploying Service Mesh control plane..."
oc new-project istio-system

echo -n "Waiting for ClusterServiceVersions to be copied..."
while [ $(oc get clusterserviceversion -n istio-system --no-headers 2>/dev/null | wc -l) -lt 4 ]; do
  echo -n "."
  sleep 1
done

echo "done"

echo "Creating ServiceMeshControlPlane..."
cat <<EOF | oc apply -f -
apiVersion: maistra.io/v1
kind: ServiceMeshControlPlane
metadata:
  name: basic-install
  namespace: istio-system
spec:
  istio:
    gateways:
      istio-egressgateway:
        autoscaleEnabled: false
      istio-ingressgateway:
        autoscaleEnabled: false
    mixer:
      policy:
        autoscaleEnabled: false
      telemetry:
        autoscaleEnabled: false
    pilot:
      autoscaleEnabled: false
      traceSampling: 100
    kiali:
      enabled: true
    grafana:
      enabled: true
    tracing:
      enabled: true
      jaeger:
        template: all-in-one
EOF

echo "Creating ServiceMeshMemberRoll..."
cat <<EOF | oc apply -f -
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: istio-system
spec:
  members:
    - demo
EOF

echo -n "Waiting for all 12 pods to come up..."
COUNT=-1
while true; do
  NEWCOUNT=$(oc get po -n istio-system --no-headers 2>/dev/null | grep Running | wc -l)
  if [ $NEWCOUNT -ne $COUNT ]; then
    echo -n $NEWCOUNT
    COUNT=$NEWCOUNT
    if [ $COUNT -ge 12 ]; then
      echo "done"
      break
    fi
  fi
  echo -n "."
  sleep 5
done
