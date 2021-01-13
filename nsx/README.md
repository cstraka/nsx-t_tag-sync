# vRealize Orchestrator Function

## Description

This function demonstrates using PowerShell to trigger vRealize Orchestrator workflow using vRO REST API

## Prerequisites

* You have deployed the example vSphere Tagging vRO Workflow package from https://github.com/kclinden/vro-vsphere-tagging
* You have retrieved the required vRO Workflow ID (please see this blog post [here](https://www.virtuallyghetto.com/2020/03/using-vro-rest-api-to-execute-a-workflow-with-sdk-objects.html) for more details)

## Instruction Consuming Function

Step 1 - Initialize function, only required during the first deployment

```
faas-cli template pull
```

Step 2 - Update `stack.yml` and `vro-secrets.json` with your environment information

> **Note:** If you are building your own function, you will need to update the `image:` property in the stack.yaml to point to your own Dockerhub account and Docker Image (e.g. `<dockerhubid>/<dockerimagename>`)

Step 3 - Deploy function to VMware Event Broker Appliance

```
VEBA_GATEWAY=https://phxlvveba01.itplab.local
export OPENFAAS_URL=${VEBA_GATEWAY} # this is handy so you don't have to keep specifying OpenFaaS endpoint in command-line

faas-cli login --username admin --password-stdin --tls-no-verify # login with your admin password
faas-cli secret create vro-secrets --from-file=vro-secrets.json --tls-no-verify # create secret, only required once
faas-cli deploy -f stack.yml --tls-no-verify
```

Step 4 - To remove the function and secret from VMware Event Broker Appliance

```
VEBA_GATEWAY=https://veba.primp-industries.com
export OPENFAAS_URL=${VEBA_GATEWAY} # this is handy so you don't have to keep specifying OpenFaaS endpoint in command-line

faas-cli remove -f stack.yml --tls-no-verify
faas-cli secret remove vro-secrets --tls-no-verify
```

## Instruction Building Function

Follow Step 1 from above and then any changes made to your function, you will need to run these additional two steps before proceeding to Step 2 from above.

Step 1 - Build the function container

```
faas-cli build -f stack.yml
```

Step 2 - Push the function container to Docker Registry (default but can be changed to internal registry)

```
faas-cli push -f stack.yml
```



In ITP Lab
[root@phxlvdocker01~]cd NSX-T_Tag-Sync/
[root@phxlvdocker01 NSX-T_Tag-Sync]# git pull https://github.com/cstraka/NSX-T_Tag-Sync.git
[root@phxlvdocker01 NSX-T_Tag-Sync]# cd nsx
[root@phxlvdocker01 nsx]# export OPENFAAS_URL=https://phxlvveba01.itplab.local
[root@phxlvdocker01 nsx]# cat ~/faas_pass.txt | faas-cli login -u admin --password-stdin --tls-no-verify
Calling the OpenFaaS server to validate the credentials...
credentials saved for admin https://phxlvveba01.itplab.local
[root@phxlvdocker01 nsx]# faas-cli secret create nsx-secrets --from-file=nsx-secrets.json --tls-no-verify
Creating secret: nsx-secrets
Created: 202 Accepted
[root@phxlvdocker01 nsx]# faas-cli deploy --tls-no-verify -f stack.yml
Deploying: nsxttagsync.

Deployed. 202 Accepted.
URL: https://phxlvveba01.itplab.local/function/nsxttagsync.openfaas-fn

[root@phxlvdocker01 nsx]#

Monitor the Activities
root@phxlvveba01 [ ~ ]# kubectl get pods -A
NAMESPACE        NAME                                               READY   STATUS             RESTARTS   AGE
kube-system      antrea-agent-dfr64                                 2/2     Running            2          18d
kube-system      antrea-controller-647fc85df-pq5vj                  1/1     Running            2          18d
kube-system      coredns-66bff467f8-d59ps                           1/1     Running            1          18d
kube-system      coredns-66bff467f8-plvph                           1/1     Running            1          18d
kube-system      etcd-phxlvveba01.itplab.local                      1/1     Running            1          18d
kube-system      kube-apiserver-phxlvveba01.itplab.local            1/1     Running            1          18d
kube-system      kube-controller-manager-phxlvveba01.itplab.local   1/1     Running            3          18d
kube-system      kube-proxy-nv55l                                   1/1     Running            1          18d
kube-system      kube-scheduler-phxlvveba01.itplab.local            1/1     Running            3          18d
openfaas-fn      nodeinfo-555965ddfb-qt8cr                          1/1     Running            0          18d
openfaas-fn      nsxttagsync-78f6c8ffb9-qt4qz                       0/1     ImagePullBackOff   0          8m23s
openfaas         alertmanager-655465946c-4f576                      1/1     Running            1          18d
openfaas         basic-auth-plugin-7d4956689b-fcswm                 1/1     Running            1          18d
openfaas         faas-idler-b85f98fb7-d66pv                         1/1     Running            4          18d
openfaas         gateway-854d5bf48-m7dss                            2/2     Running            3          18d
openfaas         nats-5cd4dff7c8-knzxk                              1/1     Running            1          18d
openfaas         prometheus-859f6bfbc4-xkzbr                        1/1     Running            1          18d
openfaas         queue-worker-6cb888d49c-f8k5g                      1/1     Running            2          18d
projectcontour   contour-98d599f9f-x8mfb                            1/1     Running            3          18d
projectcontour   contour-98d599f9f-xpccw                            1/1     Running            1          18d
projectcontour   contour-certgen-v1.9.0-dpbl2                       0/1     Completed          0          18d
projectcontour   envoy-hjh6r                                        2/2     Running            2          18d
vmware           tinywww-65dd5c4d6f-ztspj                           1/1     Running            1          18d
vmware           vmware-event-router-6976868859-4ml2v               1/1     Running            5          18d

kubectl logs vmware-event-router-6976868859-4ml2v -n vmware | grep com.vmware.cis

Examine Logs

2021-01-11T19:38:17.665Z        INFO    [OPENFAAS]      openfaas/openfaas.go:197        finished processing of event    {"eventID": "49f8bd2a-d9fa-4944-a435-9d5567ecde64", "topic": "com.vmware.cis.tagging.detach"}
2021-01-11T21:24:50.256Z        INFO    [OPENFAAS]      openfaas/openfaas.go:195        invoking function(s) for event  {"eventID": "742cc650-79e1-4d17-883d-7a070103e2fb", "topic": "com.vmware.cis.tagging.attach"}
2021-01-11T21:24:50.256Z        INFO    [OPENFAAS]      openfaas/openfaas.go:205        function(s) matched for event   {"count": 1, "eventID": "742cc650-79e1-4d17-883d-7a070103e2fb", "topic": "com.vmware.cis.tagging.attach"}
2021-01-11T21:25:53.259Z        ERROR   [OPENFAAS]      openfaas/openfaas.go:249        could not invoke function       {"function": "nsxttagsync.openfaas-fn", "topic": "com.vmware.cis.tagging.attach", "retries": 3, "error": "All attempts fail:\n#1: function \"nsxttagsync.openfaas-fn\" on topic \"com.vmware.cis.tagging.attach\" returned non successful status code 500: \"\"\n#2: function \"nsxttagsync.openfaas-fn\" on topic \"com.vmware.cis.tagging.attach\" returned non successful status code 500: \"\"\n#3: function \"nsxttagsync.openfaas-fn\" on topic \"com.vmware.cis.tagging.attach\" returned non successful status code 500: \"\""}
2021-01-11T21:25:53.259Z        INFO    [OPENFAAS]      openfaas/openfaas.go:197        finished processing of event    {"eventID": "742cc650-79e1-4d17-883d-7a070103e2fb", "topic": "com.vmware.cis.tagging.attach"}

kubectl get pods -A
NAMESPACE        NAME                                               READY   STATUS             RESTARTS   AGE
kube-system      antrea-agent-dfr64                                 2/2     Running            2          18d
kube-system      antrea-controller-647fc85df-pq5vj                  1/1     Running            2          18d
kube-system      coredns-66bff467f8-d59ps                           1/1     Running            1          18d
kube-system      coredns-66bff467f8-plvph                           1/1     Running            1          18d
kube-system      etcd-phxlvveba01.itplab.local                      1/1     Running            1          18d
kube-system      kube-apiserver-phxlvveba01.itplab.local            1/1     Running            1          18d
kube-system      kube-controller-manager-phxlvveba01.itplab.local   1/1     Running            3          18d
kube-system      kube-proxy-nv55l                                   1/1     Running            1          18d
kube-system      kube-scheduler-phxlvveba01.itplab.local            1/1     Running            3          18d
openfaas-fn      nodeinfo-555965ddfb-qt8cr                          1/1     Running            0          18d
openfaas-fn      nsxttagsync-8475b555db-8pvzj                       0/1     ImagePullBackOff   0          51s
openfaas         alertmanager-655465946c-4f576                      1/1     Running            1          18d
openfaas         basic-auth-plugin-7d4956689b-fcswm                 1/1     Running            1          18d
openfaas         faas-idler-b85f98fb7-d66pv                         1/1     Running            4          18d
openfaas         gateway-854d5bf48-m7dss                            2/2     Running            3          18d
openfaas         nats-5cd4dff7c8-knzxk                              1/1     Running            1          18d
openfaas         prometheus-859f6bfbc4-xkzbr                        1/1     Running            1          18d
openfaas         queue-worker-6cb888d49c-f8k5g                      1/1     Running            2          18d
projectcontour   contour-98d599f9f-x8mfb                            1/1     Running            3          18d
projectcontour   contour-98d599f9f-xpccw                            1/1     Running            1          18d
projectcontour   contour-certgen-v1.9.0-dpbl2                       0/1     Completed          0          18d
projectcontour   envoy-hjh6r                                        2/2     Running            2          18d
vmware           tinywww-65dd5c4d6f-ztspj                           1/1     Running            1          18d
vmware           vmware-event-router-6976868859-4ml2v               1/1     Running            5          18d

kubectl logs -n openfaas-fn nsxttagsync-78f6c8ffb9-qt4qz
Error from server (BadRequest): container "nsxttagsync" in pod "nsxttagsync-8475b555db-8pvzj" is waiting to start: trying and failing to pull image






