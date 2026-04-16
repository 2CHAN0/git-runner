# Self-Hosted GitHub Actions Runner 구성 가이드

## 배경

GitHub Actions의 hosted runner는 사용 시간에 따라 비용이 발생한다. 특히 macOS runner는 Linux 대비 10배 비싸고($0.08/분), 무료 한도(2,000~3,000분/월)는 CI가 활발한 프로젝트에서 금방 소진된다.

이 구성은 **유휴 맥북을 self-hosted runner로 활용**하여 CI/CD 비용을 $0으로 줄이면서, 맥북이 꺼져 있을 때는 GitHub hosted runner로 자동 fallback하는 구조를 만든다.

---

## 아키텍처

```
개발 머신 (맥북 B)                    유휴 머신 (맥북 A)
┌──────────────────┐                ┌──────────────────────────┐
│  코드 작성         │                │  GitHub Actions Runner    │
│  git push / PR    │                │  (백그라운드 서비스 상주)    │
└────────┬─────────┘                │                          │
         │                          │  - npm ci                │
         ▼                          │  - vitest (테스트)        │
┌──────────────────┐                │  - tsc (빌드 체크)        │
│  GitHub           │───job 전달────►│  - Docker Postgres       │
│                   │                │    (통합 테스트)           │
│                   │◄──결과 보고────│                          │
└──────────────────┘                └──────────────────────────┘
         │
         │ (맥북 A 오프라인 시)
         ▼
┌──────────────────┐
│  GitHub Hosted    │
│  Runner (fallback)│
│  ubuntu-latest    │
└──────────────────┘
```

---

## CI 파이프라인 설계 원칙

### Self-hosted (맥북 1대): 단일 job

Runner가 1대이면 여러 job으로 나눠도 **순차 실행**된다. 각 job마다 checkout, cache restore, node setup 등의 오버헤드(~15초)가 발생하므로, 하나의 job으로 합쳐서 오버헤드를 1회로 줄인다.

```
check-runner (2s) → ci-self-hosted: install → test → build → integration (45s)
총 ~47초
```

### Hosted fallback (GitHub 머신 여러 대): 병렬 구조

GitHub hosted runner는 job마다 별도 머신이 배정되므로, 쪼개서 병렬 실행하는 것이 빠르다.

```
check-runner → install → test-shard 1/2 ─┐
                       → test-shard 2/2 ─┤ 병렬
                       → build ──────────┤
                       → integration ────┘
```

### Runner 감지 방식

워크플로우 첫 단계에서 GitHub API로 self-hosted runner의 온라인 상태를 확인하고, 결과에 따라 분기한다. 이 API 호출에는 `repo` 스코프의 PAT가 필요하며, repo secret(`RUNNER_TOKEN`)으로 저장한다.

```yaml
runners=$(gh api repos/$REPO/actions/runners \
  --jq '[.runners[] | select(.status=="online")] | length')
```

### Integration 테스트 분기

| 환경 | Postgres 실행 방식 |
|------|-------------------|
| Self-hosted (macOS) | `docker compose up` (GitHub `services`는 macOS에서 미지원) |
| Hosted (ubuntu) | `services: postgres` (GitHub Actions 네이티브 지원) |

---

## 역할별 설정 절차

설정은 **Admin(리포 관리자)**과 **맥북 A(빌드 머신)** 두 역할로 나뉜다. Admin은 GitHub 웹/CLI에서 초기 설정을 하고, 맥북 A는 runner만 설치하면 된다. 이후 맥북 A에는 GitHub 로그인이 필요 없다.

```
Admin (1회성)                        맥북 A (빌드 머신)
┌─────────────────────┐             ┌─────────────────────┐
│ 1. PAT 생성          │             │                     │
│ 2. RUNNER_TOKEN 등록  │             │ 4. Runner 다운로드    │
│ 3. 등록 토큰 발급     │──토큰 전달──►│ 5. Runner 등록       │
│ 6. ci.yml 교체       │             │ 7. 서비스 등록/시작    │
└─────────────────────┘             └─────────────────────┘
       GitHub 웹/CLI                    맥북 A 터미널
```

---

### Admin이 할 일 (GitHub 웹 또는 CLI)

> 리포에 admin 권한이 있는 사람이 수행한다. 총 3가지를 해야 하며, 모두 1회성이다.

#### A-1. PAT(Personal Access Token) 생성

GitHub 웹에서 생성한다. 이 토큰은 두 가지 용도로 쓰인다:
- CI 워크플로우에서 runner 온라인 여부 확인 (API 호출)
- 등록 토큰 발급 (CLI에서 1회)

```
GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token

설정:
  - Token name: ci-runner-token
  - Expiration: 90 days (또는 원하는 기간)
  - Repository access: Only select repositories → 대상 리포 선택
  - Permissions:
    - Administration: Read (runner 상태 조회 + 등록 토큰 발급)
    - Contents: Read (워크플로우 실행에 필요)
```

