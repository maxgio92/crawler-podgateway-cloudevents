# Architecture

## Components

- KNative Eventing and Serving operators
- Pod Gateway
- Crawler pod provisioner

### Resources

- KNative Broker
- KNative Trigger for the Crawler Provisioner Service
- Crawler Provisioner Service
- Pod Gateways

A `io.podgateway.client.pending` CloudEvent sent to the Knative Broker, triggers the Crawler Provisioner Service, which consumes the event.

The consumed event, if valid, makes the Provisioner service to create a Crawler pod, and finally notify the success or failure of that operation, with an event (`io.podgateway.client.scheduling.done` or `io.podgateway.client.scheduling.failed`).

The Crawler pod is created claiming the Pod Gateway specified in the `io.podgateway.client.pending` event Message (`gateway` field).

The claim is translated by the provisioner into an Kubernetes annotation, which needs to be matched by the installed Pod Gateways' Admission controllers.

In detail, the Message's `gateway_name` field value in the `io.podgateway.client.pending` event, must match a `gatewayLabelValue` or `gatewayAnnotationValue` Helm value of an installed Pod Gateway Helm release.

#### Example

With a Pod Gateway installed with:

```shell
helm install angelnu/pod-gateway pod-gateway-foo -n gateway-system --set "gatewayAnnotation=setGateway" --set "gatewayAnnotationValue=foo"
```

a `io.podgateway.client.pending` Event message need to match the gateway annotation:

```
{
 "gateway_name": "foo"
}
```

> NOTE: https://github.com/angelnu/helm-charts/pull/49 needs to be merged before using the official `angelnu/pod-gateway` Helm chart. In the meantime the forked [pod-gateway](https://github.com/maxgio92/helm-charts/tree/issue/48/charts/apps/pod-gateway) chart supports it.

