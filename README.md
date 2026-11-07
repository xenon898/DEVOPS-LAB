# DevOps take-home

This repository contains a small HTTP service, its Helm chart and local setup
script, plus the supplied Part 4 debug lab.

## Run it locally

With Docker, kind, kubectl, Helm and Bash installed, run:

```bash
./setup.sh
curl --resolve demo.local:80:127.0.0.1 http://demo.local/
curl --resolve demo.local:80:127.0.0.1 http://demo.local/healthz
kubectl -n demo get deployment,service,ingress
```

The first request returns the app name, version and pod hostname as JSON. The
second returns `ok`. The `--resolve` option sends the `demo.local` Host header
to the kind cluster without requiring a hosts-file edit.

The chart defaults to two replicas. Each pod requests 50m CPU and 64Mi memory,
with limits of 250m CPU and 128Mi memory. The service is intentionally small,
so these are modest starting values; the requests reserve enough for scheduling
and the limits bound a simple local workload. Production values should come
from observed usage and an agreed availability target.

## Configuration

`APP_NAME` and `VERSION` are stored in the `demo-config` ConfigMap and passed
to the container as environment variables. The same ConfigMap is mounted as a
volume so the service can also observe a direct ConfigMap update after
Kubernetes refreshes the projected files. For example:

```bash
kubectl -n demo patch configmap demo-config --type merge \
  -p '{"data":{"APP_NAME":"changed-in-cluster"}}'
```

Then request `/` again after the ConfigMap volume has refreshed. A Helm value
change can be applied with `helm upgrade --install demo ./chart -n demo`.

## Part 4 status

The terminal recording is in `lab/part4-session.log`. The chart sets
`restartPolicy: Never` for the migration Job, sets `PORT` to 8080 after the
image log showed it listening on 8081, mounts a writable cache directory for
the worker, and grants the reporter service account pod watch access. The last
clean verify passed 9 of 11 checks. The reporter is still unready, and `/report`
does not return a pod count. A TLS-verified probe using the reporter account
parsed a namespaced pod-list response, but that did not identify why the
reporter itself logs a JSON parse error. Part 4 is incomplete; I have not
captured a green verify. `lab/FINDINGS.md` records the evidence and next step.

## Deliberate omissions and production work

I did not add CI, TLS, authentication, persistent storage, or an autoscaler.
Those are outside this small exercise; omitting TLS and auth would be unsafe
for a public service. Before production I would add image scanning and signing,
automated tests and chart validation, a supported ingress or Gateway API
controller, TLS and identity, network policies, disruption budgets,
observability, and resource settings based on load data. The setup script
installs ingress-nginx only because the assignment requires it for this local
demo; the project retired in March 2026 and should not be selected for a new
production deployment ([retirement notice](https://kubernetes.github.io/ingress-nginx/)).

## How I used AI

AI use: I completed the service, chart, setup script, and written answer
myself. I used ChatGPT only for Part 4 troubleshooting, checking its
suggestions against cluster output before correcting the Job policy, port,
worker cache mount, and reporter permissions. The reporter issue remains
unresolved.
