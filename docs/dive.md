## Deep dive

The `gateway` field's value can be choosen between the ones you set in the `pod-gateway` Helm value `setGatewayLabelValue`/`setGatewayAnnotationValue` (in this demo `foo` and `bar`).

The event will be sent by the CloudEvents Player dashboard, and be consumed by the Crawler Provisioner service.

In turn, the Crawler Provisioner service will schedule a Crawler as a Pod, and as soon as the operation is completed a new event will be created.

Based on the success or failure, the event will be of type:
1. `io.podgateway.client.scheduling.done`  or
1. `io.podgateway.client.scheduling.failed`

You can see this event coming in the CloudEvents Player dashboard.

### Scheduling events

#### Failure

The `io.podgateway.client.scheduling.failed` event will contain the related error message.

#### Success

The `io.podgateway.client.scheduling.done` event will contain Data of the Crawler Pod just created, such as:
- `pod_name`
- `namespace`

### Inspect the Crawler pod

Please consider that in this demonstration the Crawler pod is created with a single `alpine/curl` container, running `sleep infinity`, and with an **annotation** that claims the `foo` pod gateway as default gateway:

```shell
$ kubectl get pods -n <namespace> <pod_name> -o=jsonpath='{.metadata.annotations}'
{"setGateway":"foo"}
```

By inspecting the pod's containers, you can see that it has got injected an **init** and a **sidecar** containers:

```shell
$ kubectl get pods -n <namespace> <pod_name> -o=jsonpath='{.spec.containers[*].image}, {.spec.containers[*].commands}
alpine/curl ghcr.io/angelnu/pod-gateway:v1.8.1, ["sleep","infinity"] ["/bin/client_sidecar.sh"]
```

