# Co-update Patterns Library — Generic (Reusable Across Projects)

> **목적**: Next.js + Supabase 스택의 모든 프로젝트에서 재사용 가능한 forward propagation 패턴.
> 마케팅 SaaS, 커머스, B2B 도구 등 도메인 무관하게 적용.
>
> **사용 방법**:
> 1. 새 프로젝트 셋업 시 이 파일을 `<project>/.md/co-update/patterns.md`로 복사
> 2. `<placeholder>` 부분을 프로젝트 경로로 치환 (예: `<admin_users_modal>` → `src/app/(admin)/admin/users/components/UserDetailModal.tsx`)
> 3. 도메인 특화 패턴은 같은 파일에 추가
> 4. `cases.md`는 빈 상태로 시작 → 사례 누적 → 임계값 도달 시 패턴 추출
>
> **버전**: 1.0 (2026-04-15)
> **출처**: marketing-saas-v2의 12개 패턴에서 7개를 generic으로 재작성.

---

## 📐 Placeholder 표기 규칙

| Placeholder | 일반 의미 |
|---|---|
| `<admin_users_page>` | 관리자 회원 목록 페이지 |
| `<admin_users_modal>` | 관리자 회원 상세 모달 |
| `<auth_lib>` | 인증 헬퍼 (`requireAuth`, `requireAdmin`) |
| `<constants>` | 상수 파일 |
| `<types>` | TypeScript 타입 정의 |
| `<validations>` | Zod 스키마 모음 |
| `<api_helpers>` | CRUD 헬퍼 |
| `<async_hook>` | 로딩+토스트 통합 훅 |
| `<sanitize>` | 입력 살균 함수 |
| `<rate_limit>` | rate limit 함수 |
| `<dashboard_layout>` | 대시보드 사이드바 |
| `<flow_guard>` | 진행 단계 가드 컴포넌트 |
| `<migration_dir>` | DB 마이그레이션 디렉토리 |
| `<env_local>` | 로컬 환경변수 파일 |
| `<env_example>` | 환경변수 예시 파일 |
| `<deployment_dashboard>` | 배포 환경 대시보드 (Railway/Vercel 등) |
| `<docs_db_schema>` | DB 스키마 문서 |

---

## 패턴 L1: 새 admin 액션 추가

**카테고리**: `support-burden`, `auth/role`
**트리거**: `<admin_users_dir>/[id]/<액션이름>/route.ts` 신규

| 같이 확인할 곳 | 왜 |
|---|---|
| `<migration_dir>` `action_logs` CHECK constraint | 새 액션 이름 추가 필요 |
| 새 route 내부 | `action_logs` 테이블에 로그 기록 추가 |
| `<admin_users_modal>` | UI 액션 버튼 추가 |
| `<admin_action_logs_page>` (있다면) | 액션 라벨/필터 옵션 추가 |
| 알림 시스템 (`<notifications>`) | 사용자 알림 필요 여부 |

---

## 패턴 L2: 새 사용자 role 추가

**카테고리**: `auth/role`, `db-schema`
**트리거**: `users.role` CHECK constraint 변경 또는 새 role 값 사용

| 같이 확인할 곳 | 왜 |
|---|---|
| `<migration_dir>` 새 migration | `users_role_check` constraint 업데이트 |
| `<auth_lib>` `requireAdmin` / `requireSuperAdmin` | 새 role의 권한 정의 |
| `<constants>` `ROLE_LABELS` | UI 표시 라벨 |
| `<admin_users_modal>` | role 변경 dropdown 옵션 |
| `<admin_users_page>` | 필터 dropdown 옵션 |
| RLS 정책 (있다면) | 새 role의 접근 권한 |

---

## 패턴 L3: 새 사용자 상태(status) 추가

**카테고리**: `auth/role`, `ui-flow`
**트리거**: `users.status` 새 값

| 같이 확인할 곳 | 왜 |
|---|---|
| `<migration_dir>` | `users_status_check` constraint |
| `<constants>` `STATUS_LABELS` | UI 라벨 |
| `<auth_lib>` 로그인 차단 로직 | suspended 패턴 따라 처리 |
| `<admin_users_page>` | 필터 옵션 |
| `<admin_users_modal>` | 상태 변경 dropdown |
| `<middleware>` (있다면) | 라우팅 가드 |

---

## 패턴 L4: 새 DB 테이블 추가

**카테고리**: `db-schema`
**트리거**: `<migration_dir>` 신규 `CREATE TABLE`

