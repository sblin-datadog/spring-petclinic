# Spring PetClinic — Datadog demo

A fork of the [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) sample application (Spring Boot 3.5, Java 21), adapted to demo Datadog observability:

- Custom metrics sent with DogStatsD to `DD_AGENT_HOST:8125` (`MetricsConfig`)
- JSON logs with Log4j2 (`log4j-layout-template-json`) for log/trace correlation
- Custom response headers `x-custom-random-error` and `x-custom-timestamp` to be used with `DD_TRACE_HEADER_TAGS` (`CustomHeaderFilter`)
- Kubernetes manifest with unified service tagging (`env`, `service`, `version`)

[Understanding the Spring Petclinic application with a few diagrams](https://speakerdeck.com/michaelisvy/spring-petclinic-sample-application)

## Prerequisites

- [podman](https://podman.io/) to build and run the image — nothing else is needed on the host.
- A JDK 21 only for local development. Maven is provided by the `./mvnw` wrapper, no installation required.

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
sed -e "s/__VERSION__/$VERSION/g" -e "s/__GIT_SHA__/$(git rev-parse HEAD)/g" springpetclinic.yaml \
  | kubectl apply -f -
```

Do not apply the file directly with `kubectl apply -f springpetclinic.yaml`: the placeholders would be sent as is.

## Run locally with podman

```bash
podman run --rm -p 8080:8080 docker.io/samuelblin/petclinic:1.0.31
```

Then open <http://localhost:8080/>.

## Kubernetes and Datadog

The manifest deploys the app behind a `LoadBalancer` on port `8181`. It does not include the Datadog tracer: it expects the Datadog Agent to be installed in the cluster (DaemonSet + Cluster Agent) with Single Step Instrumentation enabled for the target namespace. The Agent also collects the container logs (`ad.datadoghq.com/spring-container.logs` annotation) and receives the DogStatsD metrics.

`DD_GIT_COMMIT_SHA` is replaced with the current commit at deploy time. For Datadog Source Code Integration to link traces and profiles to the code:

- deploy from the commit the image was built from (working tree clean, `git status` empty);
- push that commit to GitHub first (`DD_GIT_REPOSITORY_URL`).

## Database configuration

In its default configuration, Petclinic uses an in-memory database (H2) which gets populated at startup with data. The h2 console is exposed at `http://localhost:8080/h2-console`, and it is possible to inspect the content of the database using the `jdbc:h2:mem:<uuid>` URL. The UUID is printed at startup to the console.

A similar setup is provided for MySQL and PostgreSQL if a persistent database configuration is needed. Whenever the database type changes, the app needs to run with a different profile: `spring.profiles.active=mysql` for MySQL or `spring.profiles.active=postgres` for PostgreSQL (for example with `-e SPRING_PROFILES_ACTIVE=postgres` on `podman run`).

Start MySQL or PostgreSQL locally with podman:

```bash
podman run -e MYSQL_USER=petclinic -e MYSQL_PASSWORD=petclinic -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=petclinic -p 3306:3306 mysql:9.2
```

or

```bash
podman run -e POSTGRES_USER=petclinic -e POSTGRES_PASSWORD=petclinic -e POSTGRES_DB=petclinic -p 5432:5432 postgres:17.5
```

You can also use the provided `docker-compose.yml` file. Each service is named after the Spring profile:

```bash
podman compose up mysql
```

or

```bash
podman compose up postgres
```

Further documentation is provided for [MySQL](src/main/resources/db/mysql/petclinic_db_setup_mysql.txt) and [PostgreSQL](src/main/resources/db/postgres/petclinic_db_setup_postgres.txt).

## Local development (optional)

Build and run the jar without a container (requires a JDK 21):

```bash
git clone https://github.com/sblin-datadog/spring-petclinic.git
cd spring-petclinic
./mvnw package
java -jar target/*.jar
```

Or run it with the Spring Boot Maven plugin, which picks up changes to resources immediately (Java sources still need a compile, usually done by the IDE):

```bash
./mvnw spring-boot:run
```

To work in an IDE (IntelliJ IDEA, VS Code, Eclipse with m2e…), open the project through its [pom.xml](pom.xml) and run the `PetClinicApplication` main class.

### Compiling the CSS

`petclinic.css` in `src/main/resources/static/resources/css` is generated from `petclinic.scss` combined with [Bootstrap](https://getbootstrap.com/). If you change the `scss` or upgrade Bootstrap, recompile it with the Maven profile `css`:

```bash
./mvnw package -P css
```

## License

The Spring PetClinic sample application is released under version 2.0 of the [Apache License](https://www.apache.org/licenses/LICENSE-2.0).
