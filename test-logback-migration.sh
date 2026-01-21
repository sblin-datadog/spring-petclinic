#!/bin/bash

echo "🧪 Test de la migration Log4j2 → Logback"
echo "=========================================="
echo ""

PROJECT_DIR="/Users/samuel.blin/Documents/Github/sblin-datadog/spring-petclinic"
cd "$PROJECT_DIR" || exit 1

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Vérifier l'archive Log4j2
echo "Test 1: Vérification de l'archive Log4j2"
echo "-------------------------------------------"
if [ -d "src/main/resources/archive-log4j2" ]; then
    echo -e "${GREEN}✅ Répertoire archive-log4j2 existe${NC}"
    
    if [ -f "src/main/resources/archive-log4j2/log4j2.xml" ]; then
        echo -e "${GREEN}✅ log4j2.xml archivé${NC}"
    else
        echo -e "${RED}❌ log4j2.xml manquant dans l'archive${NC}"
    fi
    
    if [ -f "src/main/resources/archive-log4j2/EcsLayout.json" ]; then
        echo -e "${GREEN}✅ EcsLayout.json archivé${NC}"
    else
        echo -e "${RED}❌ EcsLayout.json manquant dans l'archive${NC}"
    fi
else
    echo -e "${RED}❌ Répertoire archive-log4j2 n'existe pas${NC}"
fi
echo ""

# Test 2: Vérifier que les anciens fichiers sont supprimés
echo "Test 2: Vérification de la suppression des fichiers Log4j2"
echo "------------------------------------------------------------"
if [ ! -f "src/main/resources/log4j2.xml" ]; then
    echo -e "${GREEN}✅ log4j2.xml supprimé de resources${NC}"
else
    echo -e "${RED}❌ log4j2.xml existe encore dans resources${NC}"
fi

if [ ! -f "src/main/resources/EcsLayout.json" ]; then
    echo -e "${GREEN}✅ EcsLayout.json supprimé de resources${NC}"
else
    echo -e "${RED}❌ EcsLayout.json existe encore dans resources${NC}"
fi
echo ""

# Test 3: Vérifier la présence de logback-spring.xml
echo "Test 3: Vérification de logback-spring.xml"
echo "--------------------------------------------"
if [ -f "src/main/resources/logback-spring.xml" ]; then
    echo -e "${GREEN}✅ logback-spring.xml créé${NC}"
    
    # Vérifier le contenu
    if grep -q "LogstashEncoder" "src/main/resources/logback-spring.xml"; then
        echo -e "${GREEN}✅ LogstashEncoder configuré${NC}"
    else
        echo -e "${RED}❌ LogstashEncoder non trouvé${NC}"
    fi
    
    if grep -q "dd.trace_id" "src/main/resources/logback-spring.xml"; then
        echo -e "${GREEN}✅ Corrélation trace configurée (dd.trace_id)${NC}"
    else
        echo -e "${RED}❌ dd.trace_id non configuré${NC}"
    fi
    
    if grep -q '"ddsource":"java"' "src/main/resources/logback-spring.xml"; then
        echo -e "${GREEN}✅ Source Datadog configurée (ddsource:java)${NC}"
    else
        echo -e "${RED}❌ ddsource non configuré${NC}"
    fi
else
    echo -e "${RED}❌ logback-spring.xml n'existe pas${NC}"
fi
echo ""

# Test 4: Vérifier le pom.xml
echo "Test 4: Vérification du pom.xml"
echo "---------------------------------"
if grep -q "spring-boot-starter-log4j2" "pom.xml"; then
    echo -e "${RED}❌ Log4j2 encore présent dans pom.xml${NC}"
else
    echo -e "${GREEN}✅ Log4j2 retiré du pom.xml${NC}"
fi

if grep -q "logstash-logback-encoder" "pom.xml"; then
    echo -e "${GREEN}✅ logstash-logback-encoder ajouté${NC}"
else
    echo -e "${RED}❌ logstash-logback-encoder manquant${NC}"
fi

if grep -q "spring-boot-starter-logging" "pom.xml" | grep -q "exclusion"; then
    echo -e "${RED}❌ Exclusions spring-boot-starter-logging encore présentes${NC}"
else
    echo -e "${GREEN}✅ Exclusions spring-boot-starter-logging retirées${NC}"
fi
echo ""

# Test 5: Vérifier application.properties
echo "Test 5: Vérification de application.properties"
echo "------------------------------------------------"
if grep -q "logging.config=classpath:log4j2.xml" "src/main/resources/application.properties"; then
    echo -e "${RED}❌ Référence à log4j2.xml encore présente${NC}"
else
    echo -e "${GREEN}✅ Référence à log4j2.xml retirée${NC}"
fi
echo ""

# Test 6: Essayer de compiler
echo "Test 6: Compilation Maven"
echo "--------------------------"
echo -e "${YELLOW}⏳ Compilation en cours (peut prendre 1-2 minutes)...${NC}"
if ./mvnw clean compile -q > /tmp/maven-compile.log 2>&1; then
    echo -e "${GREEN}✅ Compilation réussie${NC}"
else
    echo -e "${RED}❌ Erreur de compilation${NC}"
    echo "Détails dans /tmp/maven-compile.log"
fi
echo ""

# Test 7: Vérifier la documentation
echo "Test 7: Vérification de la documentation"
echo "------------------------------------------"
if [ -f "MIGRATION_LOG4J2_TO_LOGBACK.md" ]; then
    echo -e "${GREEN}✅ Documentation de migration créée${NC}"
else
    echo -e "${YELLOW}⚠️  Documentation de migration manquante${NC}"
fi
echo ""

# Résumé
echo "=========================================="
echo "🎯 Résumé de la migration"
echo "=========================================="
echo ""
echo "Fichiers archivés:"
echo "  📁 src/main/resources/archive-log4j2/"
echo "     - log4j2.xml"
echo "     - EcsLayout.json"
echo "     - README.md"
echo ""
echo "Nouveaux fichiers:"
echo "  📄 src/main/resources/logback-spring.xml"
echo "  📄 MIGRATION_LOG4J2_TO_LOGBACK.md"
echo ""
echo "Modifications:"
echo "  📝 pom.xml (Log4j2 → Logback)"
echo "  📝 application.properties"
echo ""
echo "Prochaines étapes:"
echo "  1. ./mvnw clean package"
echo "  2. docker build -t samuelblin/petclinic:1.0.24 ."
echo "  3. Tester localement: ./mvnw spring-boot:run"
echo "  4. Vérifier les logs JSON dans la console"
echo "  5. Déployer sur Kubernetes"
echo ""
echo "📚 Documentation complète: MIGRATION_LOG4J2_TO_LOGBACK.md"
echo ""