The pod has been mutated by the `pod-gateway` [admission controller](https://github.com/angelnu/gateway-admision-controller), as the `setGateway`'s value matched the one configured in the `pod-gateway-foo` Helm release values:

```shell
$ grep gatewayAnnotation deploy/pod-gateway-foo-values.yaml
gatewayAnnotation: setGateway
gatewayAnnotationValue: foo
```

And you can see that the `pod-gateway` init and sidecar container injected, reference the exact requested gateway:

```shell
$ kubectl get pods -n <namespace> <pod_name> -o=jsonpath='{.spec.containers[1].env[0]}';
  kubectl get pods -n <namespace> <pod_name> -o=jsonpath='{.spec.initContainers[0].env[0]}'
{"name":"gateway","value":"pod-gateway-foo.gateway-system.svc.cluster.local"}
{"name":"gateway","value":"pod-gateway-foo.gateway-system.svc.cluster.local"}
```

and they reference the pod gateway Kubernetes `Service`s, running in the cluster:

```shell
$ kubectl get service -n gateway-system pod-gateway-foo
NAME              TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
pod-gateway-foo   ClusterIP   None         <none>        4789/UDP   19h
```

### Inspect the traffic

The injected init container [sets up](https://github.com/angelnu/pod-gateway/blob/main/bin/client_init.sh) routes and devices for the VXLAN tunnel to the gateway:

At the end of the day, the egress traffic is routed through the `foo` gateway:

```shell
kubectl exec -n <namespace> -it <pod_name> -- sh
$ curl -sLI https://google.com
HTTP/2 200
...
```

And it can be inspected:

```shell
kubectl exec -n gateway-system -it pod-gateway-foo -- sh
$ apk add tcpdump
$ tcpdump -i eth0 -nv
13:27:28.464066 IP (tos 0x0, ttl 63, id 9650, offset 0, flags [none], proto UDP (17), length 102)
    10.244.0.31.50116 > 10.244.0.26.8472: OTV, flags [I] (0x08), overlay 0, instance 42
IP (tos 0x0, ttl 64, id 28100, offset 0, flags [DF], proto TCP (6), length 52)
    172.16.0.184.40714 > 142.250.184.78.80: Flags [.], cksum 0xf437 (incorrect -> 0x45f6), ack 529, win 503, options [nop,nop,TS val 3550340975 ecr 1309124579], length 0
13:27:28.464080 IP (tos 0x0, ttl 63, id 28100, offset 0, flags [DF], proto TCP (6), length 52)
    10.244.0.26.40714 > 142.250.184.78.80: Flags [.], cksum 0x527d (incorrect -> 0xe7b0), ack 529, win 503, options [nop,nop,TS val 3550340975 ecr 1309124579], length 0
13:27:28.464394 IP (tos 0x0, ttl 63, id 9651, offset 0, flags [none], proto UDP (17), length 102)
    10.244.0.31.50116 > 10.244.0.26.8472: OTV, flags [I] (0x08), overlay 0, instance 42
IP (tos 0x0, ttl 64, id 28101, offset 0, flags [DF], proto TCP (6), length 52)
    172.16.0.184.40714 > 142.250.184.78.80: Flags [F.], cksum 0xf437 (incorrect -> 0x45f5), seq 75, ack 529, win 503, options [nop,nop,TS val 3550340975 ecr 1309124579], length 0
13:27:28.464413 IP (tos 0x0, ttl 63, id 28101, offset 0, flags [DF], proto TCP (6), length 52)
    10.244.0.26.40714 > 142.250.184.78.80: Flags [F.], cksum 0x527d (incorrect -> 0xe7af), seq 75, ack 529, win 503, options [nop,nop,TS val 3550340975 ecr 1309124579], length 0
13:27:28.477304 IP (tos 0x0, ttl 118, id 19535, offset 0, flags [none], proto TCP (6), length 52)
    142.250.184.78.80 > 10.244.0.26.40714: Flags [F.], cksum 0xe898 (correct), seq 529, ack 76, win 256, options [nop,nop,TS val 1309124592 ecr 3550340975], length 0
13:27:28.477313 IP (tos 0x0, ttl 64, id 56934, offset 0, flags [none], proto UDP (17), length 102)
    10.244.0.26.56262 > 10.244.0.31.8472: OTV, flags [I] (0x08), overlay 0, instance 42
IP (tos 0x0, ttl 117, id 19535, offset 0, flags [none], proto TCP (6), length 52)
    142.250.184.78.80 > 172.16.0.184.40714: Flags [F.], cksum 0x46de (correct), seq 529, ack 76, win 256, options [nop,nop,TS val 1309124592 ecr 3550340975], length 0
13:27:28.477338 IP (tos 0x0, ttl 63, id 9652, offset 0, flags [none], proto UDP (17), length 102)
    10.244.0.31.50116 > 10.244.0.26.8472: OTV, flags [I] (0x08), overlay 0, instance 42
IP (tos 0x0, ttl 64, id 28102, offset 0, flags [DF], proto TCP (6), length 52)
    172.16.0.184.40714 > 142.250.184.78.80: Flags [.], cksum 0xf437 (incorrect -> 0x45da), ack 530, win 503, options [nop,nop,TS val 3550340988 ecr 1309124592], length 0
13:27:28.477342 IP (tos 0x0, ttl 63, id 28102, offset 0, flags [DF], proto TCP (6), length 52)
    10.244.0.26.40714 > 142.250.184.78.80: Flags [.], cksum 0x527d (incorrect -> 0xe794), ack 530, win 503, options [nop,nop,TS val 3550340988 ecr 1309124592], length 0
13:27:30.765115 IP (tos 0x0, ttl 64, id 57405, offset 0, flags [none], proto UDP (17), length 78)
    10.244.0.26.45891 > 10.244.0.31.8472: OTV, flags [I] (0x08), overlay 0, instance 42
ARP, Ethernet (len 6), IPv4 (len 4), Request who-has 172.16.0.184 tell 172.16.0.1, length 28
13:27:30.765228 IP (tos 0x0, ttl 63, id 10161, offset 0, flags [none], proto UDP (17), length 78)
    10.244.0.31.45891 > 10.244.0.26.8472: OTV, flags [I] (0x08), overlay 0, instance 42
ARP, Ethernet (len 6), IPv4 (len 4), Reply 172.16.0.184 is-at 06:9a:67:b0:8a:f9, length 28
13:27:35.587509 IP (tos 0x0, ttl 63, id 11575, offset 0, flags [none], proto UDP (17), length 134)
    10.244.0.31.55657 > 10.244.0.26.8472: OTV, flags [I] (0x08), overlay 0, instance 42
IP (tos 0x0, ttl 64, id 47534, offset 0, flags [DF], proto ICMP (1), length 84)
    172.16.0.184 > 172.16.0.1: ICMP echo request, id 83, seq 0, length 64
13:27:35.587562 IP (tos 0x0, ttl 64, id 57952, offset 0, flags [none], proto UDP (17), length 134)
    10.244.0.26.55657 > 10.244.0.31.8472: OTV, flags [I] (0x08), overlay 0, instance 42
IP (tos 0x0, ttl 64, id 8358, offset 0, flags [none], proto ICMP (1), length 84)
    172.16.0.1 > 172.16.0.184: ICMP echo reply, id 83, seq 0, length 64
```

### Multiple gateway support

Please read [this issue](https://github.com/angelnu/gateway-admision-controller/issues/102) to understand how the support is accomplished.

### Produce CloudEvents programmatically

By using a simple cURL client:

```shell
kubectl -n default run curl --image=radial/busyboxplus:curl -it
$ curl -v "http://broker-ingress.knative-eventing.svc.cluster.local/default/default" \
-X POST \
-H "Ce-Id: 536808d3-88be-4077-9d7a-a3f162705f79" \
-H "Ce-Specversion: 1.0" \
-H "Ce-Type: io.podgateway.client.pending" \
-H "Ce-Source: dev.knative.samples/helloworldsource" \
-H "Content-Type: application/json" \
-d '{"message":"Hello!","gateway_name":"foo"}'
```
