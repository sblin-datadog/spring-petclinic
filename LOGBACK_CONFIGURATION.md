# Configuration Logback pour spring-petclinic

Documentation de la configuration Logback avec logs JSON et corrélation trace/log pour Datadog.

## 📁 Structure des fichiers

```
spring-petclinic/
├── src/main/resources/
│   ├── logback-spring.xml              ← Configuration Logback principale
│   ├── application.properties           ← Configuration Spring Boot
│   └── archive-log4j2/                  ← Archive des fichiers Log4j2
│       ├── log4j2.xml
│       ├── EcsLayout.json
│       └── README.md
├── pom.xml                              ← Dépendances Maven
├── MIGRATION_LOG4J2_TO_LOGBACK.md      ← Documentation de migration
├── LOGBACK_CONFIGURATION.md            ← Ce fichier
└── test-logback-migration.sh           ← Script de test
```

---

## 🎯 Fonctionnalités

### ✅ Logs JSON structurés

Tous les logs sont générés au format JSON avec `logstash-logback-encoder` :

```json
{
  "timestamp": "2026-01-20T15:30:45.123Z",
  "status": "info",
  "ddsource": "java",
  "logger.name": "org.springframework.samples.petclinic.owner.OwnerController",
  "logger.thread_name": "http-nio-8080-exec-1",
  "message": "Displaying owner list",
  "dd.trace_id": "1234567890123456789",
  "dd.span_id": "9876543210987654321",
  "dd.service": "petclinic",
  "dd.version": "1.0.24",
  "dd.env": "dev"
}
```

---

### ✅ Corrélation trace/log automatique

Le MDC (Mapped Diagnostic Context) de Logback capture automatiquement les IDs de trace injectés par le Datadog Java Agent :

```xml
<includeMdcKeyName>dd.trace_id</includeMdcKeyName>
<includeMdcKeyName>dd.span_id</includeMdcKeyName>
<includeMdcKeyName>dd.service</includeMdcKeyName>
<includeMdcKeyName>dd.version</includeMdcKeyName>
<includeMdcKeyName>dd.env</includeMdcKeyName>
```

**Prérequis** : Le Datadog Java Agent doit être activé avec :
```
-javaagent:/dd-java-agent.jar
-Ddd.logs.injection=true
```

---

### ✅ Deux destinations de logs

#### 1. Console (stdout)
- Format : JSON
- Async : Oui (512 queue size)
- Usage : Collecté par Datadog Agent en Kubernetes

#### 2. Fichier rotatif
- Emplacement : `logs/petclinic.log`
- Rotation : Quotidienne + 10MB max
- Rétention : 10 jours
- Compression : Gzip
- Async : Oui

---

### ✅ Support des profils Spring

```xml
<springProfile name="dev">
    <!-- Development: verbose logging -->
    <logger name="org.springframework.samples.petclinic" level="DEBUG"/>
</springProfile>

<springProfile name="prod">
    <!-- Production: less verbose -->
    <logger name="org.springframework" level="WARN"/>
</springProfile>
```

**Activation** :
```bash
# Local
./mvnw spring-boot:run -Dspring.profiles.active=dev

# Kubernetes
env:
  - name: SPRING_PROFILES_ACTIVE
    value: "prod"
```

---

## 🔧 Configuration détaillée

### Champs JSON mappés

| Champ Logback | Champ JSON output | Description |
|---------------|-------------------|-------------|
| `timestamp` | `timestamp` | ISO8601 en UTC |
| `level` | `status` | info, warn, error, etc. |
| `logger` | `logger.name` | Nom du logger Java |
| `thread` | `logger.thread_name` | Nom du thread |
| `message` | `message` | Message du log |
| Custom | `ddsource` | Toujours "java" |
| MDC | `dd.trace_id` | ID de trace Datadog |
| MDC | `dd.span_id` | ID de span Datadog |
| MDC | `dd.service` | Nom du service |
| MDC | `dd.version` | Version |
| MDC | `dd.env` | Environnement |

---

### Niveaux de log configurés

```xml
<!-- Application -->
<logger name="org.springframework.samples.petclinic" level="INFO"/>

<!-- Spring Framework -->
<logger name="org.springframework" level="WARN"/>

<!-- Hibernate -->
<logger name="org.hibernate" level="WARN"/>

<!-- Root (fallback) -->
<root level="INFO"/>
```

---

## 🚀 Utilisation

### Test local

```bash
cd /Users/samuel.blin/Documents/Github/sblin-datadog/spring-petclinic

# Avec logs de debug
export SPRING_PROFILES_ACTIVE=dev
./mvnw spring-boot:run

# Logs visibles dans la console en JSON
```

### Build Docker

```bash
# Build
docker build -t samuelblin/petclinic:1.0.24 .

# Test local
docker run -p 8080:8080 \
  -e DD_SERVICE=petclinic \
  -e DD_VERSION=1.0.24 \
  -e DD_ENV=dev \
  samuelblin/petclinic:1.0.24

# Push
docker push samuelblin/petclinic:1.0.24
```

### Déploiement Kubernetes

