#!/bin/bash

PROJ=demo

cd $(dirname $0)
BASE=$(pwd)
cd - >> /dev/null

set -e

oc new-project $PROJ || oc project $PROJ

echo "*** Building backend..."

oc new-app \
  -n $PROJ \
  --name=backend \
  --binary \
  --build-env=IMPORT_URL=. \
  --build-env=INSTALL_URL=simpleweb \
  --docker-image=docker.io/centos/go-toolset-7-centos7:latest

oc patch dc/backend \
  -n $PROJ \
  -p '{"spec":{"template":{"metadata":{"labels":{"app":"backend","version":"v1"},"annotations":{"sidecar.istio.io/inject":"true"}}}}}'

echo "*** Pausing to allow imagestream to be created..."
sleep 3

oc start-build backend \
  -n $PROJ \
  --follow \
  --from-dir=${BASE}/src

oc expose dc/backend --port=8080 -n $PROJ

oc patch svc/backend \
  -n $PROJ \
  --type=json \
  -p='[{"op":"add","path":"/spec/ports/0/name","value":"http"}]'

cat <<EOF | oc create -n $PROJ -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: backend
spec:
  host: backend
EOF

echo "*** Deploying frontend..."

oc create cm frontend --from-file=${BASE}/nginx.conf.d -n $PROJ

oc new-app \
  -n $PROJ \
  --name=frontend \
  --docker-image=docker.io/bitnami/nginx:1.16

oc patch dc/frontend \
  -n $PROJ \
  -p '{"spec":{"template":{"metadata":{"labels":{"app":"frontend","version":"v1"},"annotations":{"sidecar.istio.io/inject":"true"}}}}}'

oc set volumes dc/frontend \
  -n $PROJ \
  --add \
  -t configmap \
  --mount-path /opt/bitnami/nginx/conf/server_blocks \
  --configmap-name frontend

oc patch svc/frontend \
  -n $PROJ \
  --type=json \
  -p='[{"op":"add","path":"/spec/ports/0/name","value":"http"},{"op":"add","path":"/spec/ports/1/name","value":"https"}]'

oc expose svc/frontend -n $PROJ

cat <<EOF | oc create -n $PROJ -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: frontend
spec:
  host: frontend
EOF

#cat <<EOF | oc create -n $PROJ -f -
#apiVersion: networking.istio.io/v1alpha3
#kind: VirtualService
#metadata:
#  name: frontend
#spec:
#  hosts:
#  - frontend
#  http:
#  - route:
#    - destination:
#        host: frontend
#      weight: 100
#EOF