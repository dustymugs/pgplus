1. copy `secret.yaml` and update copy

```
cp secret.yaml my-secret-copy.yaml
```

2. apply secret

```
kubectl apply -f my-secret-copy.yaml
```

3. copy `configmap.yaml` and update copy

```
cp configmap.yaml my-configmap-copy.yaml
```

Items to review/update include:

  - `postgres.master_dns_name`
  - `pgbouncer.pool_mode`
  - `walg.aws_endpoint`
  - `walg.s3_prefix`

4. apply properties

```
kubectl apply -f my-configmap-copy.yaml
```

5. copy `deployment.yaml` and update copy

```
cp deployment.yaml my-deployment-copy.yaml
```

Items to review include:

  - `spec.replicas`
  - `resources.limits`
  - `resources.requests`

6. apply deployment

```
kubectl apply -f my-deployment-copy.yaml
```

If you wish to dry-run...

```
kubectl apply --dry-run -f my-deployment-copy.yaml
```

7. (Optional) Set the `is_standby` and `restore` labels if you have replicas in your deployment

Let's use the following following output from `kubectl get pods --show-labels`

```
NAME                                READY     STATUS    RESTARTS   AGE       LABELS
...
pgplus-68bbbf854f-9l2tb   0/1     ContainerCreating   0          16s   done=,is_standby=,pod-template-hash=68bbbf854f,restore=,role=db
pgplus-68bbbf854f-jbdnp   0/1     ContainerCreating   0          16s   done=,is_standby=,pod-template-hash=68bbbf854f,restore=,role=db
pgplus-68bbbf854f-qqcnn   0/1     ContainerCreating   0          16s   done=,is_standby=,pod-template-hash=68bbbf854f,restore=,role=db
...
```

We want `pgplus-68bbbf854f-9l2tb` to be the master PostgreSQL instance and the other Pods to be standby PostgreSQL instances

```
kubectl label --overwrite pods pgplus-68bbbf854f-jbdnp restore=1 is_standby=1
kubectl label --overwrite pods pgplus-68bbbf854f-qqcnn restore=1 is_standby=1
```

8. Add CNAME DNS record for master PostgreSQL instance

9. Finally, let the pods know that you're done making label changes

```
kubectl label --overwrite pods --selector='role=db' done=1
```

10. At this point, the PGPlus containers will start initializing
