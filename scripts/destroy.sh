#!/bin/bash

set -e  # exit immediately on error
set -u  # fail on undeclared variables

kapp delete -y -a oss-rabbitmq-cluster
kubectl delete -f https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml
kapp delete -y -a oss-rabbitmq-secrets
kubectl delete -f https://github.com/carvel-dev/secretgen-controller/releases/latest/download/release.yml
kapp delete -y -a oss-rabbitmq-namespace

exit 0