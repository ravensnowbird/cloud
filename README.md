

# Desplegar Kubernetes en GCloud utilizando:

Container Registry
Cloud Build
Kubernetes 
Cloud Shell

 Nueva sesion de Cloud Shell 
*https://console.cloud.google.com/*


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

# Configurando y custumizando ingress-nginx

1.- Creamos el namespece dentro del Clusrter incluido en *namespace.yaml*
```apiVersion: v1```
```kind: Namespace```
```metadata:```

2. Configuramos el servicio y el el deploy default incluido en *default-backend.yaml*

```apiVersion: v1```
```kind: Service```
``` metadata:```
``` name: default-http-backend```
```namespace: ingress-nginx```
```labels:```
```app: default-http-backend```

```spec:```
```ports:```
``` - port: 80```
``` targetPort: 8080```
```selector:```
```app: default-http-backend```
```name: ingress-nginx```

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
          image: quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.25.1
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
        apiVersion: v1
```


5. Realizamos el despliegue en Kubernetes:

```
kubectl apply -f 1_namespace.yaml 2_default-backend.yaml 3_configmap.yaml 4_tcp-services-configmap.yaml 5_udp-services-configmap.yaml 6_install.yaml
```

6. Validamos el despliegue en Kubernetes y el servicio ok:

    https://console.cloud.google.com/kubernetes/workload?organizationId=439006755624&project=resuelve-sandbox&workload_list_tablesize=50 
    https://console.cloud.google.com/kubernetes/discovery?organizationId=439006755624&project=resuelve-sandbox&service_list_tablesize=50
	

# Instalando Cert Manager

1.- Creamos un namespace para correr cert-manager 

```kubectl create namespace cert-manager```

2.- Deshabilitamos la validación de recursos en el namespacer cert-manager para evitar problema huevo - gallina con cert - manager y webhook 

```kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
```

3.-hora podemos seguir adelante e instalar cert-manager. Todos los recursos (CustomResourceDefinitions, cert-manager y el componente webhook) se incluyen en un único archivo de manifiesto YAML:

```cert-manager.yaml```

Vertificamos la instalación:

```kubectl get pods --namespace cert-manager```

# Desplegando nuestra imagen en Container

1.- Seleccionar el proyecto de despliegue 

```gcloud config set project [PROJECT_ID]```

2.- Habilitar las APIS necesarias para el continuo:

``` 
gcloud services enable container.googleapis.com \
    cloudbuild.googleapis.com \
    sourcerepo.googleapis.com \
    containeranalysis.googleapis.com
```

3.- Desplegar el clouster para Sandbox

```
gcloud container clusters create sandbox\
    --num-nodes 1 --zone us-central1-b  
```

5.- Clona el código del repo desde GitHub
```
cd ~
git clone https://github.com/resuelve/cloud.git \
    cloud
```
6.- Creamos la imagen de contenedor con CloudBuild aplicando el siguiente comando:
```
cd ~/cloud
COMMIT_ID="$(git rev-parse --short=7 HEAD)"
gcloud builds submit --tag="gcr.io/${PROJECT_ID}/hello-cloudbuild:${COMMIT_ID}" .
```

7.- Verificamos imagen en el contenedor:

```
https://console.cloud.google.com/gcr?_ga=2.175160550.-515079399.1563474278&_gac=1.40177302.1566322914.EAIaIQobChMImc2j1fyR5AIVhcpkCh2zAwsrEAAYASAAEgKxTPD_BwE

Podemos realizar la integración a traves del archivo pero por el momento lo dejamos así
cloudbuild.yaml 

```
8.- configurarmos el .yml para envío a Kubernets *kubernetes.yaml.tpl*

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-cloudbuild
  labels:
    app: hello-cloudbuild
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-cloudbuild
  template:
    metadata:
      labels:
        app: hello-cloudbuild
    spec:
      containers:
      - name: hello-cloudbuild
        image: gcr.io/GOOGLE_CLOUD_PROJECT/$IMAGEN
        ports:
        - containerPort: 8080
---
kind: Service
apiVersion: v1
metadata:
  name: hello-cloudbuild
spec:
  annotations:
    kubernetes.io/tls-acme: "true"
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-body-size:  25M
    nginx.ingress.kubernetes.io/client-body-buffer-size:  25M

-----
apiVersion: v1
kind: Service
metadata:
  name: hello-cloudbuild
spec:
  selector:
    app: hello-cloudbuild
  ports:
  - name: http
    protocol: TCP
    port: 8080
    targetPort: 8080

-----
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
name: hello-cloudbuild
spec:
  selector:
    app: hello-cloudbuild
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: LoadBalancer
apiVersion: extensions/v1beta1
  tls:
  - secretName: hello-cloudbuild
    hosts:
    - hello-cloudbuild.resuelve.io                               

  ```

