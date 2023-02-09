# Event-driven in-tunnel crawler jobs

The stack is based on [Knative](https://knative.dev/docs/), [CloudEvents](https://cloudevents.io/), [pod-gateway](https://docs.k8s-at-home.com/guides/pod-gateway/) and the pod-gateway [client provisioner](https://github.com/maxgio92/cloudevents-podgateway-client-provisioner).

```ascii
                            ┌───────────────────┐
                            │                   │
                            │  gtw mutating     │
                            │  admission        │
                            └─────┬─┬─┬────┬─┬─┬┘
                                  │ │ │    │ │ │
                                ┌─▼─┴─┴──┐ │ │ │   ┌────────────┐
                                │client  │ │ │ │   │            │
                           ┌───►│        │ ▼ │ │   │ gateway    │
┌──────┐                   │    │gtw=foo ├───┴─┴───┤ foo        │
│      │                   │    │        │ tunnel  │            ├────►
│events│  ┌────────────┐   │    └───┬─┬──┘   │ │   │            │
│      │  │            │   │        │ │      │ │   │            │
│      │  │ provisioner├───┘    ┌───▼─┴──┐   │ │   └────────────┘
│      ├─►│            │        │client  │   │ │
│      │  │            ├───────►│        │   ▼ │   ┌────────────┐
│      │  │            │        │gtw=bar ├─────┴───┤            │
│      │  │            ├───┐    │        │ tunnel  │ gateway    │
│      │  │            │   │    └─────┬──┘     │   │ bar        ├────►
│      │  └────────────┘   │          │        │   │            │
│      │                   │    ┌─────▼──┐     ▼   │            │
└──────┘                   │    │client  ├─────────┤            │
                           └───►│        │ tunnel  └────────────┘
                                │gtw=bar │
                                │        │
                                └────────┘
```

> This is a proof of concept, please do not use in production.

## Table of contents

- [Quickstart](#quickstart)
- [Guides](./docs/guides.md)
- [Architecture](/docs/architecture.md)
- [Customization](/docs/customize.md)
- [Deep dive](./docs/dive.md)


## Quickstart

Requirements:
- [Docker](https://docs.docker.com/get-docker/)
- [KinD](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [Knative CLI](https://knative.dev/docs/client/install-kn/)

### Deploy the stack locally on [KinD](https://kind.sigs.k8s.io)

```shell
make deploy
```

### Produce Events

Now navigate with the browser on http://cloudevents-player.default.127.0.0.1.sslip.io, and send events with:
- ID: generate it
- Type: `io.podgateway.client.pending`
- Source: as you prefer
- SpecVersion: 1.0
- Message:
  ```json
  {
   "gateway_name": "foo"
  }
  ```

A `io.podgateway.client.scheduling.done` Event will be generated, with a Message containing:
- the `pod_name`
- the `namespace`

of the Crawler pod.

### Inspect the trafic

The Crawler pod's egress traffic can be inspected in the selected Pod Gateway:

```shell
kubectl exec -n gateway-system -it pod-gateway-foo -- sh
$ apk add tcpdump
$ tcpdump -i eth0 -nv
tcpdump: listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes

```

and sending ICMP traffic to Internet, from the Crawler pod:

```shell
kubectl exec -n <namespace> -it <pod_name> -- sh
$ ping -c1 8.8.8.8
```

it can be verified with `tcpdump` run above, that it comes from the *eth0* Pod Gateway interface:

```shell
[...]
$ tcpdump -i eth0 -nv
tcpdump: listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
14:24:21.791574 IP (tos 0x0, ttl 63, id 45165, offset 0, flags [none], proto UDP (17), length 134)
    10.244.0.31.43342 > 10.244.0.26.8472: OTV, flags [I] (0x08), overlay 0, instance 42
IP (tos 0x0, ttl 64, id 64442, offset 0, flags [DF], proto ICMP (1), length 84)
    172.16.0.184 > 8.8.8.8: ICMP echo request, id 68, seq 0, length 64
14:24:21.791618 IP (tos 0x0, ttl 63, id 64442, offset 0, flags [DF], proto ICMP (1), length 84)
    10.244.0.26 > 8.8.8.8: ICMP echo request, id 68, seq 0, length 64
14:24:21.804365 IP (tos 0x0, ttl 113, id 0, offset 0, flags [none], proto ICMP (1), length 84)
    8.8.8.8 > 10.244.0.26: ICMP echo reply, id 68, seq 0, length 64
14:24:21.804393 IP (tos 0x0, ttl 64, id 37367, offset 0, flags [none], proto UDP (17), length 134)
    10.244.0.26.43342 > 10.244.0.31.8472: OTV, flags [I] (0x08), overlay 0, instance 42
IP (tos 0x0, ttl 112, id 0, offset 0, flags [none], proto ICMP (1), length 84)
    8.8.8.8 > 172.16.0.184: ICMP echo reply, id 68, seq 0, length 64
```

