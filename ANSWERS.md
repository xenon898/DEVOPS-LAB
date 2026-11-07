# Written question

I would inventory the 40 Ingresses: hosts, paths, TLS, classes, annotations,
DNS, traffic, and dependencies on ingress-nginx behavior. I would group them
by app and feature, then choose a maintained Gateway API controller that
supports our Kubernetes versions and required features. I would install its
CRDs and controller, create a GatewayClass and shared Gateway listeners, and
test those listeners before moving routes.

I would convert a low-risk service first. Map its Ingress to an HTTPRoute and
review annotations such as rewrites, auth, rate limits, and timeouts
manually, since they may not translate directly. Run both paths side by side
and compare responses, TLS, redirects, health checks, and client IP handling.
Shift traffic in small batches while watching errors and latency, with a
rollback plan for each step. Change DNS or load balancers after the routes
behave as expected.

I expect unsupported annotations, route conflicts, listener attachment
rejections, and differences in path precedence or default-backend behavior.
Track these as application work and test edge cases before migrating
dependent services. Keep ingress-nginx through a measured rollback window,
set a retirement date, and remove it after route owners confirm success. The
project ended maintenance in March 2026, so I would not treat it as a
long-term fallback. [Gateway API migration guide](https://gateway-api.sigs.k8s.io/guides/getting-started/migrating-from-ingress/).
