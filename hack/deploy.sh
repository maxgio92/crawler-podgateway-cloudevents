#!/usr/bin/env bash

set -ex

current="$(dirname -- "${BASH_SOURCE[0]}")"
deploydir="${current}/../deploy"

CLUSTER_NAME="${CLUSTER_NAME:-cloudevents-crawler-pod}"

function main() {
	kn quickstart kind --name $CLUSTER_NAME || true

	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.1/cert-manager.yaml
	kubectl wait deployment -n cert-manager cert-manager-webhook --for condition=Available=True --timeout=90s

	kubectl apply -k $deploydir

	tmpdir=$(mktemp -d)
	git clone git@github.com:maxgio92/helm-charts.git $tmpdir
	git -C $tmpdir checkout issue/48

	helm dependency build $tmpdir/charts/apps/pod-gateway
	helm upgrade --install -n gateway-system --create-namespace pod-gateway-foo $tmpdir/charts/apps/pod-gateway -f $deploydir/pod-gateway-foo-values.yaml
	helm upgrade --install -n gateway-system --create-namespace pod-gateway-bar $tmpdir/charts/apps/pod-gateway -f $deploydir/pod-gateway-bar-values.yaml
}

main $@

