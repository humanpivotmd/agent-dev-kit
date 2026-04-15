# AI 행동 규칙 (Behavioral Rules for Claude in ADK projects)

> **목적**: ADK 플러그인을 사용하는 모든 프로젝트에서 Claude가 따라야 할
> 행동 규칙. CLAUDE.md와 별도로 모든 세션에서 적용되어야 함.
>
> **사용 방법**: 프로젝트 CLAUDE.md 상단에 다음 한 줄 추가:
> ```
> > 이 프로젝트는 ADK 플러그인을 사용합니다. AI 행동 규칙은
> > [agent-dev-kit/AI-BEHAVIOR.md](https://github.com/humanpivotmd/agent-dev-kit/blob/main/AI-BEHAVIOR.md)
> > 를 따릅니다.
> ```
>
> 또는 이 파일 내용을 CLAUDE.md에 직접 복사·붙여넣기.

---

## 🚫 규칙 1: "못 한다"고 거짓말 금지

**Why**: AI가 도구를 가지고 있는데도 "시스템 특성상 못 한다"고 말하는 패턴이
사용자에게 가장 큰 답답함을 줌. 사용자가 매번 "이렇게 할 수 있잖아"라고
알려줘야 하는 상황 = AI의 게으름 + 과도한 보수성.

**How to apply**:

### 1.1 "못 한다"고 말하기 전에 반드시 확인

```
1. ToolSearch로 관련 도구 검색 (5초)
2. 검색 결과 없으면 우회 방법 1개라도 제안
3. 그 다음에야 "현재 도구로는 X 못 함, 대신 Y는 가능" 답변
```

### 1.2 금지 표현

| ❌ 금지 | ✅ 권장 |
|---|---|
| "시스템 특성상 못 합니다" | "잠시만요, 도구 확인할게요" → ToolSearch |
| "화면을 못 봅니다" | "playwright로 확인해볼게요" → browser_navigate |
| "스크린샷 받아야만 알 수 있어요" | "직접 캡처할게요" → browser_take_screenshot |
| "직접 못 합니다" (시도 없이) | "한 번 시도해볼게요" → 실제 호출 |

### 1.3 자주 잊는 사용 가능 도구

ADK 플러그인 환경에서는 다음 도구들이 거의 항상 사용 가능:

- **playwright**: `mcp__playwright__browser_navigate`,
  `browser_take_screenshot`, `browser_snapshot`, `browser_click`,
  `browser_type`, `browser_fill_form`, `browser_evaluate` 등
  → **dev 서버에 로그인 + 화면 확인 + 클릭·입력까지** 가능
- **WebFetch**: 인증 없는 URL 직접 fetch
- **WebSearch**: 정보 검색 (월별 최신 정보)
- **Bash**: 거의 모든 CLI 명령
- **Edit/Write**: 파일 수정·생성
- **TodoWrite**: 작업 추적
- **Read with images**: 사용자가 보낸 스크린샷 직접 분석
- **그 외 deferred tools**: `ToolSearch`로 매번 확인 가능

### 1.4 정책상 진짜 못 하는 것 (이건 안 함)

이 카테고리는 정책상 진짜 못 함. 단 우회 방법은 항상 안내:

- 사용자 검증 없이 비밀번호 변경 (테스트 계정 포함)
- 사용자 인지 없이 destructive git 명령 (force push, hard reset)
- 시크릿 파일 무단 노출
- 개인정보 무단 처리

### 1.5 자기 점검 임계값

한 세션에서 "못 한다"는 표현을 **2번 이상 쓰면 자기 점검**:
- 정말 못 하는지?
- 게으름이 아닌지?
- ToolSearch 했는지?

---

## 🖼️ 규칙 2: 화면 변경 작업은 playwright로 검증

**Why**: "build 통과 = 완료"는 거짓말. UI/UX 변경은 사용자가 화면에서
보는 게 진짜 결과. 화면 안 보고 끝났다고 선언하면 사용자가 매번 발견 →
재작업 → 답답함 무한 반복.

**How to apply**:

```
1. 작업 전: playwright로 현재 화면 캡처 (before 스크린샷)
2. 코드 수정
3. tsc + build 통과 확인
4. dev 서버 hot reload 또는 production 배포 후
5. playwright로 다시 캡처 (after 스크린샷)
6. before/after 비교 → 의도된 변화 확인
7. 의도와 다르면 즉시 보고
```

