#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * 자동 영향 분석 도구
 * 파일 수정 시 복합적인 영향을 분석합니다
 */

class ImpactAnalyzer {
  constructor() {
    this.projectRoot = path.resolve(__dirname);
    this.srcDir = path.join(this.projectRoot, 'src');
  }

  /**
   * 파일 의존성 분석
   */
  analyzeFileDependencies(targetFile) {
    console.log(`🔍 파일 의존성 분석: ${targetFile}`);

    const imports = this.findImports(targetFile);
    const exports = this.findExports(targetFile);
    const usages = this.findUsages(targetFile);

    return {
      imports,
      exports,
      usages,
      dependencyMap: this.buildDependencyMap(targetFile, usages)
    };
  }

  /**
   * UI/UX 영향 분석
   */
  analyzeUIImpact(targetFile) {
    console.log(`🎨 UI/UX 영향 분석`);

    const uiComponents = this.findUIComponents(targetFile);
    const routes = this.findRoutes(targetFile);
    const styles = this.findStyles(targetFile);

    return {
      components: uiComponents,
      routes,
      styles,
      responsive: this.checkResponsive(targetFile),
      accessibility: this.checkAccessibility(targetFile)
    };
  }

  /**
   * 프로세스/비즈니스 로직 영향 분석
   */
  analyzeProcessImpact(targetFile) {
    console.log(`⚙️ 프로세스 영향 분석`);

    const workflows = this.findWorkflows(targetFile);
    const stateManagement = this.findStateManagement(targetFile);
    const apiCalls = this.findAPICalls(targetFile);

    return {
      workflows,
      stateManagement,
      apiCalls,
      businessRules: this.findBusinessRules(targetFile)
    };
  }

  /**
   * 함수/모듈 영향 분석
   */
  analyzeFunctionImpact(targetFile) {
    console.log(`🔧 함수 영향 분석`);

    const functions = this.findFunctions(targetFile);
    const classes = this.findClasses(targetFile);
    const interfaces = this.findInterfaces(targetFile);

    return {
      functions,
      classes,
      interfaces,
      callChain: this.buildCallChain(targetFile)
    };
  }

  /**
   * 데이터베이스 영향 분석
   */
  analyzeDBImpact(targetFile) {
    console.log(`🗄️ DB 영향 분석`);

    const queries = this.findDBQueries(targetFile);
    const schemas = this.findSchemas(targetFile);
    const migrations = this.findMigrations(targetFile);

    return {
      queries,
      schemas,
      migrations,
      dataFlow: this.analyzeDataFlow(targetFile)
    };
  }

  /**
   * 종합 리스크 평가
   */
  assessRisk(analysisResults) {
    console.log(`⚠️ 리스크 평가`);

    let riskScore = 0;
    const risks = [];

    // 파일 의존성 리스크
    if (analysisResults.file.usages.length > 10) {
      riskScore += 3;
      risks.push('높은 파일 의존성 (10개 이상의 사용처)');
    }

    // UI 영향 리스크
    if (analysisResults.ui.components.length > 5) {
      riskScore += 2;
      risks.push('다수의 UI 컴포넌트 영향');
    }

    // 프로세스 영향 리스크
    if (analysisResults.process.workflows.length > 0) {
      riskScore += 3;
      risks.push('비즈니스 프로세스 영향');
    }

    // DB 영향 리스크
    if (analysisResults.db.schemas.length > 0) {
      riskScore += 4;
      risks.push('DB 스키마 변경 필요');
    }

    // 함수 영향 리스크
    if (analysisResults.function.callChain.length > 5) {
      riskScore += 2;
      risks.push('복잡한 함수 호출 체인');
    }

    return {
      score: riskScore,
      level: riskScore >= 8 ? '🔴' : riskScore >= 4 ? '🟡' : '🟢',
      risks
    };
  }

  /**
   * 메인 분석 실행
   */
  async analyze(targetFile) {
    console.log(`🚀 영향 분석 시작: ${targetFile}\n`);

    const results = {
      file: this.analyzeFileDependencies(targetFile),
      ui: this.analyzeUIImpact(targetFile),
      process: this.analyzeProcessImpact(targetFile),
      function: this.analyzeFunctionImpact(targetFile),
      db: this.analyzeDBImpact(targetFile)
    };

    const risk = this.assessRisk(results);

    this.printReport(results, risk);

    return { results, risk };
  }

  // 실제 분석 메서드들 (간단한 grep 기반)
  findImports(file) {
    try {
      const content = fs.readFileSync(path.join(this.srcDir, file), 'utf8');
      const imports = content.match(/import.*from ['"]([^'"]+)['"]/g) || [];
      return imports.map(imp => imp.match(/from ['"]([^'"]+)['"]/)[1]);
    } catch {
      return [];
    }
  }

  findExports(file) {
    try {
      const content = fs.readFileSync(path.join(this.srcDir, file), 'utf8');
      const exports = content.match(/export (const|function|class|interface)/g) || [];
      return exports;
    } catch {
      return [];
    }
  }

