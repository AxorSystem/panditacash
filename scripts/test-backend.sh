#!/usr/bin/env bash
# Test E2E de todos los endpoints del backend PanditaCash
# Uso: ./test-backend.sh
# Reporta: cada endpoint como PASS/FAIL con el shape del response.

set -u
BASE="${BASE:-https://api-panditacash.5-78-222-255.sslip.io}"
MAMA_TEL="${MAMA_TEL:-5215500000000}"
MAMA_PIN="${MAMA_PIN:-1234}"

# Colores
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

pass=0
fail=0
total=0

check() {
  local name="$1"
  local body="$2"
  local status="$3"
  local expected="$4"

  total=$((total + 1))
  if [ "$status" = "$expected" ]; then
    pass=$((pass + 1))
    printf "${GREEN}✓${RESET} %-60s %s\n" "$name" "$status"
    if [ -n "${VERBOSE:-}" ]; then
      echo "$body" | head -c 200
      echo ""
    fi
  else
    fail=$((fail + 1))
    printf "${RED}✗${RESET} %-60s got %s, expected %s\n" "$name" "$status" "$expected"
    echo "  Body: $(echo "$body" | head -c 300)"
  fi
}

req() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local auth="${4:-}"
  local extra_headers=()
  [ -n "$auth" ] && extra_headers+=(-H "Authorization: Bearer $auth")

  if [ -z "$data" ]; then
    curl -sk -w "\n%{http_code}" --max-time 20 -X "$method" "$BASE$path" "${extra_headers[@]}" 2>&1
  else
    curl -sk -w "\n%{http_code}" --max-time 20 -X "$method" "$BASE$path" \
      -H "Content-Type: application/json" \
      "${extra_headers[@]}" \
      -d "$data" 2>&1
  fi
}

parse() {
  # separa body y status del output de req()
  local response="$1"
  # último line = status, resto = body
  local status
  status=$(echo "$response" | tail -n 1)
  local body
  body=$(echo "$response" | sed '$d')
  echo "$body"
  echo "|||STATUS|||$status"
}

test_endpoint() {
  local name="$1"
  local expected_status="$2"
  local method="$3"
  local path="$4"
  local data="${5:-}"
  local auth="${6:-}"

  local result
  result=$(req "$method" "$path" "$data" "$auth")
  local body
  body=$(echo "$result" | sed '$d')
  local status
  status=$(echo "$result" | tail -n 1)

  check "$name" "$body" "$status" "$expected_status"
  # Retorna el body para uso posterior
  echo "$body" > /tmp/last_response.txt
}

echo -e "${CYAN}==============================================${RESET}"
echo -e "${CYAN}  PanditaCash Backend E2E Tests${RESET}"
echo -e "${CYAN}==============================================${RESET}"
echo "  BASE: $BASE"
echo ""

# ---------- Health ----------
echo -e "\n${CYAN}📊 Health${RESET}"
test_endpoint "GET /api/health" 200 GET "/api/health"
test_endpoint "GET /api/health/db" 200 GET "/api/health/db"

# ---------- Auth ----------
echo -e "\n${CYAN}🔐 Auth${RESET}"
test_endpoint "POST /api/auth/mama/login (bad PIN)" 401 POST "/api/auth/mama/login" \
  '{"telefono":"'"$MAMA_TEL"'","pin":"wrong"}'
test_endpoint "POST /api/auth/mama/login (OK)" 200 POST "/api/auth/mama/login" \
  '{"telefono":"'"$MAMA_TEL"'","pin":"'"$MAMA_PIN"'"}'

TOKEN=$(cat /tmp/last_response.txt | grep -o '"token":"[^"]*"' | sed 's/"token":"//;s/"$//')
if [ -z "$TOKEN" ]; then
  echo -e "${RED}✗ No pude obtener el token de mama. Aborto.${RESET}"
  exit 1
fi
echo -e "${YELLOW}  Token: ${TOKEN:0:20}...${RESET}"

# ---------- Prestamos ----------
echo -e "\n${CYAN}💰 Préstamos${RESET}"
test_endpoint "GET /api/prestamos/dashboard" 200 GET "/api/prestamos/dashboard" "" "$TOKEN"
# verificar shape
DASH=$(cat /tmp/last_response.txt)
if echo "$DASH" | grep -q '"stats"' && echo "$DASH" | grep -q '"prestado_activo"'; then
  echo -e "  ${GREEN}shape stats.prestado_activo ✓${RESET}"
else
  echo -e "  ${RED}shape stats faltante o mal${RESET}"
fi

test_endpoint "POST /api/prestamos/simular" 200 POST "/api/prestamos/simular" \
  '{"principal":5000,"tasa_mensual":0.10,"plazo_meses":3,"frecuencia":"mensual"}' "$TOKEN"
