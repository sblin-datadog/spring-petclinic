FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /app
COPY .mvn/ .mvn
COPY mvnw pom.xml ./
RUN ./mvnw -B dependency:go-offline
COPY src ./src
ARG VERSION=0.0.0-SNAPSHOT
RUN ./mvnw -B package -DskipTests -Drevision=${VERSION} \
 && cp target/spring-petclinic-*.jar app.jar

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
RUN apt-get update \
 && apt-get install -y --no-install-recommends netcat-openbsd \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/app.jar app.jar
# Build with --build-arg DATADOG_DEMO=false to hide the "Datadog" menu entry
# (can still be overridden at runtime with PETCLINIC_DATADOGDEMO_ENABLED)
ARG DATADOG_DEMO=true
ENV PETCLINIC_DATADOGDEMO_ENABLED=${DATADOG_DEMO}
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
