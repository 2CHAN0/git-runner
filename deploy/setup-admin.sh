#!/bin/bash
# ─────────────────────────────────────────────
# Admin 설정 스크립트
# 리포에 admin 권한이 있는 사람이 실행
# ─────────────────────────────────────────────
set -euo pipefail

REPO="${1:-}"
if [ -z "$REPO" ]; then
  echo "사용법: ./setup-admin.sh <owner/repo>"
  echo "예시:   ./setup-admin.sh ireneshlee814/creator-docsend"
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Admin 설정: $REPO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. gh 로그인 확인
echo ""
echo "[1/3] GitHub CLI 인증 확인..."
if ! gh auth status &>/dev/null; then
  echo "❌ gh CLI에 로그인되어 있지 않습니다. 'gh auth login'을 먼저 실행하세요."
  exit 1
fi
echo "✅ $(gh auth status 2>&1 | grep 'Logged in')"

# 2. admin 권한 확인
echo ""
echo "[2/3] 리포 권한 확인..."
IS_ADMIN=$(gh api "repos/$REPO" --jq '.permissions.admin' 2>/dev/null || echo "false")
if [ "$IS_ADMIN" != "true" ]; then
  echo "❌ $REPO 에 admin 권한이 없습니다."
  echo "   리포 owner에게 Settings → Collaborators에서 Admin 권한을 요청하세요."
  exit 1
fi
echo "✅ Admin 권한 확인됨"

# 3. RUNNER_TOKEN secret 등록
echo ""
echo "[3/3] RUNNER_TOKEN secret 등록..."
EXISTING=$(gh secret list --repo "$REPO" 2>/dev/null | grep "RUNNER_TOKEN" || true)
if [ -n "$EXISTING" ]; then
  echo "⚠️  RUNNER_TOKEN이 이미 등록되어 있습니다. 덮어쓰시겠습니까? (y/N)"
  read -r CONFIRM
  if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "   건너뜁니다."
  else
    echo "PAT(Personal Access Token)을 입력하세요."
    echo "  필요 권한: Administration:Read, Contents:Read"
    echo "  생성: GitHub → Settings → Developer settings → Fine-grained tokens"
    gh secret set RUNNER_TOKEN --repo "$REPO"
    echo "✅ RUNNER_TOKEN 갱신됨"
  fi
else
  echo "PAT(Personal Access Token)을 입력하세요."
  echo "  필요 권한: Administration:Read, Contents:Read"
  echo "  생성: GitHub → Settings → Developer settings → Fine-grained tokens"
  gh secret set RUNNER_TOKEN --repo "$REPO"
  echo "✅ RUNNER_TOKEN 등록됨"
fi

# 4. Runner 등록 토큰 발급
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Runner 등록 토큰 발급"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
REG_TOKEN=$(gh api -X POST "repos/$REPO/actions/runners/registration-token" --jq '.token')
echo ""
echo "🔑 등록 토큰: $REG_TOKEN"
echo ""
echo "⏰ 유효기간: 1시간"
echo ""
echo "이 토큰을 맥북 A 담당자에게 전달하세요."
echo "맥북 A에서 실행할 명령어:"
echo ""
echo "  ./setup-runner.sh $REPO $REG_TOKEN"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Admin 설정 완료"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "남은 작업:"
echo "  1. 맥북 A에서 setup-runner.sh 실행 (담당자)"
echo "  2. Runner 온라인 확인 후 ci.yml 교체 (Admin)"
echo ""
echo "Runner 온라인 확인:"
echo "  gh api repos/$REPO/actions/runners --jq '.runners[] | {name, status}'"
echo ""
echo "ci.yml 교체:"
echo "  cp deploy/ci.yml .github/workflows/ci.yml"
