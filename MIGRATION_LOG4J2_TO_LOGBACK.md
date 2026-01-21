# Migration Log4j2 → Logback

Documentation de la migration du framework de logging de **Log4j2** vers **Logback** pour le projet spring-petclinic.

## 📅 Date de migration

Janvier 2026

---

## 🎯 Raisons de la migration

1. **Logback est le logging par défaut de Spring Boot**
   - Meilleure intégration native
   - Moins de configuration nécessaire
   - Support natif des profils Spring (`<springProfile>`)

2. **Simplicité de configuration**
   - Logback utilise `logback-spring.xml` (auto-détecté)
   - Pas besoin d'exclusions complexes dans le `pom.xml`

3. **Logstash Encoder mature**
   - `logstash-logback-encoder` est très utilisé et bien maintenu
   - Support JSON natif et complet
   - Excellente intégration avec Datadog

4. **Performance**
   - Appenders asynchrones optimisés
   - Moins de dépendances transitives

---

## 📋 Modifications effectuées

### 1. **Archivage des fichiers Log4j2**

Les anciens fichiers de configuration ont été déplacés vers :
```
src/main/resources/archive-log4j2/
├── log4j2.xml
├── EcsLayout.json
└── README.md
```

✅ **Conservés pour référence** - Peuvent être restaurés si nécessaire

---

### 2. **Modifications du `pom.xml`**

#### ❌ RETIRÉ :

```xml
<!-- Log4j2 Support -->
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-log4j2</artifactId>
</dependency>

<!-- Log4j2 JSON Layout -->
<dependency>
  <groupId>org.apache.logging.log4j</groupId>
  <artifactId>log4j-layout-template-json</artifactId>
</dependency>

<!-- Exclusions de spring-boot-starter-logging -->
<exclusions>
  <exclusion>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-logging</artifactId>
  </exclusion>
</exclusions>
```

#### ✅ AJOUTÉ :

```xml
<!-- Logback JSON encoder for structured logging -->
<dependency>
  <groupId>net.logstash.logback</groupId>
  <artifactId>logstash-logback-encoder</artifactId>
  <version>7.4</version>
</dependency>
```

**Note** : Spring Boot inclut déjà Logback par défaut via `spring-boot-starter-logging`, donc aucune dépendance Logback explicite n'est nécessaire.

---

### 3. **Nouveau fichier de configuration**

**Fichier créé** : `src/main/resources/logback-spring.xml`

#### Caractéristiques principales :

✅ **Logs JSON structurés** avec `LogstashEncoder`

✅ **Corrélation trace/log** via MDC (Mapped Diagnostic Context)
   - `dd.trace_id`
   - `dd.span_id`
   - `dd.service`
   - `dd.version`
   - `dd.env`

✅ **Champs compatibles Datadog** :
   - `timestamp` : Horodatage ISO8601 en UTC
   - `status` : Niveau de log (info, warn, error)
   - `ddsource` : "java" (pour identification dans Datadog)
   - `logger.name` : Nom du logger
   - `logger.thread_name` : Nom du thread
   - `message` : Message du log

✅ **Deux appenders** :
   - Console (stdout) en JSON
   - Fichier avec rotation (logs/petclinic.log)

✅ **Appenders asynchrones** pour performance

✅ **Support des profils Spring** (`dev`, `prod`)

---

### 4. **Modifications de `application.properties`**

#### ❌ RETIRÉ :

```properties
logging.config=classpath:log4j2.xml
```

#### ✅ AJOUTÉ :

```properties
# Logback configuration file (optional, auto-detected by Spring Boot)
# logging.config=classpath:logback-spring.xml
```

**Note** : Spring Boot détecte automatiquement `logback-spring.xml`, donc la ligne est commentée (optionnelle).

---

## 🔄 Comparaison : Log4j2 vs Logback

| Aspect | Log4j2 (avant) | Logback (après) |
|--------|----------------|------------------|
| **Framework** | Apache Log4j2 | Logback (natif Spring Boot) |
| **Configuration** | `log4j2.xml` + `EcsLayout.json` | `logback-spring.xml` uniquement |
| **JSON Encoder** | `log4j-layout-template-json` | `logstash-logback-encoder` |
| **Dépendances** | 2 dépendances + exclusions | 1 dépendance (+ Logback inclus) |
| **Format JSON** | `JsonTemplateLayout` + template custom | `LogstashEncoder` (tout inclus) |
| **Trace correlation** | Via variables d'environnement | Via MDC (plus standard) |
| **Profils Spring** | Non supporté nativement | Support natif `<springProfile>` |
| **Performance** | AsyncAppender manuel | AsyncAppender optimisé |

---

## 📊 Format des logs (avant/après)

Les deux formats produisent des logs JSON similaires pour Datadog :

### Avant (Log4j2) :

```json
{
  "timestamp": "2026-01-20T15:30:45.123Z",
  "status": "info",
  "thread_name": "http-nio-8080-exec-1",
  "logger_name": "org.springframework.samples.petclinic.owner.OwnerController",
  "message": "Processing request for owner list",
  "service": "petclinic",
  "version": "1.0.23",
  "dd.trace_id": "1234567890123456789",
  "dd.span_id": "9876543210987654321"
}
```

### Après (Logback) :