> 생성된 토큰을 복사해둔다. 이 토큰은 A-2, A-3에서 모두 사용한다.

#### A-2. Repo Secret 등록 (`RUNNER_TOKEN`)

CI 워크플로우가 runner 상태를 확인할 때 사용하는 secret이다.

**방법 1: GitHub 웹**
```
대상 리포 → Settings → Secrets and variables → Actions → New repository secret

Name: RUNNER_TOKEN
Secret: (A-1에서 생성한 PAT 붙여넣기)
```

**방법 2: CLI** (admin 계정으로 gh 로그인된 상태)
```bash
gh secret set RUNNER_TOKEN --repo <owner>/<repo>
# 프롬프트에 PAT 붙여넣기
```

#### A-3. Runner 등록 토큰 발급

맥북 A에서 runner를 등록할 때 필요한 1회용 토큰이다. 유효기간 1시간이므로 맥북 A 설정 직전에 발급한다.

**방법 1: GitHub 웹**
```
대상 리포 → Settings → Actions → Runners → New self-hosted runner
→ 페이지에 표시되는 토큰 복사
```

**방법 2: CLI**
```bash
gh api -X POST repos/<owner>/<repo>/actions/runners/registration-token --jq '.token'
# 출력 예: AXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

> 이 토큰을 맥북 A 담당자에게 전달한다. (Slack DM, 구두 등 — 1시간 내 사용 필요)

---

### 맥북 A(빌드 머신)에서 할 일

> GitHub 계정 로그인 불필요. `gh` CLI 설치도 불필요. Admin에게 받은 **등록 토큰**만 있으면 된다.

#### B-0. 사전 준비 (1회)

맥북 A에 아래 소프트웨어가 설치되어 있어야 한다:

```bash
# Node.js 20 (nvm 또는 직접 설치)
node --version   # v20.x.x 확인

# Docker Desktop
docker --version  # Docker version 2x.x.x 확인
docker info       # Docker daemon 실행 중인지 확인
```

#### B-1. Runner 다운로드

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner

# macOS ARM (M1/M2/M3/M4)
curl -sL -o actions-runner.tar.gz \
  https://github.com/actions/runner/releases/download/v2.323.0/actions-runner-osx-arm64-2.323.0.tar.gz

# macOS Intel인 경우:
# curl -sL -o actions-runner.tar.gz \
#   https://github.com/actions/runner/releases/download/v2.323.0/actions-runner-osx-x64-2.323.0.tar.gz

tar xzf actions-runner.tar.gz
```

#### B-2. Runner 등록

Admin에게 받은 등록 토큰을 사용한다.

```bash
./config.sh \
  --url https://github.com/<owner>/<repo> \
  --token <Admin에게_받은_등록_토큰> \
  --name "local-macbook" \
  --labels "self-hosted,macOS,ARM64" \
  --unattended --replace
```

성공 시 출력:
```
√ Connected to GitHub
√ Runner successfully added
√ Settings Saved.
```

> 이 시점에서 `.credentials` 파일이 생성된다. 이후에는 이 파일로 GitHub에 자동 인증되므로 별도 로그인이 필요 없다.

#### B-3. 서비스 등록 (재부팅 시 자동 시작)

```bash
./svc.sh install   # macOS launchd 서비스로 등록
./svc.sh start     # 서비스 시작
```

확인:
```bash
./svc.sh status
# 출력: active (running)
```

> 이제 맥북 A가 켜져 있는 한, runner가 자동으로 GitHub에서 job을 받아서 실행한다.

#### B-4. 슬립 방지 설정 (권장)

맥북이 슬립에 들어가면 runner가 응답하지 못한다.

```
System Settings → Energy Saver (또는 Battery → Options)
  → Prevent automatic sleeping when the display is off: ON
```

또는 CLI로:
```bash
# 영구 슬립 방지 (터미널을 열어둬야 함)
caffeinate -s &
```

---

### Admin이 마지막으로 할 일: ci.yml 교체

맥북 A에서 runner가 온라인인 것을 확인한 후, ci.yml을 교체한다.

```bash
# Runner 온라인 확인
gh api repos/<owner>/<repo>/actions/runners \
  --jq '.runners[] | {name, status}'
# 출력: { "name": "local-macbook", "status": "online" }
```

확인되면 `.github/workflows/ci.yml`을 아래 구조로 교체:

