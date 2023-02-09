# Step by step local deployment

## Deploy KNative in KinD

We're going to deploy KNative in KinD:

```
kn quickstart kind
```

> This setup is not [production grade](https://knative.dev/docs/getting-started/quickstart-install/#before-you-begin).

And required [cert-manager](https://cert-manager.io/):

```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.1/cert-manager.yaml
```

and wait for it:

```
kubectl wait deployment -n cert-manager cert-manager-webhook --for condition=Available=True --timeout=90s
```

## Deploy the provsioner and its Trigger

Here we're going to deploy the crawler pods provisioner Service with the related Trigger:

```
kubectl apply -k ./deploy
```

## Deploy Pod gateways

> NOTE: https://github.com/angelnu/helm-charts/pull/49 needs to be merged before using the official `angelnu/pod-gateway` Helm chart. In the meantime the forked [pod-gateway](https://github.com/maxgio92/helm-charts/tree/issue/48/charts/apps/pod-gateway) chart supports it.

Here we're going to deploy two pod gateways, named `foo` and `bar`:

```
tmpdir=$(mktemp -d)
git clone git@github.com:maxgio92/helm-charts.git $tmpdir
git -C $tmpdir checkout issue/48
helm dependency build $tmpdir/charts/apps/pod-gateway
helm upgrade --install -n gateway-system --create-namespace pod-gateway-foo $tmpdir/charts/apps/pod-gateway -f $deploydir/pod-gateway-foo-values.yaml
helm upgrade --install -n gateway-system --create-namespace pod-gateway-bar $tmpdir/charts/apps/pod-gateway -f $deploydir/pod-gateway-bar-values.yaml
```

## Play

Now that the setup is ready, please follow the [quickstart](../README.md#produce-events), to start producing events.

