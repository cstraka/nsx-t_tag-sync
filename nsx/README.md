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
VEBA_GATEWAY=https://phxlvveba01.itplab.local
export OPENFAAS_URL=${VEBA_GATEWAY} # this is handy so you don't have to keep specifying OpenFaaS endpoint in command-line

faas-cli remove -f stack.yml --tls-no-verify
faas-cli secret remove vro-secrets --tls-no-verify
```
faas-cli secret list --tls-no-verify

## Instruction Building Function

Follow Step 1 from above and then any changes made to your function, you will need to run these additional two steps before proceeding to Step 2 from above.

Step 1 - Build the function container

```
faas-cli build -f stack.yml
faas-cli deploy --tls-no-verify -f stack.yml
```

Step 2 - Push the function container to Docker Registry (default but can be changed to internal registry)

```
faas-cli push -f stack.yml
faas-cli push --tls-no-verify -f stack.yml
```

The Hard Way
faas-cli build -f stack.yml
faas-cli push -f stack.yml
faas-cli deploy -f stack.yml --tls-no-verify

The Easy Way
faas-cli up --tls-no-verify


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

root@phxlvveba01 [ ~ ]# kubectl get pods -A
NAMESPACE        NAME                                               READY   STATUS      RESTARTS   AGE
kube-system      antrea-agent-dfr64                                 2/2     Running     2          21d
kube-system      antrea-controller-647fc85df-pq5vj                  1/1     Running     2          21d
kube-system      coredns-66bff467f8-d59ps                           1/1     Running     1          21d
kube-system      coredns-66bff467f8-plvph                           1/1     Running     1          21d
kube-system      etcd-phxlvveba01.itplab.local                      1/1     Running     1          21d
kube-system      kube-apiserver-phxlvveba01.itplab.local            1/1     Running     1          21d
kube-system      kube-controller-manager-phxlvveba01.itplab.local   1/1     Running     3          21d
kube-system      kube-proxy-nv55l                                   1/1     Running     1          21d
kube-system      kube-scheduler-phxlvveba01.itplab.local            1/1     Running     3          21d
openfaas-fn      nsxttagsync-6b4dbfd676-w6tcd                       1/1     Running     1          2d10h
openfaas         alertmanager-655465946c-4f576                      1/1     Running     1          21d
openfaas         basic-auth-plugin-7d4956689b-fcswm                 1/1     Running     1          21d
openfaas         faas-idler-b85f98fb7-d66pv                         1/1     Running     4          21d
openfaas         gateway-854d5bf48-m7dss                            2/2     Running     3          21d
openfaas         nats-5cd4dff7c8-knzxk                              1/1     Running     1          21d
openfaas         prometheus-859f6bfbc4-xkzbr                        1/1     Running     1          21d
openfaas         queue-worker-6cb888d49c-f8k5g                      1/1     Running     2          21d
projectcontour   contour-98d599f9f-x8mfb                            1/1     Running     3          21d
projectcontour   contour-98d599f9f-xpccw                            1/1     Running     1          21d
projectcontour   contour-certgen-v1.9.0-dpbl2                       0/1     Completed   0          21d
projectcontour   envoy-hjh6r                                        2/2     Running     2          21d
vmware           tinywww-65dd5c4d6f-ztspj                           1/1     Running     1          21d
vmware           vmware-event-router-6976868859-4ml2v               1/1     Running     5          21d

See Execution Logs
root@phxlvveba01 [ ~ ]#  kubectl logs -n openfaas-fn      nsxttagsync-6b4dbfd676-w6tcd
2021/01/13 06:09:45 Version: 0.9.14     SHA: a65df4795bc66147c41161c48bfd4c72f60c7434
2021/01/13 06:09:45 Read/write timeout: 5s, 5s. Port: 8080
2021/01/13 06:09:45 Writing lock-file to: /tmp/.lock
2021/01/13 06:13:46 Forking fprocess.
2021/01/13 06:13:51 Wrote 4235 Bytes - Duration: 4.387700 seconds
2021/01/13 06:15:43 Forking fprocess.
2021/01/13 06:15:47 Wrote 4235 Bytes - Duration: 4.145429 seconds

Connect to Shell
kubectl exec --stdin --tty -n openfaas-fn nsxttagsync-6b4dbfd676-w6tcd -- /bin/bash






Docker Reference
Build custom image:
https://www.linuxtechi.com/build-docker-container-images-with-dockerfile/

Pull a new image from repo
docker pull centos

See images (these are the base local images available to run a new running docker container)
[cstraka@phxlvdocker01 usr]$ docker images
REPOSITORY               TAG       IMAGE ID       CREATED         SIZE
cmstraka/nsxt-tag-sync   latest    c3a0cb00c5c6   3 weeks ago     211MB
cmstraka/centos          latest    eb131a473f67   3 weeks ago     211MB
<none>                   <none>    aa80b7f6171c   3 weeks ago     211MB
centos                   latest    300e315adb2f   5 weeks ago     209MB
ubuntu                   latest    f643c72bc252   7 weeks ago     72.9MB
hello-world              latest    bf756fb1ae65   12 months ago   13.3kB
vmware/photon2           latest    6337aa168349   2 years ago     32.1MB

kill existing container
docker rm competent_elbakyan

Run a new image from REPO
docker run --name veba-testfunction -it centos:latest bash

See  running containers
[cstraka@phxlvdocker01 ~]$ docker ps -a
CONTAINER ID   IMAGE           COMMAND   CREATED         STATUS         PORTS     NAMES
d5ff4b82e4a0   centos:latest   "bash"    4 minutes ago   Up 4 minutes             veba-testfunction

Commit running container to a new image (effectively cloned centos:latest to cmstraka/veba-base:latest)  use ':%tag% if something other than ':latest' is desired.
[cstraka@phxlvdocker01 ~]$ docker commit -m "Cloned CentOS image " -a "Craig Straka" d5ff4b82e4a0 cmstraka/veba-base
sha256:f85575f236987b6d5e54f976778f6c88f97d0c7f5ee3aee7758dd7b5d5b81d89

docker push cmstraka/veba-base:latest

look on github.io, cmstraka/veba-base:latest is available for pull and use!
[root@phxlvdocker01 Test]# docker run --name veba-testfunction -it cmstraka/veba-base:latest bash
[root@321256888f3b /]# [root@phxlvdocker01 Test]# docker ps -a
CONTAINER ID   IMAGE                           COMMAND   CREATED          STATUS         PORTS      NAMES
321256888f3b   cmstraka/veba-base:latest       "bash"    10 seconds ago   Up 9 seconds              veba-testfunction
b1a6870d478e   cmstraka/nsxt-tag-sync:latest   "bash"    2 hours ago      Up 2 hours     8080/tcp   veba-test


Copy a script into a running container (do this after a new script has been uploaded to a new image
docker cp script.ps1 4832bf5d5048:/root/function/script.ps1


Packages for Working VRO script
root [ ~ ]# tdnf list
Refreshing metadata for: 'VMware Photon Linux 3.0 (x86_64)'
Error: 404 when downloading https://dl.bintray.com/vmware/photon_release_3.0_x86_64/repodata/repomd.xml
. Please check repo url.
Error: Failed to synchronize cache for repo 'VMware Photon Linux 3.0 (x86_64)' from 'https://dl.bintray.com/vmware/photon_release_3.0_x86_64'
Disabling Repo: 'VMware Photon Linux 3.0 (x86_64)'
Refreshing metadata for: 'VMware Photon Extras 3.0 (x86_64)'
Error: 404 when downloading https://dl.bintray.com/vmware/photon_extras_3.0_x86_64/repodata/repomd.xml
. Please check repo url.
Error: Failed to synchronize cache for repo 'VMware Photon Extras 3.0 (x86_64)' from 'https://dl.bintray.com/vmware/photon_extras_3.0_x86_64'
Disabling Repo: 'VMware Photon Extras 3.0 (x86_64)'
Refreshing metadata for: 'VMware Photon Linux 3.0 (x86_64) Updates'
Error: 404 when downloading https://dl.bintray.com/vmware/photon_updates_3.0_x86_64/repodata/repomd.xml
. Please check repo url.
Error: Failed to synchronize cache for repo 'VMware Photon Linux 3.0 (x86_64) Updates' from 'https://dl.bintray.com/vmware/photon_updates_3.0_x86_64'
Disabling Repo: 'VMware Photon Linux 3.0 (x86_64) Updates'
Linux-PAM.x86_64                                                                                                1.3.0-1.ph3                                                               @System
bash.x86_64                                                                                                     4.4.18-2.ph3                                                              @System
bzip2-libs.x86_64                                                                                               1.0.8-1.ph3                                                               @System
ca-certificates.x86_64                                                                                          20190521-1.ph3                                                            @System
ca-certificates-pki.x86_64                                                                                      20190521-1.ph3                                                            @System
cracklib.x86_64                                                                                                 2.9.6-8.ph3                                                               @System
curl.x86_64                                                                                                     7.61.1-6.ph3                                                              @System
curl-libs.x86_64                                                                                                7.61.1-6.ph3                                                              @System
e2fsprogs-libs.x86_64                                                                                           1.45.5-1.ph3                                                              @System
elfutils-libelf.x86_64                                                                                          0.176-1.ph3                                                               @System
expat.x86_64                                                                                                    2.2.9-1.ph3                                                               @System
expat-libs.x86_64                                                                                               2.2.9-1.ph3                                                               @System
filesystem.x86_64                                                                                               1.1-4.ph3                                                                 @System
glibc.x86_64                                                                                                    2.28-4.ph3                                                                @System
icu.x86_64                                                                                                      61.1-1.ph3                                                                @System
krb5.x86_64                                                                                                     1.17-1.ph3                                                                @System
libcap.x86_64                                                                                                   2.25-8.ph3                                                                @System
libdb.x86_64                                                                                                    5.3.28-2.ph3                                                              @System
libgcc.x86_64                                                                                                   7.3.0-4.ph3                                                               @System
libmetalink.x86_64                                                                                              0.1.3-1.ph3                                                               @System
libsolv.x86_64                                                                                                  0.6.35-2.ph3                                                              @System
libssh2.x86_64                                                                                                  1.9.0-2.ph3                                                               @System
libstdc++.x86_64                                                                                                7.3.0-4.ph3                                                               @System
lttng-ust.x86_64                                                                                                2.10.2-2.ph3                                                              @System
lua.x86_64                                                                                                      5.3.5-2.ph3                                                               @System
ncurses-libs.x86_64                                                                                             6.1-2.ph3                                                                 @System
nspr.x86_64                                                                                                     4.21-1.ph3                                                                @System
nss-libs.x86_64                                                                                                 3.44-3.ph3                                                                @System
openssl.x86_64                                                                                                  1.0.2u-2.ph3                                                              @System
photon-release.noarch                                                                                           3.0-5.ph3                                                                 @System
photon-repos.noarch                                                                                             3.0-4.ph3                                                                 @System
pkg-config.x86_64                                                                                               0.29.2-2.ph3                                                              @System
popt.x86_64                                                                                                     1.16-5.ph3                                                                @System
powershell.x86_64                                                                                               6.2.3-1.ph3                                                               @System
readline.x86_64                                                                                                 7.0-2.ph3                                                                 @System
rpm-libs.x86_64                                                                                                 4.14.2-6.ph3                                                              @System
sqlite-libs.x86_64                                                                                              3.31.1-1.ph3                                                              @System
tdnf.x86_64                                                                                                     2.0.0-11.ph3                                                              @System
tdnf-cli-libs.x86_64                                                                                            2.0.0-11.ph3                                                              @System
toybox.x86_64                                                                                                   0.8.2-1.ph3                                                               @System
userspace-rcu.x86_64                                                                                            0.10.1-1.ph3                                                              @System
xz-libs.x86_64                                                                                                  5.2.4-1.ph3                                                               @System
zlib.x86_64                                                                                                     1.2.11-1.ph3                                                              @System
zlib-devel.x86_64                                                                                               1.2.11-1.ph3                                                              @System

Using docker pull it down to your local machine.
	docker pull vmware/powerclicore:latest

Once it has been pulled down use docker images to see the image information.
	docker images
docker images
REPOSITORY                           TAG                 IMAGE ID            CREATED             SIZE
cmstraka/nsxt-tag-sync               latest              1e9b5e4a2047        27 minutes ago      227MB
cmstraka/powerclicore                latest              ed9e07c2bfe4        2 hours ago         227MB
photon                               3.0                 dfd3fd2bc370        11 days ago         36.3MB
photon                               latest              dfd3fd2bc370        11 days ago         36.3MB
vmware/veba-event-router             v0.5.0              14a503051fdc        5 weeks ago         202MB
embano1/tinywww                      latest              b73df0803467        3 months ago        74.4MB
projectcontour/contour               v1.9.0              e5264899280b        3 months ago        38.3MB
envoyproxy/envoy                     v1.15.1             a8b75a4b4116        3 months ago        110MB
k8s.gcr.io/kube-proxy                v1.18.3             3439b7546f29        8 months ago        117MB
k8s.gcr.io/kube-scheduler            v1.18.3             76216c34ed0c        8 months ago        95.3MB
k8s.gcr.io/kube-apiserver            v1.18.3             7e28efa976bd        8 months ago        173MB
k8s.gcr.io/kube-controller-manager   v1.18.3             da26705ccb4b        8 months ago        162MB
vmware/powerclicore                  latest              a0fceeaed43e        8 months ago        372MB
cmstraka/nsxt-tag-sync               <none>              a0fceeaed43e        8 months ago        372MB
openfaas/queue-worker                0.11.0              156f3ea15fa6        8 months ago        9.76MB
antrea/antrea-ubuntu                 v0.6.0              36cc5d6d96b8        8 months ago        319MB
openfaas/faas-netes                  0.10.3              9f1afd1e679c        9 months ago        71.6MB
openfaas/basic-auth-plugin           0.18.17             4d5c7c56e1f4        9 months ago        16.6MB
openfaas/gateway                     0.18.17             9496eadeb6e5        9 months ago        30MB
openfaas/faas-idler                  0.3.0               93f8e669f6cf        10 months ago       26.4MB
functions/hubstats                   latest              01affa91e9e4        11 months ago       29.3MB
k8s.gcr.io/pause                     3.2                 80d28bedfe5d        11 months ago       683kB
nats-streaming                       0.17.0              411737a82b95        11 months ago       16MB
k8s.gcr.io/coredns                   1.6.7               67da37a9a360        11 months ago       43.8MB
k8s.gcr.io/etcd                      3.4.3-0             303ce5db0e90        15 months ago       288MB
prom/prometheus                      v2.11.0             b97ed892eb23        18 months ago       126MB
prom/alertmanager                    v0.18.0             ce3c87f17369        18 months ago       51.9MB
	

We will now need to tag and push the image to our own repository to use as a base image. For the tag identifier use the Image ID from docker images.
	docker tag a0fceeaed43e dstamen/test
	docker push dstamen/test
	
	
	
	