SIM=$(cat /tmp/last_response.txt)
if echo "$SIM" | grep -q '"interes_mensual"' && echo "$SIM" | grep -q '"ganancia_total"'; then
  echo -e "  ${GREEN}shape simular ✓${RESET}"
else
  echo -e "  ${RED}shape simular mal (esperado: interes_mensual, ganancia_total)${RESET}"
fi

test_endpoint "GET /api/prestamos/lookup?telefono=527341682051" 200 GET \
  "/api/prestamos/lookup?telefono=527341682051" "" "$TOKEN"

test_endpoint "GET /api/prestamos/1" 200 GET "/api/prestamos/1" "" "$TOKEN"

test_endpoint "GET /api/prestamos/999999 (no existe)" 404 GET "/api/prestamos/999999" "" "$TOKEN"

# ---------- Clientes ----------
echo -e "\n${CYAN}👥 Clientes${RESET}"
test_endpoint "GET /api/clientes" 200 GET "/api/clientes" "" "$TOKEN"
CLIS=$(cat /tmp/last_response.txt)
if echo "$CLIS" | grep -q '"nombre"' && echo "$CLIS" | grep -q '"telefono"'; then
  echo -e "  ${GREEN}shape clientes ✓${RESET}"
else
  echo -e "  ${RED}shape clientes mal${RESET}"
fi

test_endpoint "GET /api/clientes/2" 200 GET "/api/clientes/2" "" "$TOKEN"
DET=$(cat /tmp/last_response.txt)
if echo "$DET" | grep -q '"cliente"' && echo "$DET" | grep -q '"prestamos"' && echo "$DET" | grep -q '"score"'; then
  echo -e "  ${GREEN}shape detalle: cliente, prestamos, score ✓${RESET}"
else
  echo -e "  ${RED}shape detalle mal${RESET}"
fi

test_endpoint "GET /api/clientes/2/score" 200 GET "/api/clientes/2/score" "" "$TOKEN"

# ---------- Movimientos ----------
echo -e "\n${CYAN}📅 Movimientos${RESET}"
test_endpoint "GET /api/movimientos" 200 GET "/api/movimientos" "" "$TOKEN"
MOV=$(cat /tmp/last_response.txt)
if echo "$MOV" | grep -q '"stats"' && echo "$MOV" | grep -q '"movimientos"'; then
  echo -e "  ${GREEN}shape movimientos ✓${RESET}"
else
  echo -e "  ${RED}shape movimientos mal${RESET}"
fi

# ---------- Analytics ----------
echo -e "\n${CYAN}📊 Analytics${RESET}"
test_endpoint "GET /api/analytics" 200 GET "/api/analytics" "" "$TOKEN"
ANA=$(cat /tmp/last_response.txt)
if echo "$ANA" | grep -q '"totales"'; then
  echo -e "  ${GREEN}shape totales ✓${RESET}"
else
  echo -e "  ${YELLOW}shape totales — verificar${RESET}"
fi

# ---------- KYC (admin) ----------
echo -e "\n${CYAN}📋 KYC (admin)${RESET}"
test_endpoint "GET /api/kyc/pendientes" 200 GET "/api/kyc/pendientes" "" "$TOKEN"
test_endpoint "GET /api/kyc/cliente/2" 200 GET "/api/kyc/cliente/2" "" "$TOKEN"

# ---------- Solicitudes ----------
echo -e "\n${CYAN}📩 Solicitudes${RESET}"
test_endpoint "GET /api/solicitudes/mias (como admin)" 200 GET "/api/solicitudes/mias" "" "$TOKEN"

# ---------- Auth cliente (parcial) ----------
echo -e "\n${CYAN}🔑 Auth cliente${RESET}"
test_endpoint "POST /api/auth/cliente/request-otp" 200 POST "/api/auth/cliente/request-otp" \
  '{"telefono":"5551234567","nombre":"Test User"}'

# ---------- Auth failures ----------
echo -e "\n${CYAN}🚫 Auth failures${RESET}"
test_endpoint "GET /api/prestamos/dashboard (sin token)" 401 GET "/api/prestamos/dashboard"
test_endpoint "GET /api/clientes (token inválido)" 401 GET "/api/clientes" "" "invalid_token"

# ---------- Summary ----------
echo ""
echo -e "${CYAN}==============================================${RESET}"
if [ "$fail" -eq 0 ]; then
  echo -e "${GREEN}✓ TODOS los tests pasaron ($pass/$total)${RESET}"
else
  echo -e "${RED}✗ $fail tests fallaron${RESET} (pasaron: $pass/$total)"
fi
echo -e "${CYAN}==============================================${RESET}"

exit $fail
