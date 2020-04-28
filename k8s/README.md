1. copy `secret.yaml` and update copy

```
cp secret.yaml my-secret-copy.yaml
```

2. apply secret

```
kubectl apply -f ./my-secret-copy.yaml
```

3. copy `configmap.properties` and update copy

```
cp configmap.properties my-configmap-copy.properties
```

Items to review/update include:

  - `postgres.master_dns_name`
  - `pgbouncer.pool_mode`
  - `walg.s3_prefix`

4. apply properties

```
kubectl create configmap pgplus --from-file=my-configmap-copy.properties
```

5. copy `deployment.yaml` and update copy

```
cp deployment.yaml my-deployment-copy.yaml
```

Items to review include:

  - `replicas`

6. apply deployment

```
kubectl apply -f my-deployment-copy.yaml
```

7. (Optional) Set the `is_standby` and `restore` labels if you have replicas in your deployment

Let's use the following following output from `kubectl get pods --show-labels`

```
NAME                                READY     STATUS    RESTARTS   AGE       LABELS
...
pgplus-deployment-75675f5897-7ci7o   1/1       Running   0          18s      role=db,pod-template-hash=3123191453
pgplus-deployment-75675f5897-kzszj   1/1       Running   0          18s      role=db,pod-template-hash=3123191453
pgplus-deployment-75675f5897-qqcnn   1/1       Running   0          18s      role=db,pod-template-hash=3123191453
...
```

We want `pgplus-deployment-75675f5897-7ci7o` to be the master PostgreSQL instance and the other Pods to be standby PostgreSQL instances

```
kubectl label --overwrite pods pgplus-deployment-75675f5897-kzszj restore=1 is_standby=1
kubectl label --overwrite pods pgplus-deployment-75675f5897-qqcnn restore=1 is_standby=1
```

8. Finally, let the pods know that you're done making label changes

```
kubectl label --overwrite pods --selector='role=db' done=1
```

9. At this point, the PGPlus containers will start initializing