9.- Para realiza el despliegue de la aplicación en el Cluster lanzamos el siguiente comando desde Shell

```kubectl apply -f kubernetes.yaml.tpl```

Para validar el despliegue de la aplicación dentro de Kubernets  aplicamos el siguiente comando:

```
kubectl get pods

te debe de dar la siguiente entrada:

NAME                               READY   STATUS    RESTARTS   AGE
hello-app-555d9f45f8-jzwbp         1/1     Running   0          20h
hello-cloudbuild-68848cc9c-s9xtk   1/1     Running   0          114m

```
# Instala KubeDB Operator

1.- Instalando dependencias 

```helm repo add appscode https://charts.appscode.com/stable/
helm repo update
helm search appscode/kubedb

NAME                   	CHART VERSION	APP VERSION 	DESCRIPTION
appscode/kubedb        	v0.13.0-rc.0 	v0.13.0-rc.0	KubeDB by AppsCode - Production ready databases on Kubern...
appscode/kubedb-catalog	v0.13.0-rc.0 	v0.13.0-rc.0	KubeDB Catalog by AppsCode - Catalog for database versions
´´´
2.- Instalamos kubedb operator 

``` helm install appscode/kubedb --name kubedb-operator --version v0.13.0-rc.0 \
  --namespace kube-system
```
3.- Esperamos que los cdr esten registrados
```kubectl get crds -l app=kubedb -w ```

4.- Instalamos el catalogo de versiones de Databases para KubeDB

```helm install appscode/kubedb-catalog --name kubedb-catalog --version v0.13.0-rc.0 \
  --namespace kube-system ```

# Installing in GKE Cluster

```
kubectl create clusterrolebinding "cluster-admin-$(whoami)" \
  --clusterrole=cluster-admin \
  --user="$(gcloud config get-value core/account)"
  ´´´

  Verificamos la instalación

```kubectl get pods --all-namespaces -l app=kubedb --watch```
Ctrl+C

```kubectl get crd -l app=kubedb ```

# Implementando Kubernetes Blue/Green Deplyment 

1.-Implementammos un  contenedor con la etiqueta que lleve el nombre y la versión, estas se utilizaran mas adelante para cambiar a la versión Green.

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-1.10
spec:
  replicas: 3
  template:
    metadata:
      labels:
        name: nginx
        version: "1.10"
    spec:
      containers: 
        - name: nginx
          image: nginx:1.10
          ports:
            - name: http
              containerPort: 80
```
Lo encontraremos en el archivo *blue-deploy.yml*

2.- Aplicamos kubectl apply -f blue-deploy.yaml

3.- El servicio es de tipo LoadBalancer, por lo que se puede acceder a través de un Network Load Balancer. Utilizamos las etiquetas de nombre y versión especificadas en la implementación para seleccionar los pods para el servicio.

```
apiVersion: v1
kind: Service
metadata: 
  name: nginx
  labels: 
    name: nginx
spec:
  ports:
    - name: http
      port: 80
      targetPort: 80
  selector: 
    name: nginx
    version: "1.10"
  type: LoadBalancer
```
4.- Aplicamos un kubectl apply -f service.yaml para crear el servicio

5.- La versión implementada actualmente se puede probar en una ventana separada sondeando el servidor. Esto imprimirá la versión actual de nginx implementada.

``` EXTERNAL_IP=$(kubectl get svc nginx -o jsonpath="{.status.loadBalancer.ingress[*].ip}") 
    while true; do curl -s http://$EXTERNAL_IP/version | grep nginx; sleep 0.5; done
```
6.- Impementamos la versión Green, se creará una nueva mmplementación para actualizar la aplicación y el Service se actualizará para apuntar a la nueva versión. La onfiguración estará dentro de greem-deply.yaml

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-1.11
spec:
  replicas: 3
  template:
    metadata:
      labels:
        name: nginx
        version: "1.11"
    spec:
      containers: 
        - name: nginx
          image: nginx:1.11
          ports:
            - name: http
              containerPort: 80

```
7.- Creamos el nuevo deployment y hacemos el swicheo a la versión Green:

```sed 's/1\.10/1.11/' blue-deploy.yaml | kubectl apply -f -```

8.- Actualizaremos el Servicio para seleccionar pods del despliegue Green. Esto hará que se establezcan nuevas solicitudes en los nuevos pods. Puede actualizar el archivo directamente o usar una herramienta como sed:
sed 's/1\.10/1.11/' kubernetes/service.yaml 

8.- Subimos el servicio:
sed 's/1\.10/1.11/' service.yaml | kubectl apply -f -

