# Customizations

## Crawler container image and command

For demo purposes, the container image set is `alpine/curl` and the command `sleep infinity`.

You can check this in [pkg/provision/constants.go](../pkg/provision/constants.go).

## Pod-gateway matching label/annotation

The label/annotation key expected to be matched by the pod-gateway, which is a fundamental component of this setup, are set in [pkg/provision/constants.go](../pkg/provision/constants.go).

They need to match what is set in the [pod-gateway]() Helm chart value:
- `gatewayLabel`
- `gatewayAnnotation`

> The provisioner sets both, but you don't need to set both in the pod-gateway Helm release.

In this demo setup the annotation only has been set.