  findUsages(file) {
    const fileName = path.basename(file, path.extname(file));
    const usages = [];
    
    // 재귀적으로 src 디렉토리 탐색
    const searchDirectory = (dir) => {
      try {
        const items = fs.readdirSync(dir);
        
        for (const item of items) {
          const fullPath = path.join(dir, item);
          const stat = fs.statSync(fullPath);
          
          if (stat.isDirectory() && !item.startsWith('.') && item !== 'node_modules') {
            searchDirectory(fullPath);
          } else if (stat.isFile() && ['.ts', '.tsx', '.js', '.jsx'].includes(path.extname(fullPath))) {
            try {
              const content = fs.readFileSync(fullPath, 'utf8');
              if (content.includes(fileName) && fullPath !== path.join(this.srcDir, file)) {
                usages.push(path.relative(this.projectRoot, fullPath));
              }
            } catch (error) {
              // 파일 읽기 실패 시 무시
            }
          }
        }
      } catch (error) {
        // 디렉토리 접근 실패 시 무시
      }
    };
    
    searchDirectory(this.srcDir);
    return usages;
  }

  findUIComponents(file) {
    try {
      const content = fs.readFileSync(path.join(this.srcDir, file), 'utf8');
      const components = content.match(/<([A-Z][a-zA-Z0-9]*)/g) || [];
      return [...new Set(components.map(c => c.slice(1)))];
    } catch {
      return [];
    }
  }

  findRoutes(file) {
    try {
      const content = fs.readFileSync(path.join(this.srcDir, file), 'utf8');
      const routes = content.match(/href=["']([^"']+)["']/g) || [];
      return routes.map(r => r.match(/href=["']([^"']+)["']/)[1]);
    } catch {
      return [];
    }
  }

  findStyles(file) {
    try {
      const content = fs.readFileSync(path.join(this.srcDir, file), 'utf8');
      const styles = content.match(/className=["']([^"']+)["']/g) || [];
      return styles.map(s => s.match(/className=["']([^"']+)["']/)[1]);
    } catch {
      return [];
    }
  }

  findWorkflows(file) {
    try {
      const content = fs.readFileSync(path.join(this.srcDir, file), 'utf8');
      const workflows = content.match(/(workflow|process|flow)/gi) || [];
      return workflows;
    } catch {
      return [];
    }
  }

  findAPICalls(file) {
    try {
      const content = fs.readFileSync(path.join(this.srcDir, file), 'utf8');
      const apis = content.match(/fetch\(|axios\./g) || [];
      return apis;
    } catch {
      return [];
    }
  }

  findFunctions(file) {
    try {
      const content = fs.readFileSync(path.join(this.srcDir, file), 'utf8');
      const functions = content.match(/function ([a-zA-Z_$][a-zA-Z0-9_$]*)/g) || [];
      return functions.map(f => f.replace('function ', ''));
    } catch {
      return [];
    }
  }

  findDBQueries(file) {
    try {
      const content = fs.readFileSync(path.join(this.srcDir, file), 'utf8');
      const queries = content.match(/\.from\(|\.select\(|\.insert\(|\.update\(|\.delete\(/g) || [];
      return queries;
    } catch {
      return [];
    }
  }

  // 기타 메서드들 (간단 구현)
  findExports() { return []; }
  buildDependencyMap() { return {}; }
  checkResponsive() { return false; }
  checkAccessibility() { return false; }
  findStateManagement() { return []; }
  findBusinessRules() { return []; }
  findClasses() { return []; }
  findInterfaces() { return []; }
  buildCallChain() { return []; }
  findSchemas() { return []; }
  findMigrations() { return []; }
  analyzeDataFlow() { return {}; }

  printReport(results, risk) {
    console.log('\n📊 영향 분석 리포트');
    console.log('='.repeat(50));

    console.log(`\n🔍 파일 의존성:`);
    console.log(`  - Imports: ${results.file.imports.length}개`);
    console.log(`  - Exports: ${results.file.exports.length}개`);
    console.log(`  - Usages: ${results.file.usages.length}개`);

    console.log(`\n🎨 UI/UX 영향:`);
    console.log(`  - Components: ${results.ui.components.length}개`);
    console.log(`  - Routes: ${results.ui.routes.length}개`);

    console.log(`\n⚙️ 프로세스 영향:`);
    console.log(`  - Workflows: ${results.process.workflows.length}개`);
    console.log(`  - API Calls: ${results.process.apiCalls.length}개`);

    console.log(`\n🔧 함수 영향:`);
    console.log(`  - Functions: ${results.function.functions.length}개`);

    console.log(`\n🗄️ DB 영향:`);
    console.log(`  - Queries: ${results.db.queries.length}개`);

    console.log(`\n⚠️ 리스크 평가: ${risk.level} (점수: ${risk.score})`);
    risk.risks.forEach(risk => console.log(`  - ${risk}`));

    console.log('\n' + '='.repeat(50));
  }
}

// CLI 실행
if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.log('사용법: node impact-analyzer.js <파일경로>');
    console.log('예시: node impact-analyzer.js app/(dashboard)/contents/page.tsx');
    process.exit(1);
  }

  const analyzer = new ImpactAnalyzer();
  analyzer.analyze(args[0]).catch(console.error);
}

module.exports = ImpactAnalyzer;