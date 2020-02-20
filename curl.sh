#!/bin/bash

PROJ=demo

while true; do
  curl $(oc get route/frontend -n $PROJ -o jsonpath='{"http://"}{.spec.host}')
  sleep 2
done