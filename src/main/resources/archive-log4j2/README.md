# Archive Log4j2 Configuration

Ce répertoire contient les anciens fichiers de configuration Log4j2 pour référence.

## Fichiers archivés

- `log4j2.xml` - Configuration Log4j2 avec JsonLayout
- `EcsLayout.json` - Template JSON personnalisé pour Log4j2

## Raison de la migration

Le projet a été migré de Log4j2 vers **Logback** pour les raisons suivantes :
1. Logback est le framework de logging par défaut de Spring Boot
2. Meilleure intégration native avec Spring Boot
3. Configuration plus simple avec `logback-spring.xml`
4. Support JSON natif avec `logstash-logback-encoder`

## Migration vers Logback

La nouvelle configuration se trouve dans :
- `src/main/resources/logback-spring.xml`

Les logs JSON avec corrélation trace/log sont conservés et fonctionnent de la même manière.

## Date de migration

Janvier 2026

## Restauration (si nécessaire)

Pour revenir à Log4j2 :
1. Restaurer ces fichiers dans `src/main/resources/`
2. Modifier le `pom.xml` pour réactiver Log4j2 (voir commits git)
3. Supprimer `logback-spring.xml`

