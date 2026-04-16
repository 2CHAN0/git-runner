#!/bin/bash
# ─────────────────────────────────────────────
# 맥북 A (빌드 머신) Runner 설정 스크립트
# GitHub 계정 로그인 불필요. Admin에게 받은 토큰만 있으면 됨.
# ─────────────────────────────────────────────
set -euo pipefail

REPO="${1:-}"
TOKEN="${2:-}"
RUNNER_NAME="${3:-local-macbook}"

if [ -z "$REPO" ] || [ -z "$TOKEN" ]; then
  echo "사용법: ./setup-runner.sh <owner/repo> <등록토큰> [runner이름]"
  echo "예시:   ./setup-runner.sh ireneshlee814/creator-docsend AXXXXXXXXXXXX"
  echo "예시:   ./setup-runner.sh ireneshlee814/creator-docsend AXXXXXXXXXXXX my-macbook"
  exit 1
fi

RUNNER_DIR="$HOME/actions-runner"
ARCH=$(uname -m)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Runner 설정: $REPO"
echo " Runner 이름: $RUNNER_NAME"
echo " 설치 경로:   $RUNNER_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. 사전 조건 확인
echo ""
echo "[1/5] 사전 조건 확인..."

CHECKS_PASSED=true

if command -v node &>/dev/null; then
  NODE_VER=$(node --version)
  echo "  ✅ Node.js: $NODE_VER"
else
  echo "  ❌ Node.js가 설치되어 있지 않습니다."
  echo "     brew install node@20  또는  https://nodejs.org 에서 설치하세요."
  CHECKS_PASSED=false
fi

if command -v docker &>/dev/null; then
  DOCKER_VER=$(docker --version)
  echo "  ✅ Docker: $DOCKER_VER"
  if docker info &>/dev/null; then
    echo "  ✅ Docker daemon 실행 중"
  else
    echo "  ❌ Docker Desktop이 실행되지 않고 있습니다. Docker Desktop을 시작하세요."
    CHECKS_PASSED=false
  fi
else
  echo "  ❌ Docker가 설치되어 있지 않습니다."
  echo "     https://www.docker.com/products/docker-desktop 에서 설치하세요."
  CHECKS_PASSED=false
fi

if [ "$CHECKS_PASSED" = false ]; then
  echo ""
  echo "❌ 사전 조건이 충족되지 않았습니다. 위 항목을 먼저 설치하세요."
  exit 1
fi

# 2. Runner 다운로드
echo ""
echo "[2/5] Runner 다운로드..."
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [ -f "./config.sh" ]; then
  echo "  ⚠️  기존 runner가 있습니다. 덮어씁니다."
fi

if [ "$ARCH" = "arm64" ]; then
  RUNNER_URL="https://github.com/actions/runner/releases/download/v2.323.0/actions-runner-osx-arm64-2.323.0.tar.gz"
  echo "  아키텍처: Apple Silicon (ARM64)"
else
  RUNNER_URL="https://github.com/actions/runner/releases/download/v2.323.0/actions-runner-osx-x64-2.323.0.tar.gz"
  echo "  아키텍처: Intel (x64)"
fi

curl -sL -o actions-runner.tar.gz "$RUNNER_URL"
tar xzf actions-runner.tar.gz
rm -f actions-runner.tar.gz
echo "  ✅ 다운로드 완료"

# 3. Runner 등록
echo ""
echo "[3/5] Runner 등록..."
./config.sh \
  --url "https://github.com/$REPO" \
  --token "$TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "self-hosted,macOS,ARM64" \
  --unattended --replace

# 4. 서비스 등록
echo ""
echo "[4/5] 서비스 등록 (launchd)..."
./svc.sh install
./svc.sh start

# 5. 확인
echo ""
echo "[5/5] 상태 확인..."
sleep 2
./svc.sh status

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ✅ Runner 설정 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " Runner가 GitHub에 연결되어 job을 대기하고 있습니다."
echo ""
echo " 관리 명령어:"
echo "   cd $RUNNER_DIR"
echo "   ./svc.sh status    # 상태 확인"
echo "   ./svc.sh stop      # 중지"
echo "   ./svc.sh start     # 시작"
echo "   ./svc.sh uninstall # 서비스 해제"
echo ""
echo " Admin에게 Runner 온라인 확인을 요청하세요."