```bash
# Mettre à jour springpetclinic.yaml avec la nouvelle image
# image: samuelblin/petclinic:1.0.24

kubectl apply -f springpetclinic.yaml -n petclinic
kubectl rollout restart deployment/petclinic -n petclinic

# Vérifier les logs JSON
kubectl logs -f deployment/petclinic -n petclinic
```

---

## 📊 Vérification dans Datadog

### 1. Logs structurés

Requête Datadog :
```
source:java service:petclinic
```

Vérifiez :
- ✅ Logs en JSON
- ✅ Champ `ddsource: java`
- ✅ Champs `dd.trace_id` et `dd.span_id` présents

### 2. Corrélation log/trace

1. **APM > Traces**
2. Trouvez une trace de `petclinic`
3. Cliquez sur la trace
4. Onglet **"Logs"**
5. ✅ Tous les logs avec le même `trace_id` apparaissent

### 3. Filtres utiles

```
# Tous les logs Java
source:java

# Logs du service petclinic
source:java service:petclinic

# Erreurs uniquement
source:java service:petclinic status:error

# Logs avec trace
source:java service:petclinic @dd.trace_id:*

# Logs d'un endpoint spécifique
source:java service:petclinic @logger.name:*OwnerController*
```

---

## 🔍 Debugging

### Les logs ne sont pas en JSON

**Vérification** :
```bash
kubectl logs deployment/petclinic -n petclinic | head -1
```

Si logs en texte :
1. Vérifier que `logback-spring.xml` existe dans l'image
2. Vérifier les dépendances Maven : `./mvnw dependency:tree | grep logstash`
3. Rebuild l'image Docker

---

### Pas de trace_id dans les logs

**Cause** : Datadog Java Agent pas configuré ou logs.injection désactivé

**Solution** :

1. **Vérifier l'agent Datadog** (Kubernetes avec admission controller) :
```yaml
metadata:
  annotations:
    admission.datadoghq.com/java-lib.version: "latest"
```

2. **Ou injection manuelle du javaagent** :
```dockerfile
# Dockerfile
ADD https://dtdg.co/latest-java-tracer dd-java-agent.jar
```

```yaml
# Kubernetes
env:
  - name: JAVA_TOOL_OPTIONS
    value: "-javaagent:/dd-java-agent.jar -Ddd.logs.injection=true"
```

3. **Vérifier dans les logs de démarrage** :
```
[dd.trace] Datadog Java Agent started
[dd.trace] dd.logs.injection: true
```

---

### Logs trop verbeux ou pas assez

**Modifier le niveau** dans `logback-spring.xml` :

```xml
<!-- Plus de logs -->
<logger name="org.springframework.samples.petclinic" level="DEBUG"/>

<!-- Moins de logs -->
<logger name="org.springframework.samples.petclinic" level="WARN"/>
```

Ou via `application.properties` :
```properties
logging.level.org.springframework.samples.petclinic=DEBUG
```

Ou via variable d'environnement :
```bash
export LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_SAMPLES_PETCLINIC=DEBUG
```

---

## 🎨 Personnalisation

### Ajouter un champ personnalisé

```xml
<encoder class="net.logstash.logback.encoder.LogstashEncoder">
    <customFields>{"ddsource":"java","app":"petclinic","datacenter":"us-east-1"}</customFields>
</encoder>
```

### Désactiver pretty-print (production)

Retirer ou commenter :
```xml
<!-- Retirer pour production -->
<!--
<jsonGeneratorDecorator class="net.logstash.logback.decorate.CompositeJsonGeneratorDecorator">
    <decorator class="net.logstash.logback.decorate.PrettyPrintingJsonGeneratorDecorator"/>
</jsonGeneratorDecorator>
-->
```

### Ajouter un nouveau logger

```xml
<logger name="com.mycompany.mypackage" level="DEBUG" additivity="false">
    <appender-ref ref="ASYNC_CONSOLE"/>
    <appender-ref ref="ASYNC_FILE"/>
</logger>
```

---

## 📚 Ressources

- [Logback Documentation](https://logback.qos.ch/documentation.html)
- [Logstash Logback Encoder](https://github.com/logfellow/logstash-logback-encoder)
- [Spring Boot Logging](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.logging)
- [Datadog Java Logging](https://docs.datadoghq.com/logs/log_collection/java/)
- [Datadog Log Correlation](https://docs.datadoghq.com/tracing/other_telemetry/connect_logs_and_traces/java/)

---

## ✅ Checklist de configuration

- [x] Logback configuré dans `logback-spring.xml`
- [x] `logstash-logback-encoder` ajouté au `pom.xml`
- [x] Logs JSON activés
- [x] Corrélation trace/log configurée (MDC)
- [x] Champs Datadog (ddsource, dd.trace_id, dd.span_id)
- [x] Appenders asynchrones pour performance
- [x] Rotation des fichiers de log
- [x] Support des profils Spring (dev/prod)
- [ ] Tester localement
- [ ] Vérifier dans Datadog
- [ ] Déployer en production

---

**Configuration complète et opérationnelle !** 🎉

