#!/bin/bash
# Pre-install environment check for ADK MCP servers.
# Run before `claude plugin install` to surface missing env vars early.

REQUIRED_VARS=("GITHUB_TOKEN" "DATABASE_URL_READONLY")
OPTIONAL_VARS=("OPENAI_API_KEY" "MILVUS_ADDRESS")

echo "🔍 ADK MCP 환경 변수 확인 중..."
echo ""

MISSING=0

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "❌ 필수: $var — 미설정 (GitHub/Postgres MCP 비활성화됨)"
    MISSING=$((MISSING + 1))
  else
    echo "✅ 필수: $var"
  fi
done

for var in "${OPTIONAL_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "⚠️  선택: $var — 미설정 (해당 MCP 비활성화됨)"
  else
    echo "✅ 선택: $var"
  fi
done

echo ""
if [ $MISSING -gt 0 ]; then
  echo "🔴 필수 변수 ${MISSING}개 누락 — MCP 일부 비활성화 상태로 설치됩니다."
  echo "   설정 후 재실행: export GITHUB_TOKEN=xxx && bash scripts/check-env.sh"
  exit 1
else
  echo "🟢 필수 변수 모두 설정됨 — 설치 진행 가능"
  exit 0
fi
