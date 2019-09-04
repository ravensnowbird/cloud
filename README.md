

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

# Configurando y custumizando 

1.- Creamos el namespece dentro del Clusrter incluido en *namespace.yaml*
```apiVersion: v1```
```kind: Namespace```
```metadata:```

2. Configuramos el servicio y el el deploy default incluido en *default-backend.yaml*
```
apiVersion: v1
kind: Service
metadata:
  name: default-http-backend
  namespace: ingress-nginx
  labels:
    app: default-http-backend
spec:
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: default-http-backend```name: ingress-nginx```
```
3. Creamos el config map incluido en *configmap.yaml*
```
kind: ConfigMap
apiVersion: v1
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
  labels:
    app: ingress-nginx
data:
  body-size: "64m"
  client-max-body-size: "50m"
```
4. Agregamos los servcios UDP y TCP incluidos en *5_udp-services-configmap.yaml y 4_tcp-services-configmap.yaml*
```kind: ConfigMap
apiVersion: v1
metadata:
  name: tcp-services
  namespace: ingress-nginx
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: udp-services
  namespace: ingress-nginx
```
5. Por ultimo instalamos el kubernetes-ingress-controller / nginx-ingress-controller incluido el *6_install.yaml*

```apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-ingress-controller
  namespace: ingress-nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ingress-nginx
  template:
    metadata:
      labels:
        app: ingress-nginx
      annotations:
        prometheus.io/port: '10254'
        prometheus.io/scrape: 'true'
    spec:
      initContainers:
      - command:
        - sh
        - -c
        - sysctl -w net.core.somaxconn=32768; sysctl -w net.ipv4.ip_local_port_range="1024 65535"
        image: alpine:3.6
        imagePullPolicy: IfNotPresent
        name: sysctl
        securityContext:
          privileged: true
      containers:
        - name: nginx-ingress-controller
          image: quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.10.2
          args:
            - /nginx-ingress-controller
            - --default-backend-service=$(POD_NAMESPACE)/default-http-backend
            - --configmap=$(POD_NAMESPACE)/nginx-configuration
            - --tcp-services-configmap=$(POD_NAMESPACE)/tcp-services
            - --udp-services-configmap=$(POD_NAMESPACE)/udp-services
            - --annotations-prefix=nginx.ingress.kubernetes.io
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          ports:
          - name: http
            containerPort: 80
          - name: https
            containerPort: 443
          livenessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
      nodeSelector:
        cloud.google.com/gke-nodepool: "ingress-nginx"
```
apiVersion: v1
