# Spring PetClinic — Datadog demo

A fork of the [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) sample application (Spring Boot 3.5, Java 21), adapted to demo Datadog observability:

- Custom metrics sent with DogStatsD to `DD_AGENT_HOST:8125` (`MetricsConfig`)
- JSON logs with Log4j2 (`log4j-layout-template-json`) for log/trace correlation
- Custom response headers `x-custom-random-error` and `x-custom-timestamp` to be used with `DD_TRACE_HEADER_TAGS` (`CustomHeaderFilter`)
- Kubernetes manifest with unified service tagging (`env`, `service`, `version`)

[Understanding the Spring Petclinic application with a few diagrams](https://speakerdeck.com/michaelisvy/spring-petclinic-sample-application)

## Prerequisites

- [podman](https://podman.io/) to build the image — no JDK or Maven needed on the host, the build runs `./mvnw` inside the container.
- `kubectl` configured for the target cluster.

## Build, push and deploy

Docker Hub repository: `samuelblin/petclinic`

The version is not hardcoded anywhere: it is passed at build time (`pom.xml` uses `${revision}`, `springpetclinic.yaml` uses the `__VERSION__` and `__GIT_SHA__` placeholders). Check the tags already pushed to [Docker Hub](https://hub.docker.com/r/samuelblin/petclinic/tags) and pick the next one:

```bash
./deploy.sh 1.0.31
```

The script:

1. checks that the working tree is clean and the commit is pushed to GitHub (required by Datadog Source Code Integration, see below), that you are logged in to Docker Hub, that the tag does not exist yet and that the current Kubernetes context is reachable;
2. asks for confirmation, showing the target context and the version currently deployed;
3. builds a multi-arch image (`linux/amd64,linux/arm64`, override with `PLATFORMS=linux/amd64 ./deploy.sh 1.0.31`) and pushes it;
4. applies `springpetclinic.yaml` with the placeholders replaced, then waits for the rollout.

The `Dockerfile` is a multi-stage build that produces a single fat-jar and runs it directly (no `mvnw spring-boot:run` at container start). The final image only contains a Java 21 JRE and the prebuilt `app.jar`.

> ⚠️ The target K8s nodes typically run **linux/amd64**, but a Mac (Apple Silicon) builds **linux/arm64** by default. Always pin the platform explicitly, or publish a multi-arch manifest.

### Manual steps with podman

```bash
VERSION=1.0.31
```

#### One-shot: build amd64 only and push

```bash
podman machine start                                   # if not already running
podman login docker.io
podman build --platform linux/amd64 --build-arg VERSION=$VERSION \
  -t docker.io/samuelblin/petclinic:$VERSION .
podman push docker.io/samuelblin/petclinic:$VERSION
```

#### Recommended: multi-arch manifest (amd64 + arm64)

```bash
podman manifest create samuelblin/petclinic:$VERSION
podman build --platform linux/amd64,linux/arm64 --build-arg VERSION=$VERSION \
  --manifest samuelblin/petclinic:$VERSION .
podman manifest push --all \
  samuelblin/petclinic:$VERSION \
  docker.io/samuelblin/petclinic:$VERSION
```

#### Deploy to Kubernetes

```bash
sed -e "s/__VERSION__/${VERSION:?set VERSION first}/g" -e "s/__GIT_SHA__/$(git rev-parse HEAD)/g" springpetclinic.yaml \
  | kubectl apply -f -
kubectl rollout status deployment/petclinic -n petclinic --timeout=5m
```

Do not apply the file directly with `kubectl apply -f springpetclinic.yaml`: the placeholders would be sent as is.

## Kubernetes and Datadog

The manifest creates the `petclinic` namespace if it does not exist (no error if it does) and deploys the app in it.

The front is exposed by the `petclinic-lb` service (`LoadBalancer`, port `8181` → container port `8080`) at `http://<EXTERNAL-IP>:8181/`. `deploy.sh` prints this URL at the end; otherwise get the IP with:

```bash
kubectl get service petclinic-lb -n petclinic
```

On a first deployment, `EXTERNAL-IP` stays `<pending>` for a minute or two while the cloud load balancer is created.

The manifest does not include the Datadog tracer: it expects the Datadog Agent to be installed in the cluster (DaemonSet + Cluster Agent) with Single Step Instrumentation enabled for the target namespace. The Agent also collects the container logs (`ad.datadoghq.com/spring-container.logs` annotation) and receives the DogStatsD metrics.

`DD_GIT_COMMIT_SHA` is replaced with the current commit at deploy time. For Datadog Source Code Integration to link traces and profiles to the code:

- deploy from the commit the image was built from (working tree clean, `git status` empty);
- push that commit to GitHub first (`DD_GIT_REPOSITORY_URL`).

## Database

The app uses its default in-memory H2 database, populated with sample data at startup: data is reset each time the pod restarts.

## License

The Spring PetClinic sample application is released under version 2.0 of the [Apache License](https://www.apache.org/licenses/LICENSE-2.0).
