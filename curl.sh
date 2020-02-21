#!/bin/bash

PROJ=demo

if [ $(oc get gateway frontend-gateway -n $PROJ --no-headers 2>/dev/null | wc -l) -lt 1 ]; then
  GATEWAY=$(oc get route/frontend -n $PROJ -o jsonpath='{.spec.host}')
  echo "gateway object does not exist"
else
  GATEWAY=$(oc get route/istio-ingressgateway -n istio-system -o jsonpath='{.spec.host}')
  echo "gateway object exists"
fi

GATEWAY='http://'${GATEWAY}
echo "sending requests to $GATEWAY"

while true; do
  curl $GATEWAY
  sleep 2
done