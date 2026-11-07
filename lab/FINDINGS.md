# Part 4 findings

## Current status

The last clean `./scenario.sh verify` passed 9 of 11 checks. Backend, gateway,
worker, metrics, and the migration Job were healthy. The reporter was not
ready, and `/report` did not return a pod count. I have four confirmed chart
fixes; I have not resolved the reporter failure or verified all six defects.
Part 4 is incomplete.

The first recorded install also showed an invalid Job pod restart policy. The
current chart uses `restartPolicy: Never`, and the Job now completes.

In a clean kind run, a temporary pod using the reporter service account, UID
10001, and the mounted service-account CA received valid JSON from the
namespaced pod API. That confirms the account and CA can make that request. It
does not prove that the reporter reads the same response correctly.

## Confirmed chart corrections

### Migration Job restart policy

**Symptom:** The first recorded install failed to apply the migration Job:

```text
Error: server-side apply failed for object debug-lab/migrate batch/v1, Kind=Job: Job.batch "migrate" is invalid: spec.template.spec.restartPolicy: Required value: valid values: "OnFailure", "Never"
```

**Cause and fix:** The Job had an invalid restart policy. Its current pod
template uses `restartPolicy: Never`.

**How I found it:** The Kubernetes API rejected the Job during install. The
latest verify reports `PASS  migrate Job completed`.

### Application port

**Symptom:** The backend readiness probe targeted port 8080, while the
application log said it was listening on 8081:

```text
Readiness probe failed: Get "http://10.244.0.7:8080/healthz": dial tcp 10.244.0.7:8080: connect: connection refused
2026/11/06 13:15:39 eb-debug-app 2.0.0 starting: mode=api pod=backend-586756f864-ghv5z listening on :8081 (image default is 8081; set PORT to override)
```

**Cause and fix:** The chart's Services and probes use the shared port 8080,
but the image defaults to 8081. The Deployments now set `PORT` from the chart's
shared port value.

**How I found it:** I compared the readiness failure with the process startup
log. After setting `PORT`, the backend, gateway, worker, and metrics passed
their readiness and in-cluster checks.

### Worker cache directory

**Symptom:** The worker's previous-container log reported:

```text
FATAL: worker could not initialise its cache: mkdir /var/cache/app: read-only file system — the process needs a writable directory at /var/cache/app (mount a volume there, or set CACHE_DIR)
```

**Cause and fix:** The worker needs a writable cache directory while its root
filesystem is read-only. The chart mounts an `emptyDir` at `/var/cache/app`.

**How I found it:** I read the previous-container log. The worker is now ready.

### Reporter watch permission

**Symptom:** The reporter service account initially could not watch pods:

```text
kubectl auth can-i watch pods -n debug-lab --as=system:serviceaccount:debug-lab:reporter
no
```

After granting the `watch` verb, the same check returned `yes`. The current
Role grants `get`, `list`, and `watch` on pods to the `reporter` service
account. The verify script's list permission check passes. These permission
checks did not resolve the separate reporter parse error below.

**How I found it:** I checked the service account's effective permissions
with `kubectl auth can-i` and then retested after updating the Role.

## Unresolved reporter failure

The latest reporter logs still say:

```text
2026/11/07 01:09:04 pod list failed: parse pod list: unexpected end of JSON input
2026/11/07 01:09:04 GET /healthz -> 503 (from 10.244.0.1:60144)
```

The reporter pod stayed Running but unready. A temporary pod with the reporter
service account, UID 10001, and the mounted CA made a TLS-verified request to
`/api/v1/namespaces/debug-lab/pods?limit=100` and parsed the response:

```text
path=/api/v1/namespaces/debug-lab/pods?limit=100 accept=identity status=200 encoding=None wire=49972 body=49972 items=7
path=/api/v1/pods?limit=100 accept=identity status=403 body=277
```

This confirms that the namespaced API response was valid JSON for the reporter
account. The all-namespaces request was forbidden, as expected for the
namespace-scoped Role. Granting a temporary cluster-wide pod role in the test
cluster did not change the 9/11 result; I removed that test role afterward.
The API server's pod-list counters also showed a namespaced `LIST` with code
200 while the reporter was retrying. These checks still do not reveal the
response bytes seen by the reporter's own HTTP client. I removed the
experimental `POD_NAMESPACE` and `WATCH_NAMESPACE` settings because they did
not change the symptom. The cause remains unknown.

**Next step:** capture the reporter process's own HTTP response status and
body length with a compatible debug client or trace, then change the chart only
if that points to a concrete setting. Do not claim Part 4 is green until the
official verifier reports 11/11.

## Other chart settings reviewed

The current gateway value is `http://backend:8080`, the metrics CPU request
and limit are `100m` and `500m`, and the RoleBinding subject is `reporter`.
The latest verify passes the gateway and metrics checks. I do not have
recorded evidence that the gateway URL or metrics CPU values were independent
defects. The list-permission failure appeared in an early verify, but later
verifies pass it; the RoleBinding in the current chart already targets the
`reporter` service account. I am not claiming an unsupported RoleBinding
target or CPU-limit fix.
