# Spring PetClinic — Datadog demo

A fork of the [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) sample application (Spring Boot 3.5, Java 21), adapted to demo Datadog observability:

- Custom metrics sent with DogStatsD to `DD_AGENT_HOST:8125` (`MetricsConfig`)
- JSON logs with Log4j2 (`log4j-layout-template-json`) for log/trace correlation
- Custom response headers `x-custom-random-error` and `x-custom-timestamp` to be used with `DD_TRACE_HEADER_TAGS` (`CustomHeaderFilter`)
- Kubernetes manifest with unified service tagging (`env`, `service`, `version`)
- A **Datadog** menu entry (`/datadog`) to trigger a distributed-trace error (`/springservice`) and security detections (App & API Protection, Code Security, Workload Protection)

[Understanding the Spring Petclinic application with a few diagrams](https://speakerdeck.com/michaelisvy/spring-petclinic-sample-application)

## Datadog demo menu

The **Datadog** menu entry opens `/datadog`, with two sections:

- **Error**: calls another k8s service (`/springservice`, URL set by `springservice.remote-url`) to produce a distributed trace, or an error when the remote service is not reachable. The upstream **Error** entry (`/oups`, `RuntimeException`) stays in the top menu.
- **Security**: attack payloads for App & API Protection (WAF), deliberately unsafe sinks for Code Security (IAST: weak hash, SQL injection, command injection) and shell commands in the container for Workload Protection. The `/vuln/*` endpoints are unsafe on purpose: never expose them outside a demo. `security-traffic.sh` sends the same WAF traffic with curl.

### Hiding the Datadog menu entry

Set `petclinic.datadog-demo.enabled=false` to get the original application back: the menu entry is hidden and `/datadog`, `/vuln/*` and `/springservice` return 404 (`/oups` and its **Error** entry are kept). With the image:

- at build time: `podman build --build-arg DATADOG_DEMO=false ...` (the default of the `Dockerfile` is `true`), this is what `deploy.sh` does;
- at run time: set the env var `PETCLINIC_DATADOGDEMO_ENABLED=false` on the container, it overrides the build-time value.

## Prerequisites

- [podman](https://podman.io/) to build the image — no JDK or Maven needed on the host, the build runs `./mvnw` inside the container.
- `kubectl` configured for the target cluster, only to deploy to Kubernetes (`--k8s`).

## Build, push and deploy

One script per image:

| Script | Docker Hub repository | Datadog menu | Database |
|---|---|---|---|
| `deploy.sh` | [`samuelblin/petclinic`](https://hub.docker.com/r/samuelblin/petclinic/tags) | hidden (standard Petclinic) | H2 |
| `deploy-dd.sh` | [`samuelblin/petclinic-dd`](https://hub.docker.com/r/samuelblin/petclinic-dd/tags) | enabled (Datadog demo) | H2 |
| `deploy-postgres.sh` | [`samuelblin/petclinic-postgres`](https://hub.docker.com/r/samuelblin/petclinic-postgres/tags) | hidden (standard Petclinic) | PostgreSQL |
| `deploy-dd-postgres.sh` | [`samuelblin/petclinic-dd-postgres`](https://hub.docker.com/r/samuelblin/petclinic-dd-postgres/tags) | enabled (Datadog demo) | PostgreSQL |

`deploy.sh` holds the logic, the other scripts only set the image, the Datadog menu and the database, and accept the same arguments.

The version is not hardcoded anywhere: it is passed at build time (`pom.xml` uses `${revision}`, `springpetclinic.yaml` uses the `__IMAGE__`, `__VERSION__` and `__GIT_SHA__` placeholders). Check the tags already pushed to the repository and pick the next one.

By default the scripts stop once the image is pushed to Docker Hub. Add `--k8s` to also deploy it to the current Kubernetes context:

```bash
./deploy.sh 1.0.31             # standard: build and push only
./deploy-dd.sh 1.0.31          # Datadog demo: build and push only
./deploy.sh --k8s 1.0.31       # standard: build, push and deploy to Kubernetes
./deploy-dd.sh --k8s 1.0.31    # Datadog demo: build, push and deploy to Kubernetes
./deploy-dd-postgres.sh --k8s 1.0.31   # Datadog demo on PostgreSQL, with the database
```

All scripts deploy to the same `petclinic` deployment: the last one run with `--k8s` replaces the others in the cluster.

The script:

1. checks that the working tree is clean and the commit is pushed to GitHub (required by Datadog Source Code Integration, see below), that you are logged in to Docker Hub, that the tag does not exist yet in the repository and, with `--k8s`, that the current Kubernetes context is reachable;
2. asks for confirmation, showing the image, whether the Datadog menu is enabled, the database and, with `--k8s`, the target context and the version currently deployed;
3. builds a multi-arch image (`linux/amd64,linux/arm64`, override with `PLATFORMS=linux/amd64 ./deploy.sh 1.0.31`) and pushes it;
4. with `--k8s` only: for the PostgreSQL variants, applies `springpetclinic-postgres.yaml` and waits for the database to be ready (so the app does not restart while it starts); then applies `springpetclinic.yaml` with the placeholders replaced and waits for the rollout.

The `Dockerfile` is a multi-stage build that produces a single fat-jar and runs it directly (no `mvnw spring-boot:run` at container start). The final image only contains a Java 21 JRE and the prebuilt `app.jar`.

> ⚠️ The target K8s nodes typically run **linux/amd64**, but a Mac (Apple Silicon) builds **linux/arm64** by default. Always pin the platform explicitly, or publish a multi-arch manifest.

### Manual steps with podman

```bash
VERSION=1.0.31
```

The commands below build the standard image (`--build-arg DATADOG_DEMO=false`). For the Datadog demo image, drop this build arg and replace `samuelblin/petclinic` with `samuelblin/petclinic-dd`. For PostgreSQL, add `--build-arg SPRING_PROFILE=postgres` and use the `-postgres` repository.

#### One-shot: build amd64 only and push

```bash
podman machine start                                   # if not already running
podman login docker.io
podman build --platform linux/amd64 --build-arg VERSION=$VERSION --build-arg DATADOG_DEMO=false \
  -t docker.io/samuelblin/petclinic:$VERSION .
podman push docker.io/samuelblin/petclinic:$VERSION
```

#### Recommended: multi-arch manifest (amd64 + arm64)

```bash
podman manifest create samuelblin/petclinic:$VERSION
podman build --platform linux/amd64,linux/arm64 --build-arg VERSION=$VERSION --build-arg DATADOG_DEMO=false \
  --manifest samuelblin/petclinic:$VERSION .
podman manifest push --all \
  samuelblin/petclinic:$VERSION \
  docker.io/samuelblin/petclinic:$VERSION
```

#### Deploy to Kubernetes

```bash
kubectl apply -f springpetclinic-postgres.yaml    # PostgreSQL variants only
kubectl rollout status deployment/petclinic-db -n petclinic --timeout=5m
IMAGE=docker.io/samuelblin/petclinic:${VERSION:?set VERSION first}   # or petclinic-dd, petclinic-postgres, petclinic-dd-postgres
sed -e "s|__IMAGE__|$IMAGE|g" -e "s/__VERSION__/$VERSION/g" -e "s/__GIT_SHA__/$(git rev-parse HEAD)/g" springpetclinic.yaml \
  | kubectl apply -f -
kubectl rollout status deployment/petclinic -n petclinic --timeout=5m
```

Do not apply the file directly with `kubectl apply -f springpetclinic.yaml`: the placeholders would be sent as is.

## Kubernetes and Datadog

The manifest creates the `petclinic` namespace if it does not exist (no error if it does) and deploys the app in it.

The front is exposed by the `petclinic-lb` service (`LoadBalancer`, port `8181` → container port `8080`) at `http://<EXTERNAL-IP>:8181/`. the deploy scripts print this URL at the end with `--k8s`; otherwise get the IP with:

```bash
kubectl get service petclinic-lb -n petclinic
```

On a first deployment, `EXTERNAL-IP` stays `<pending>` for a minute or two while the cloud load balancer is created.

The manifest does not include the Datadog tracer: it expects the Datadog Agent to be installed in the cluster (DaemonSet + Cluster Agent) with Single Step Instrumentation enabled for the target namespace. The Agent also collects the container logs (`ad.datadoghq.com/spring-container.logs` annotation) and receives the DogStatsD metrics.

`DD_GIT_COMMIT_SHA` is replaced with the current commit at deploy time. For Datadog Source Code Integration to link traces and profiles to the code:

- deploy from the commit the image was built from (working tree clean, `git status` empty);
- push that commit to GitHub first (`DD_GIT_REPOSITORY_URL`).

## Database

The `deploy.sh` and `deploy-dd.sh` images use the default in-memory H2 database, populated with sample data at startup: data is reset each time the pod restarts.

The `-postgres` images are built with `--build-arg SPRING_PROFILE=postgres` (env `SPRING_PROFILES_ACTIVE=postgres`, can be overridden at run time) and connect to PostgreSQL with `POSTGRES_URL`, `POSTGRES_USER` and `POSTGRES_PASS` (`application-postgres.properties`). In Kubernetes, `springpetclinic-postgres.yaml` deploys in the `petclinic` namespace:

- a `petclinic-db` secret with these three variables, loaded by the app through `envFrom` (`optional`, so ignored by the H2 variants);
- a `petclinic-db` deployment (`postgres:17`) and service (port `5432`).

Demo only: the credentials are fixed and the database has no persistent volume, the schema and sample data are recreated when the app starts (`spring.sql.init.mode=always`), and the data is lost when the database pod restarts. Going back to an H2 variant leaves the database in place, remove it with `kubectl delete deployment,service,secret petclinic-db -n petclinic` (not `kubectl delete -f springpetclinic-postgres.yaml`: it would also delete the `petclinic` namespace, and the app with it).

To run the PostgreSQL image locally with podman:

```bash
podman network create petclinic
podman run -d --network petclinic --name petclinic-db \
  -e POSTGRES_DB=petclinic -e POSTGRES_USER=petclinic -e POSTGRES_PASSWORD=petclinic postgres:17
podman run --rm --network petclinic -p 8080:8080 \
  -e POSTGRES_URL=jdbc:postgresql://petclinic-db:5432/petclinic \
  docker.io/samuelblin/petclinic-postgres:$VERSION
```

The `k8s/db.yml` and `k8s/petclinic.yml` files come from upstream and are not used by the deploy scripts.

## License

The Spring PetClinic sample application is released under version 2.0 of the [Apache License](https://www.apache.org/licenses/LICENSE-2.0).