```json
{
  "timestamp": "2026-01-20T15:30:45.123Z",
  "status": "info",
  "ddsource": "java",
  "logger.name": "org.springframework.samples.petclinic.owner.OwnerController",
  "logger.thread_name": "http-nio-8080-exec-1",
  "message": "Processing request for owner list",
  "dd.trace_id": "1234567890123456789",
  "dd.span_id": "9876543210987654321",
  "dd.service": "petclinic",
  "dd.version": "1.0.23",
  "dd.env": "dev"
}
```

✅ **Compatibilité** : Les deux formats sont compatibles avec Datadog et la corrélation log/trace fonctionne de la même manière.

---

## 🚀 Déploiement

### 1. **Rebuild de l'application**

```bash
cd /Users/samuel.blin/Documents/Github/sblin-datadog/spring-petclinic

# Clean build
./mvnw clean package

# Ou avec rebuild Docker
docker build --no-cache -t samuelblin/petclinic:1.0.24 .
docker push samuelblin/petclinic:1.0.24
```

### 2. **Mise à jour du manifest Kubernetes**

Modifier `springpetclinic.yaml` pour utiliser la nouvelle version :

```yaml
image: samuelblin/petclinic:1.0.24  # Nouvelle version
```

### 3. **Déploiement**

```bash
kubectl apply -f springpetclinic.yaml -n petclinic
kubectl rollout restart deployment/petclinic -n petclinic
```

### 4. **Vérification**

```bash
# Vérifier les logs JSON
kubectl logs -f deployment/petclinic -n petclinic | head -5

# Attendu : logs au format JSON avec "ddsource":"java"
```

---

## 🔍 Vérification dans Datadog

### 1. **Logs JSON structurés**

```
source:java service:petclinic
```

Vérifiez que les logs apparaissent avec :
- ✅ Champ `ddsource: java`
- ✅ Champ `status` (info, warn, error)
- ✅ Champs `dd.trace_id` et `dd.span_id`

### 2. **Corrélation log/trace**

1. APM > Traces > Trouvez une trace
2. Onglet "Logs"
3. ✅ Les logs avec le même `trace_id` doivent apparaître

---

## 🐛 Troubleshooting

### Problème 1 : Application ne démarre pas

**Erreur** : `ClassNotFoundException: org.apache.logging.log4j.*`

**Solution** : 
```bash
./mvnw clean package
# Les anciennes classes Log4j2 sont en cache
```

---

### Problème 2 : Logs pas en JSON

**Vérification** :
```bash
kubectl logs deployment/petclinic | head -1
```

Si logs en texte brut :
1. Vérifier que `logback-spring.xml` existe bien
2. Vérifier que `logstash-logback-encoder` est dans le `pom.xml`
3. Rebuild l'application

---

### Problème 3 : Pas de trace_id dans les logs

**Cause** : Le Datadog Java Agent n'injecte pas les IDs dans le MDC

**Solution** : Vérifier que l'agent Datadog Java est activé avec :
```
-javaagent:/path/to/dd-java-agent.jar
-Ddd.logs.injection=true  # ← Important !
```

Dans Kubernetes, vérifier les annotations :
```yaml
annotations:
  admission.datadoghq.com/java-lib.version: "latest"
```

---

## 🔙 Rollback (si nécessaire)

Pour revenir à Log4j2 en cas de problème :

### 1. Restaurer les fichiers

```bash
cd src/main/resources
cp archive-log4j2/log4j2.xml .
cp archive-log4j2/EcsLayout.json .
rm logback-spring.xml
```

### 2. Restaurer le `pom.xml`

```bash
git checkout HEAD~1 pom.xml
```

Ou modifier manuellement pour réactiver Log4j2.

### 3. Restaurer `application.properties`

```properties
logging.config=classpath:log4j2.xml
```

### 4. Rebuild et redéployer

```bash
./mvnw clean package
docker build -t samuelblin/petclinic:1.0.23 .
```

---

## 📚 Ressources

- [Logback Documentation](https://logback.qos.ch/documentation.html)
- [Logstash Logback Encoder](https://github.com/logfellow/logstash-logback-encoder)
- [Spring Boot Logging](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.logging)
- [Datadog Java Logging](https://docs.datadoghq.com/logs/log_collection/java/)
- [Datadog Trace Correlation](https://docs.datadoghq.com/tracing/other_telemetry/connect_logs_and_traces/java/)

---

## ✅ Checklist de migration

- [x] Archiver les fichiers Log4j2 dans `archive-log4j2/`
- [x] Supprimer `log4j2.xml` et `EcsLayout.json` de `src/main/resources/`
- [x] Retirer les dépendances Log4j2 du `pom.xml`
- [x] Retirer les exclusions `spring-boot-starter-logging`
- [x] Ajouter `logstash-logback-encoder` au `pom.xml`
- [x] Créer `logback-spring.xml` avec configuration JSON
- [x] Mettre à jour `application.properties`
- [ ] Rebuild l'application (`mvnw clean package`)
- [ ] Tester localement
- [ ] Vérifier les logs JSON dans la console
- [ ] Vérifier la corrélation trace/log
- [ ] Créer nouvelle image Docker
- [ ] Déployer sur Kubernetes
- [ ] Vérifier dans Datadog : `source:java service:petclinic`

---

## 🎉 Résultat attendu

Après migration :
- ✅ Logs JSON structurés avec `ddsource: java`
- ✅ Corrélation log/trace fonctionnelle
- ✅ Performance identique ou meilleure (async appenders)
- ✅ Configuration plus simple et maintenable
- ✅ Meilleure intégration avec Spring Boot

---

**Migration effectuée avec succès !** 🚀

