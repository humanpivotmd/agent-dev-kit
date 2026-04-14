#!/bin/bash

# Impact Analyzer 설치 스크립트
# 새 프로젝트에 자동으로 영향 분석 도구를 설치합니다

echo "🚀 Impact Analyzer 설치 시작..."

PROJECT_ROOT="$(pwd)"
SCRIPT_DIR="$(dirname "$0")"

# 1. impact-analyzer.js 복사
echo "📋 impact-analyzer.js 복사 중..."
cp "$SCRIPT_DIR/impact-analyzer.js" "$PROJECT_ROOT/" || {
    echo "❌ impact-analyzer.js 복사 실패"
    exit 1
}

# 2. package.json에 axios 추가
echo "📦 axios 의존성 추가 중..."
if [ -f "$PROJECT_ROOT/package.json" ]; then
    # jq가 있는지 확인
    if command -v jq &> /dev/null; then
        # jq를 사용하여 devDependencies에 axios 추가
        jq '.devDependencies.axios = "^1.6.0"' "$PROJECT_ROOT/package.json" > "$PROJECT_ROOT/package.json.tmp" && mv "$PROJECT_ROOT/package.json.tmp" "$PROJECT_ROOT/package.json"
        echo "✅ axios를 devDependencies에 추가했습니다"
    else
        echo "⚠️ jq가 설치되지 않아 수동으로 axios를 추가해주세요:"
        echo "npm install --save-dev axios@^1.6.0"
    fi
else
    echo "⚠️ package.json이 없어 새로 생성합니다"
    cat > "$PROJECT_ROOT/package.json" << EOF
{
  "name": "new-project",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "dev": "echo '개발 스크립트 설정 필요'",
    "build": "echo '빌드 스크립트 설정 필요'",
    "start": "echo '시작 스크립트 설정 필요'"
  },
  "devDependencies": {
    "axios": "^1.6.0"
  }
}
EOF
fi

# 3. Git hook 설정
echo "🔗 Git pre-commit hook 설정 중..."
mkdir -p "$PROJECT_ROOT/.git/hooks"

cat > "$PROJECT_ROOT/.git/hooks/pre-commit" << 'EOF'
#!/bin/bash

# 영향 분석 자동 실행
echo "🔍 커밋 전 영향 분석 실행 중..."

# 변경된 파일들 찾기
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|tsx|js|jsx)$' | head -5)

if [ -z "$CHANGED_FILES" ]; then
    echo "ℹ️ 분석할 변경 파일이 없습니다."
    exit 0
fi

# 각 파일에 대해 영향 분석 실행
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        echo "📊 $file 분석 중..."
        node impact-analyzer.js "$file"
        if [ $? -ne 0 ]; then
            echo "❌ $file 분석 실패. 커밋을 중단합니다."
            exit 1
        fi
    fi
done

echo "✅ 모든 파일 분석 완료. 커밋을 진행합니다."
EOF

chmod +x "$PROJECT_ROOT/.git/hooks/pre-commit"
echo "✅ Git hook 실행 권한 설정 완료"

# 4. 의존성 설치
echo "📦 의존성 설치 중..."
if [ -f "$PROJECT_ROOT/package.json" ]; then
    npm install
    echo "✅ 의존성 설치 완료"
else
    echo "⚠️ package.json이 없어 npm install을 건너뜁니다"
fi

# 5. 환경 변수 템플릿 생성
if [ ! -f "$PROJECT_ROOT/.env.local" ]; then
    cat > "$PROJECT_ROOT/.env.local" << EOF
# Impact Analyzer 환경 변수
# Slack 공유를 위해 아래 변수를 설정하세요
# SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
EOF
    echo "✅ .env.local 템플릿 생성 (Slack 웹훅 URL 설정 가능)"
fi

echo ""
echo "🎉 Impact Analyzer 설치 완료!"
echo ""
echo "📖 사용법:"
echo "  node impact-analyzer.js <파일경로>"
echo "  예: node impact-analyzer.js src/components/Button.tsx"
echo ""
echo "🔧 설정:"
echo "  - Slack 공유: .env.local에 SLACK_WEBHOOK_URL 설정"
echo "  - Git hook: 커밋 시 자동 분석 실행"
echo ""
echo "📊 테스트:"
echo "  node impact-analyzer.js impact-analyzer.js"