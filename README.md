# Desplegar Kubernetes en GCloud usando  Cloud Shell
 Nueva sesion de Cloud Shell 
*https://console.cloud.google.com/

1.- Seleccionar el proyecto donde se realizará el despliegue.
```gcloud config set project [PROJECT_ID]```

2.- Desplegamos el cluster para con nodepool default con 1 nodo.
```gcloud container clusters create sandbox \```
``` --num-nodes 1 --zone us-central1-b```

3.- Desplegamos el noode pool para ingress-nginx con 3 nodos.
```gcloud container node-pools create ingress-nginx \```
```--cluster=sandbox --enable-autorepair```

# Instalar Helm y Tiller con RBA 

Para simplificar la instalación y administración de aplicaciones y recursos de Kubernetes.

1.- Utilizamos el siguiente comando que obtiene la última versión:
```curl -o get_helm.sh https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get```
```chmod +x get_helm.sh```
```./get_helm.sh```

2.- Instalación de Tiller con RBAC habilitado
```kubectl create serviceaccount --namespace kube-system tiller```
```kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller```
```helm init --service-account tiller```

3.- Iniciamos helt
```helm init```

4.- Dar permisos para RBAC 
```kubectl create clusterrolebinding permissive-binding \```
```--clusterrole=cluster-admin \```
``` --user=admin \```
``` --user=kubelet \```
``` --group=system:serviceaccounts```

