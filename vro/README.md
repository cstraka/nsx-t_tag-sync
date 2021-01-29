# vRealize Orchestrator Function 
(Mad props to https://www.virtuallyghetto.com/2020/03/integrating-vcenter-event-broker-appliance-veba-with-vrealize-orchestrator.html for 99.9% of this and VEBA!)

## Description

This function demonstrates using PowerShell to trigger a vRealize Orchestrator workflow using vRO REST API

## Prerequisites
- vRealize Orchestrator deplyoment
	- vSphere VASA
	- NSX-T REST Host
- You have deployed the 'com.it-partners.com.nsxTagSyn.package' Workflow package from https://github.com/IT-Partners/nsx-t_tag-sync/tree/main/vro
- VMware Event Broker Appliance (VEBA) fling (https://flings.vmware.com/vmware-event-broker-appliance) Installtion

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
