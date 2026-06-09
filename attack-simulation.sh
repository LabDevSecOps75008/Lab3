#!/usr/bin/env bash
# Simule ce qu'un attaquant ferait contre cette API.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

BASE="http://localhost:5000"
SEP="=================================================="

echo -e "${BOLD}${CYAN}$SEP${RESET}"
echo -e "${BOLD}${CYAN}  SIMULATION D'ATTAQUE — freemobile-netops-api${RESET}"
echo -e "${BOLD}${CYAN}$SEP${RESET}"
echo ""

if ! curl -sf "$BASE/health" > /dev/null 2>&1; then
    echo "L'application ne répond pas sur $BASE"
    echo "Lancez : docker compose up -d"
    exit 1
fi

# ------------------------------------------------------------------
echo -e "${BOLD}[1/6] SQL INJECTION${RESET}"
echo      "      Extraction de tous les abonnés via une requête malformée."
echo ""
RESULT=$(curl -s -G "$BASE/api/v1/search" --data-urlencode "q=0' OR '1'='1")
COUNT=$(echo "$RESULT" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
if [[ "$COUNT" -gt 1 ]]; then
    echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
    echo -e "  ${RED}⚠  DANGER — $COUNT abonnés extraits${RESET}"
else
    echo -e "  ${GREEN}✓  Protégé${RESET}"
fi
echo ""

# ------------------------------------------------------------------
echo -e "${BOLD}[2/6] XSS RÉFLÉCHI${RESET}"
echo      "      Injection de JavaScript dans la réponse HTML."
echo ""
RESULT=$(curl -s -G "$BASE/api/v1/echo" --data-urlencode 'msg=<script>alert("xss")</script>')
if echo "$RESULT" | grep -q "<script>"; then
    echo -e "  ${RED}⚠  DANGER — payload XSS réfléchi : $RESULT${RESET}"
else
    echo -e "  ${GREEN}✓  Protégé${RESET}"
fi
echo ""

# ------------------------------------------------------------------
echo -e "${BOLD}[3/6] OS COMMAND INJECTION${RESET}"
echo      "      Exécution d'une commande système via le paramètre host."
echo ""
RESULT=$(curl -s -G "$BASE/api/v1/ping" --data-urlencode "host=localhost; cat /etc/passwd" 2>/dev/null || echo "")
if echo "$RESULT" | grep -q "root:"; then
    echo -e "  ${RED}⚠  DANGER — /etc/passwd lisible via command injection${RESET}"
else
    echo -e "  ${GREEN}✓  Protégé${RESET}"
fi
echo ""

# ------------------------------------------------------------------
echo -e "${BOLD}[4/6] ACCÈS ADMIN SANS AUTHENTIFICATION${RESET}"
echo      "      Accès à la liste des comptes administrateurs sans credentials."
echo ""
RESULT=$(curl -s "$BASE/admin/users")
if echo "$RESULT" | grep -q "password"; then
    echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
    echo -e "  ${RED}⚠  DANGER — credentials admin exposés${RESET}"
else
    echo -e "  ${GREEN}✓  Protégé${RESET}"
fi
echo ""

# ------------------------------------------------------------------
echo -e "${BOLD}[5/6] OPEN REDIRECT${RESET}"
echo      "      Redirection vers un site externe malveillant."
echo ""
REDIRECT_URL=$(curl -s -o /dev/null -w "%{redirect_url}" "$BASE/redirect?url=https://evil.com")
if echo "$REDIRECT_URL" | grep -q "evil.com"; then
    echo -e "  ${RED}⚠  DANGER — redirection vers : $REDIRECT_URL${RESET}"
else
    echo -e "  ${GREEN}✓  Protégé${RESET}"
fi
echo ""

# ------------------------------------------------------------------
echo -e "${BOLD}[6/6] DEBUG MODE — Stack trace exposé${RESET}"
echo      "      Informations internes exposées en cas d'erreur serveur."
echo ""
RESULT=$(curl -s "$BASE/crash")
if echo "$RESULT" | grep -qi "Traceback\|Werkzeug\|RuntimeError"; then
    echo -e "  ${RED}⚠  DANGER — stack trace Python exposé${RESET}"
else
    echo -e "  ${GREEN}✓  Protégé${RESET}"
fi
echo ""

# ------------------------------------------------------------------
echo -e "${BOLD}${CYAN}$SEP${RESET}"
echo -e "${BOLD}${CYAN}  FIN DE LA SIMULATION${RESET}"
echo -e "${BOLD}${CYAN}$SEP${RESET}"
echo ""
echo -e "  Prochaine étape : construire la pipeline ZAP dans .github/workflows/security.yml"
echo ""