```yaml
jobs:
  # [신규] Runner 상태 확인
  check-runner:
    runs-on: ubuntu-latest
    outputs:
      is_self_hosted: ${{ steps.pick.outputs.is_self_hosted }}
    steps:
      - id: pick
        env:
          GH_TOKEN: ${{ secrets.RUNNER_TOKEN }}
        run: |
          runners=$(gh api repos/${{ github.repository }}/actions/runners \
            --jq '[.runners[] | select(.status=="online")] | length' 2>/dev/null || echo "0")
          if [ "$runners" -gt 0 ]; then
            echo "is_self_hosted=true" >> $GITHUB_OUTPUT
          else
            echo "is_self_hosted=false" >> $GITHUB_OUTPUT
          fi

  # [신규] Self-hosted 단일 job — 오버헤드 최소화
  ci-self-hosted:
    needs: check-runner
    if: needs.check-runner.outputs.is_self_hosted == 'true'
    runs-on: self-hosted
    steps:
      - # clean workspace
      - # checkout
      - # npm ci (캐시)
      - # npm test
      - # npm run build
      - # docker compose up (Postgres)
      - # prisma db push
      - # npm run test:integration
      - # docker compose down
      - # clean workspace

  # [기존 유지] Hosted fallback — 기존 ci.yml 구조 그대로
  install:
    needs: check-runner
    if: needs.check-runner.outputs.is_self_hosted == 'false'
    runs-on: ubuntu-latest
    # ... 기존 install job 그대로

  test-shard:
    if: needs.check-runner.outputs.is_self_hosted == 'false'
    # ... 기존 test-shard 그대로

  build:
    if: needs.check-runner.outputs.is_self_hosted == 'false'
    # ... 기존 build 그대로

  integration:
    if: needs.check-runner.outputs.is_self_hosted == 'false'
    # ... 기존 integration 그대로 (services: postgres 사용)
```

#### auto-merge.yml

변경 불필요. auto-merge는 GitHub API만 사용하므로 runner 유형과 무관하다.

---

## 검증

### 1. Self-hosted 정상 동작 확인

맥북 A runner가 켜진 상태에서 PR을 생성하고 CI 결과를 확인한다.

```bash
# GitHub Actions 탭에서 확인:
# - Check Runner: ✅ "Self-hosted runner online"
# - CI (self-hosted): ✅ 
# - Hosted fallback jobs: ⏭️ 전부 스킵
```

### 2. Fallback 동작 확인

맥북 A runner를 중지한 상태에서 PR을 push하고, hosted fallback이 실행되는지 확인한다.

```bash
# 맥북 A에서:
cd ~/actions-runner && ./svc.sh stop

# 개발 머신에서: PR push → GitHub Actions 탭 확인
# - Check Runner: ✅ "No self-hosted runner — falling back"
# - CI (self-hosted): ⏭️ 스킵
# - install / test-shard / build / integration: ✅ hosted에서 실행

# 확인 후 runner 재시작:
cd ~/actions-runner && ./svc.sh start
```

---

## 검증 결과 (git-runner 테스트 리포)

| 지표 | Before (hosted 병렬) | After (self-hosted 단일) |
|------|---------------------|------------------------|
| 총 소요 시간 | ~3분 20초 | **~47초** |
| job 수 | 7개 | **2개** (check + ci) |
| 오버헤드 | ~75초 (5회 반복) | **~15초** (1회) |
| 비용 | GitHub 분수 차감 | **$0** |
| Fallback | 없음 | GitHub hosted 자동 전환 |

---

## 운영 참고사항

### Runner 관리 명령어 (맥북 A)

```bash
cd ~/actions-runner
./svc.sh status      # 상태 확인
./svc.sh stop        # 중지
./svc.sh start       # 시작
./svc.sh uninstall   # 서비스 해제
```

### 주의사항

| 항목 | 설명 |
|------|------|
| **맥북 슬립** | 뚜껑 닫으면 runner가 응답 못함. 슬립 방지 설정 필수 |
| **동시 실행** | runner 1대 = 1 job 순차 처리. 여러 PR이 동시에 올라오면 큐잉됨 |
| **보안** | private repo에서만 사용. public repo는 외부 PR이 로컬에서 임의 코드 실행 가능 |
| **PAT 만료** | Fine-grained PAT은 만료 기간이 있음. 만료 시 Admin이 재생성 후 RUNNER_TOKEN secret 갱신 |
| **Runner 업데이트** | GitHub이 자동 업데이트함. 수동 개입 불필요 |
| **Docker 리소스** | 워크플로우에서 `docker compose down -v`로 자동 정리. 수동 정리 불필요 |

### 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| CI가 계속 hosted에서 돌아감 | runner 오프라인 | 맥북 A에서 `./svc.sh status` 확인 후 `start` |
| Check Runner에서 403 에러 | RUNNER_TOKEN 만료 | Admin이 PAT 재생성 후 secret 갱신 |
| Integration 테스트 실패 | Docker Desktop 미실행 | 맥북 A에서 Docker Desktop 실행 확인 |
| Job이 queued 상태에서 안 움직임 | runner가 다른 job 처리 중 | 대기 (1대이므로 순차 처리) |
