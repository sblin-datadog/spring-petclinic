FROM eclipse-temurin:17-jdk-jammy
WORKDIR /app
# Install netcat so we can send UDP packets for DogStatsD debugging
RUN apt-get update && apt-get install -y netcat && rm -rf /var/lib/apt/lists/*
COPY .mvn/ .mvn 
COPY mvnw pom.xml ./
RUN ./mvnw dependency:resolve
COPY src ./src
CMD ["./mvnw", "spring-boot:run"]