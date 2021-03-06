# PGPlus on Kubernetes

## A basic workflow to create a new PostgreSQL cluster

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

7. Set the `is_standby`, `restore` labels if you have replicas in your deployment

Let's use the output from the following command

```
kubectl get pods --show-labels -l "role=db"
```

```

NAME                                READY     STATUS    RESTARTS   AGE       LABELS
...
pgplus-68bbbf854f-9l2tb   0/1     ContainerCreating   0          16s   done=,is_standby=,restore=,role=db,pod-template-hash=68bbbf854f
pgplus-68bbbf854f-jbdnp   0/1     ContainerCreating   0          16s   done=,is_standby=,restore=,role=db,pod-template-hash=68bbbf854f
pgplus-68bbbf854f-qqcnn   0/1     ContainerCreating   0          16s   done=,is_standby=,restore=,role=db,pod-template-hash=68bbbf854f

...
```

We want `pgplus-68bbbf854f-9l2tb` to be the master PostgreSQL pod and the other pods to be standby PostgreSQL pods.

Instruct the other pods to restore the latest base backup when ready

```
kubectl label --overwrite pods pgplus-68bbbf854f-jbdnp restore=1 is_standby=1
kubectl label --overwrite pods pgplus-68bbbf854f-qqcnn restore=1 is_standby=1
```

8. Finally, let the pods know that you're done making label changes

```
kubectl label --overwrite pods --selector=role=db done=1
```

9. Expose master and standby PostgreSQL pods as separate services (one service for master, a separate service for standbys)

```
cp services.yaml my-services-copy.yaml
```

Inspect and update the following:

  - `metadata.name`
  - `port` and `targetPort`

Apply Services

```
kubectl apply -f my-services-copy.yaml
```

10. Instruct the master PostgreSQL pod to take a base backup

```
kubectl exec pgplus-68bbbf854f-9l2tb -- gosu postgres bash -c 'wal-g backup-push $PGDATA'
```

11. At this point, the PGPlus containers will start initializing

12. After a few seconds, check the replication status

```
kubectl exec pgplus-68bbbf854f-9l2tb -- psql -U postgres -c '\x' -c "SELECT * FROM pg_stat_replication"
```

We expect one row per standby PostgreSQL pod

```
Expanded display is on.
-[ RECORD 1 ]----+------------------------------
pid              | 246
usesysid         | 10
usename          | postgres
application_name | walreceiver
client_addr      | 10.244.0.236
client_hostname  | 
client_port      | 50632
backend_start    | 2020-06-03 16:03:45.643322+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/7000000
write_lsn        | 0/7000000
flush_lsn        | 0/7000000
replay_lsn       | 0/7000000
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
reply_time       | 2020-06-03 16:12:10.001118+00
-[ RECORD 2 ]----+------------------------------
pid              | 247
usesysid         | 10
usename          | postgres
application_name | walreceiver
client_addr      | 10.244.0.157
client_hostname  | 
client_port      | 53624
backend_start    | 2020-06-03 16:03:45.946197+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/7000000
write_lsn        | 0/7000000
flush_lsn        | 0/7000000
replay_lsn       | 0/7000000
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
reply_time       | 2020-06-03 16:12:10.001279+00
```

## A basic script to create a new PostgreSQL cluster

Essentially the above basic flow in a bash script

```
kubectl delete --wait services db-master db-standby || true
kubectl delete --wait deployments pgplus || true
kubectl delete --wait configmaps pgplus || true
kubectl delete --wait secrets pgplus || true

kubectl apply --overwrite --wait -f my-secret.yaml
kubectl apply --overwrite --wait -f my-configmap.yaml
kubectl apply --overwrite --wait -f my-deployment.yaml

PODS=$(kubectl get pods --selector=role=db --no-headers | awk '{print $1}')
OLD_IFS=$IFS
IFS=$'\n'
MASTER_POD=""
for pod in $PODS; do
	if [ -z "$MASTER_POD" ]; then
		MASTER_POD="$pod"
		echo "Master pod: $pod"
	else
		echo "Standby pod: $pod"
		kubectl label --overwrite pods "$pod" restore=1 is_standby=1
	fi
done
IFS=$OLD_IFS

kubectl label --overwrite pods --selector=role=db done=1
kubectl apply --overwrite --wait -f my-services.yaml

kubectl exec $MASTER_POD -- gosu postgres bash -c 'wal-g backup-push $PGDATA'
echo "waiting for standbys to come up"
sleep 70
kubectl exec $MASTER_POD -- psql -U postgres -c '\x' -c "SELECT * FROM pg_stat_replication"
```
