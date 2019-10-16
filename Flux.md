# Instalando Agente Flux:

Guia para ejecutar Flux y desplegar cambios en el cluster.

# Prerrequisitos:

1.- Rol en GKE *ClusterRoleBinding*:
```
kubectl create clusterrolebinding "cluster-admin-$(whoami)" \
--clusterrole=cluster-admin \
--user="$(gcloud config get-value core/account)"
```
2.- Instalar  fluxctl:
```
brew install fluxctl
```
3.- En este caso utilizaremos el siguiente repositorio de Git

https://github.com/jvazquezm/flux-get-started/

# Configurando Flux

1.- Para configurar Flux dentro de Kubernets utilizando el  repositorio flux-get-started, corremos el siguiente comando:
```
export GHUSER=jvazquezm 
fluxctl install \
--git-user=${GHUSER} \
--git-email=${GHUSER}@users.noreply.github.com \
--git-url=git@github.com:${GHUSER}/flux-get-started \
--git-path=namespaces,workloads \
--namespace=fluxx | kubectl apply -f 
``` 
2.- Corremos el siguiente comando para sincronizar Flux:

```kubectl -n flux rollout status deployment/flux
```
3.- Dar acceso de escritura, Flux genera una clave SSH y registra la clave pública. Encuentre la clave pública SSH instalando fluxctl y ejecutando:

```
fluxctl identity --k8s-fwd-ns flux
```

4.- Copia y pega la clave aquí:

```https://github.com/YOURUSER/flux-get-started/settings/keys/new```

Nota: la clave SSH debe configurarse para tener acceso de escritura y lectura en el repositorio. Más específicamente, la clave SSH debe poder crear y actualizar etiquetas.


5.- Una vez realizados estos pasos podemos modificar el código y veremos reflejado automáticamente los cambios dentro del Cluster.

Estos cambian 5 minutos aproximadamente en realizarse pero si no eres conocido por esperar pacientemente puedes corre el siguiente comando:
```fluxctl sync --k8s-fwd-ns flux
```

Para finalizar podemos checar los cambios realizados acá:

```kubectl -n demo port-forward deployment/podinfo 9898:9898 &
curl localhost:9898```
