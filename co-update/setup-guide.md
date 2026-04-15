# Co-update Map Setup Guide — 새 프로젝트 적용

> ADK 플러그인의 학습형 Co-update Map을 새 프로젝트에 적용하는 5분 가이드.

---

## 전제 조건

- ADK 플러그인 설치됨 (`claude plugin install adk-pipeline@adk-marketplace`)
- 프로젝트 루트에 `CLAUDE.md` 존재
- Next.js + Supabase 스택 (다른 스택도 가능, 단 패턴 라이브러리 보정 필요)

---

## Step 1: 디렉토리 + 파일 생성 (1분)

```bash
cd /path/to/your-project
mkdir -p .md/co-update

# patterns.md — 7개 generic 패턴 복사
cp "F:/marketing -app/agent-dev-kit/co-update/patterns-library.md" \
   .md/co-update/patterns.md

# cases.md — 빈 템플릿
cat > .md/co-update/cases.md <<'EOF'
# Co-update Cases — 학습용 사례 로그

> case-logger.mjs로 자동 누적. 프로젝트 시작 시점엔 비어있음.
> 형식은 agent-dev-kit/co-update/setup-guide.md 참조.

---

## 📊 카테고리별 빈도

```
(자동 갱신됨)
```
EOF
```

---

## Step 2: patterns.md placeholder 치환 (3분)

`patterns.md`를 열어서 `<placeholder>`를 프로젝트 경로로 치환.

**예시 — 일반적인 Next.js + Supabase 프로젝트**:

| Placeholder | 치환 예시 |
|---|---|
| `<admin_users_page>` | `src/app/(admin)/admin/users/page.tsx` |
| `<admin_users_modal>` | `src/app/(admin)/admin/users/components/UserDetailModal.tsx` |
| `<admin_users_dir>` | `src/app/api/admin/users` |
| `<admin_action_logs_page>` | `src/app/(admin)/admin/action-logs/page.tsx` |
| `<auth_lib>` | `src/lib/auth.ts` |
| `<auth_client>` | `src/lib/auth-client.ts` |
| `<constants>` | `src/lib/constants.ts` |
| `<types>` | `src/types/index.ts` |
| `<validations>` | `src/lib/validations.ts` |
| `<api_helpers>` | `src/lib/api-helpers.ts` |
| `<async_hook>` | `src/hooks/useAsyncAction.ts` |
| `<sanitize>` | `src/lib/sanitize.ts` |
| `<rate_limit>` | `src/lib/rate-limit.ts` |
| `<dashboard_layout>` | `src/app/(dashboard)/layout.tsx` |
| `<dashboard_dir>` | `src/app/(dashboard)` |
| `<flow_guard>` | `src/components/FlowGuard.tsx` |
| `<middleware>` | `src/middleware.ts` |
| `<migration_dir>` | `supabase/migrations/` |
| `<env_local>` | `.env.local` |
| `<env_example>` | `.env.example` |
| `<deployment_dashboard>` | Railway dashboard / Vercel dashboard |
| `<docs_db_schema>` | `.md/설계문서/DB스키마.md` |
| `<notifications>` | `src/lib/notifications.ts` |

**찾기·치환 명령** (Linux/Mac/Git Bash):
```bash
sed -i 's|<auth_lib>|src/lib/auth.ts|g' .md/co-update/patterns.md
sed -i 's|<types>|src/types/index.ts|g' .md/co-update/patterns.md
# ... 나머지도 동일
```

또는 에디터에서 일괄 치환.

---

## Step 3: CLAUDE.md에 안내 추가 (1분)

CLAUDE.md 어딘가에 다음 섹션 추가:

```markdown
## 🔄 Co-update Map (전방 영향 검증 — 학습형)

### 두 파일로 분리됨
- **`.md/co-update/patterns.md`** — 일반 규칙 7개 (이 라이브러리 기반)
- **`.md/co-update/cases.md`** — 구체 사례 누적

### 사용 방법
1. 사용자가 새 기능 요청 → `@designer` 호출
2. designer가 `patterns.md`에서 매칭 검색 (여러 패턴 동시 매칭 가능)
3. designer가 `cases.md`에서 유사 사례 N건 검색
4. 매칭된 항목 + 사례를 spec 보고서에 포함

### 학습 루프
1. 사용자가 "이거 또 빠졌어" → `case-logger.mjs` 자동 호출
2. 같은 카테고리 3건 누적 → `pattern-extractor.mjs`가 보강 제안
3. 사용자 검토 → patterns.md 수동 업데이트
```

---

## Step 4: doctor.sh로 검증

```bash
bash "F:/marketing -app/agent-dev-kit/scripts/doctor.sh"
```

다음 항목이 ✓로 표시되어야 함:
```
✓ .md/co-update/patterns.md exists
✓ .md/co-update/cases.md exists
```

---

## Step 5: 첫 사용

새 기능 요청 시:
```
@designer "회원 계정 비활성화 기능 추가"
```

designer가 자동으로:
- `patterns.md`에서 패턴 L1(admin 액션) + L3(상태) + L6(폼) 매칭
- `cases.md`에서 비슷한 사례 검색 (처음엔 없을 것)
- 7개 안전망 항목을 spec 보고서에 자동 포함

---

## 도메인 특화 패턴 추가

이 라이브러리의 7개 외에 프로젝트 도메인 패턴을 직접 추가:

```markdown
## 패턴 P1: <도메인 개념> 추가

**카테고리**: <표준 카테고리 from category-taxonomy.md>
**트리거**: <구체적 트리거>

| 같이 확인할 곳 | 왜 |
|---|---|
| ... | ... |
```

예: marketing-saas-v2는 12개 패턴 중 5개가 도메인 특화 (Claude AI generate API, 콘텐츠 채널 등). 이건 그 프로젝트에만 머무름.

---

## 사례 로깅 사용법

```bash
# 사용자가 "이거 빠졌어" 발견했을 때
node "F:/marketing -app/agent-dev-kit/scripts/case-logger.mjs" \
  "어떤 페이지에서 어떤 게 빠졌는지 한 줄" \
  --pattern=L1 \
  --commit=$(git rev-parse HEAD) \
  --category=auth/role \
  --trigger="새 admin 액션 추가" \
  --found-via="사용자 직접 발견" \
  --prevention="패턴 L1에 항목 추가"
```

cases.md에 자동 append + 카테고리 빈도 갱신 + 임계값 알림.

---

## 임계값 도달 시 (3건+ 누적)

```bash
node "F:/marketing -app/agent-dev-kit/scripts/pattern-extractor.mjs"
```

→ 패턴 보강 후보 마크다운 리포트 출력.
→ 사용자가 검토 → patterns.md 수동 편집.

---

## 다른 프로젝트와 사례 공유 (미래)

같은 표준 카테고리(`category-taxonomy.md`)를 사용하면 미래에 여러 프로젝트의 사례를 모아 글로벌 패턴 추출이 가능. 지금은 프로젝트 단위만 지원.

---

## FAQ

**Q. 패턴이 너무 많아지면?**
A. 자주 매칭되는 것만 남기고 나머지는 archived/ 폴더로 이동.

**Q. cases.md가 너무 커지면?**
A. 분기별로 archived/cases-2026-Q2.md 같이 분할.

**Q. 다른 사람도 같이 쓰려면?**
A. patterns.md + cases.md를 git에 커밋. 팀원들이 같이 누적.

**Q. ADK 없이 이 시스템만 쓸 수 있나?**
A. patterns.md + cases.md는 plain markdown이라 ADK 없이도 사람이 읽고 활용 가능. 단 designer 자동 매칭은 안 됨.