| 같이 확인할 곳 | 왜 |
|---|---|
| `<types>` (🔴) | TypeScript 타입 추가 |
| RLS 정책 | 적절한 USING 절 |
| `<api_helpers>` | CRUD 헬퍼 적용 가능 여부 |
| 인덱스 | 자주 조회되는 컬럼 |
| `<docs_db_schema>` | 문서 업데이트 |

---

## 패턴 L5: 새 환경 변수 추가

**카테고리**: `env-config`
**트리거**: 코드에서 `process.env.NEW_VAR` 사용

| 같이 확인할 곳 | 왜 |
|---|---|
| `<env_local>` | 로컬 개발용 값 |
| `<env_example>` (있다면) | 다른 개발자용 placeholder |
| 시크릿 백업 파일 | 안전 보관 |
| `<deployment_dashboard>` | 프로덕션 배포 환경 |
| `next.config.ts` `env` 노출 (필요시) | 클라이언트 사이드 접근 |
| `NEXT_PUBLIC_` 접두사 (클라이언트 변수면) | 클라이언트 번들에 포함 |

---

## 패턴 L6: 새 폼 (form) 추가

**카테고리**: `form`
**트리거**: 사용자 입력을 받는 새 `<form>` 또는 입력 필드 묶음

| 같이 확인할 곳 | 왜 |
|---|---|
| `<validations>` | Zod 스키마 추가 |
| `<async_hook>` 사용 | 로딩/에러/토스트 통합 처리 |
| `<sanitize>` `sanitizeInput()` | 사용자 입력 살균 (XSS/주입 방지) |
| `<auth_client>` `authHeaders()` | API 호출 시 인증 |
| 성공 토스트 / 실패 토스트 | UX 일관성 |
| 제출 버튼 disabled 상태 | 중복 제출 방지 |
| 모바일 터치 영역 44px 이상 | 접근성 |
| 필수값 표시 (`aria-required`) | 접근성 |
| 에러 메시지 위치 (`aria-describedby`) | 접근성 |

---

## 패턴 L7: 새 dashboard 페이지 추가

**카테고리**: `ui-flow`
**트리거**: `<dashboard_dir>/<이름>/page.tsx` 신규

| 같이 확인할 곳 | 왜 |
|---|---|
| `<dashboard_layout>` 사이드바 메뉴 | 네비게이션에 노출 |
| `<flow_guard>` (파이프라인 페이지면) | step 가드 적용 |
| 200줄 제한 (Code Conventions) | 신규 파일은 200줄 이하 |
| `<dashboard_dir>/<이름>/loading.tsx` | 로딩 UI (필요시) |
| `<dashboard_dir>/<이름>/error.tsx` | 에러 바운더리 (필요시) |
| 빈 상태(empty state) UI | 데이터 없을 때 표시 |
| 모바일 레이아웃 | 좁은 화면 대응 |
| `metadata` export | SEO + 탭 제목 |
| 로그인 가드 | `requireAuth` 또는 미들웨어 |

---

## 📚 추가 패턴 (도메인 특화 — 프로젝트에서 추가)

위 7개는 **모든 프로젝트의 기본 안전망**. 각 프로젝트는 자기 도메인 패턴을 추가:

```markdown
## 패턴 P1: 새 [도메인 개념] 추가
**카테고리**: [관련 표준 카테고리]
**트리거**: [구체적 트리거]

| 같이 확인할 곳 | 왜 |
|---|---|
| ... | ... |
```

예시 (marketing-saas-v2의 도메인 특화 5개):
- 새 generate API 추가 (Claude AI 응답 검증, SSE 가드)
- 새 콘텐츠 채널 추가 (CHANNEL_LABEL_MAP, 프롬프트, DB constraint)
- 새 콘텐츠 생성 진입점 (settings_snapshot, channelStatuses)
- 파이프라인 단계 추가/제거 (FlowGuard, step_status, /api/generate/*)
- settings_snapshot JSONB 구조 변경 (types, fallback)

---

## 🔄 학습 루프

1. 사용자가 "이거 빠졌어" 발견 → `case-logger.mjs`로 cases.md에 기록
2. 같은 카테고리 3건 누적 → `pattern-extractor.mjs`가 보강 후보 제안
3. 사용자 검토 → 이 라이브러리 또는 프로젝트 patterns.md에 추가
4. 다른 프로젝트가 이 라이브러리 update 시 자동으로 혜택

---

## 카테고리 분류

`category-taxonomy.md` 참조. 11개 표준 카테고리로 통일하면 프로젝트 간 사례 비교·이전 가능.