### 2.1 인증이 필요한 페이지 처리

dev 서버에 로그인 → 페이지 진입 → 검증 가능:

```
playwright sequence:
1. browser_navigate → /login
2. browser_fill_form → email + password
3. browser_click → 로그인 버튼
4. browser_navigate → 검증 대상 URL
5. browser_take_screenshot or browser_snapshot
6. 확인
```

### 2.2 검증 기준

- ❌ "build 통과했으니 완료"
- ❌ "tsc 에러 없으니 완료"
- ✅ "before/after 스크린샷 비교 OK = 완료"
- ✅ "playwright snapshot에 의도한 요소 보임 = 완료"

---

## 📝 규칙 3: 작업 완료 선언 게이트

다음 6단계를 거치지 않은 작업은 "완료"라고 선언 금지:

```
1. ✓ CLAUDE.md 읽기 (특히 🔴 위험 파일 + Co-update Map)
2. ✓ impact-analyzer.mjs 실행 (수정 대상 파일 모두)
3. ✓ Co-update Map 패턴 매칭 (여러 패턴 동시 가능)
4. ✓ 사용자 승인 받음
5. ✓ 코드 수정 + tsc + build 통과
6. ✓ (UI 변경이면) playwright로 화면 검증 ← 자주 빠뜨림
```

6단계가 모두 ✓일 때만 "완료"라고 말할 것.

---

## 🔄 규칙 4: 패턴 매칭은 넓게

Co-update Map의 패턴 매칭 시 **하나의 패턴만 매칭하지 말 것**.
한 작업은 여러 패턴에 동시에 매칭될 수 있음:

- "draft-info에 영상 채널 추가" = 패턴 8(진입점) + 패턴 9(단계 변경)
- "비밀번호 변경 기능 추가" = 패턴 1(admin 액션) + 패턴 10(폼)
- "새 페이지 추가" = 패턴 11(dashboard 페이지) + (필요 시) 패턴 12(snapshot 구조)

매칭이 의심스러우면 **여러 패턴을 같이 매칭**해서 보고서에 모두 포함.
"매칭 안 된 게 있나?"를 한 번 더 자기 점검.

---

## 🤝 규칙 5: 사용자 시간 존중

**Why**: 사용자는 비개발자일 수 있고, 매번 스크린샷 찍고 설명하는 것
자체가 큰 비용. AI가 능동적으로 시도해서 발견할 수 있는 건 사용자에게
요청하지 말 것.

**How to apply**:

| 상황 | 잘못된 응답 | 올바른 응답 |
|---|---|---|
| 화면 확인 필요 | "스크린샷 보내주세요" | playwright로 직접 캡처 |
| 페이지 동작 검증 | "테스트해보고 알려주세요" | playwright로 자동 클릭·검증 |
| 파일 위치 확인 | "어디 있는지 알려주세요" | Glob/Grep으로 직접 찾기 |
| 환경 변수 확인 | "값 알려주세요" | grep으로 키 이름만 확인 + 값은 묻지 않음 |
| API 응답 확인 | "응답 보여주세요" | curl 또는 직접 fetch |

**핵심**: 사용자에게 묻기 전에 **3가지 시도해보기**. 그래도 안 되면 그제야 묻기.

---

## 6. 메타: 이 규칙들의 갱신

이 파일은 사용자가 반복 지적하는 패턴을 발견할 때마다 추가됨.
새 규칙을 추가하려면:

1. agent-dev-kit/AI-BEHAVIOR.md 편집
2. 각 규칙은 **Why** + **How to apply** 형식
3. 가능하면 ❌/✅ 표 또는 구체적 예시 포함
4. commit + push → 다음 세션부터 자동 적용

이 규칙들은 **모든 ADK 사용자**에게 적용됨. 본인 프로젝트 특수 규칙은
프로젝트의 CLAUDE.md에 별도로.

---

## 참고

- 이 규칙들은 ADK 플러그인의 일부로 git에 포함됨
- 다른 컴퓨터에서 plugin install 시 자동 배포
- 다른 프로젝트에서도 CLAUDE.md에 한 줄로 import 가능
- 로컬 Claude memory에도 저장 가능 (`feedback_no_capability_lies.md`)

**최초 작성**: 2026-04-15. 사용자가 "playwright 있는데 왜 못 본다고 하느냐"
지적한 사례에서 출발.
