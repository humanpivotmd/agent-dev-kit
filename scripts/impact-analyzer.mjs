#!/usr/bin/env node
// Impact analyzer — AST-based, replaces the legacy grep version.
//
// Uses:
//   - ts-morph for type-aware caller detection (no false positives from
//     strings, comments, or unrelated same-named identifiers)
//   - madge for module dependency graph + circular dependency detection
//
// Install (in the target project, not in the plugin):
//   npm i -D ts-morph madge
//
// Usage:
//   node scripts/impact-analyzer.mjs <file-path>
//   node scripts/impact-analyzer.mjs src/lib/auth.ts --json
//
// Exit codes:
//   0  safe (🟢)
//   1  warning (🟡)
//   2  high risk (🔴)

import { readFileSync, existsSync } from 'node:fs';
import { resolve, relative, basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// --- Arg parsing -----------------------------------------------------------
const args = process.argv.slice(2);
if (args.length === 0) {
  console.error('Usage: impact-analyzer.mjs <file-path> [--json]');
  process.exit(3);
}
const targetArg = args.find(a => !a.startsWith('--'));
const jsonOut = args.includes('--json');

// --- Locate project root (walk up looking for tsconfig.json) ---------------
function findProjectRoot(start) {
  let dir = resolve(start);
  while (true) {
    if (existsSync(join(dir, 'tsconfig.json'))) return dir;
    const parent = dirname(dir);
    if (parent === dir) return resolve(start);
    dir = parent;
  }
}

const cwd = process.cwd();
const targetAbs = resolve(cwd, targetArg);
const projectRoot = findProjectRoot(targetAbs);

if (!existsSync(targetAbs)) {
  console.error(`File not found: ${targetAbs}`);
  process.exit(3);
}

// --- Dynamic imports (graceful degradation if deps missing) ----------------
let tsMorph, madge;
try {
  tsMorph = await import('ts-morph');
} catch {
  console.error('⚠️  ts-morph not installed — AST analysis disabled.');
  console.error('   Run: npm i -D ts-morph');
}
try {
  madge = (await import('madge')).default;
} catch {
  console.error('⚠️  madge not installed — dependency graph disabled.');
  console.error('   Run: npm i -D madge');
}

// --- AST analysis ----------------------------------------------------------
async function astAnalysis() {
  if (!tsMorph) return null;
  const { Project } = tsMorph;
  const tsconfigPath = join(projectRoot, 'tsconfig.json');
  const project = new Project({
    tsConfigFilePath: existsSync(tsconfigPath) ? tsconfigPath : undefined,
    skipAddingFilesFromTsConfig: false,
  });

  const source = project.getSourceFile(targetAbs);
  if (!source) {
    return { error: `File not in tsconfig scope: ${targetAbs}` };
  }

  // ts-morph normalizes paths to forward slashes; match that for comparison.
  const targetPath = source.getFilePath();

  // Exported declarations → find references (excluding self-file references)
  const exports = [];
  for (const [name, decls] of source.getExportedDeclarations()) {
    const refs = new Set();
    for (const decl of decls) {
      if (typeof decl.findReferencesAsNodes !== 'function') continue;
      try {
        for (const node of decl.findReferencesAsNodes()) {
          const file = node.getSourceFile().getFilePath();
          if (file === targetPath) continue; // skip self-references
          refs.add(relative(projectRoot, file));
        }
      } catch {
        // findReferences can throw on disconnected nodes — ignore
      }
    }
    exports.push({ name, callerCount: refs.size, callers: [...refs] });
  }

  // Imports (outgoing edges)
  const imports = source.getImportDeclarations().map(d => d.getModuleSpecifierValue());

  // Uniquecallers (union across all exports)
  const allCallers = new Set();
  exports.forEach(e => e.callers.forEach(c => allCallers.add(c)));

  return {
    exports,
    imports,
    uniqueCallers: [...allCallers],
    uniqueCallerCount: allCallers.size,
  };
}

// --- Madge dependency graph ------------------------------------------------
async function madgeAnalysis() {
  if (!madge) return null;
  try {
    const tsconfig = join(projectRoot, 'tsconfig.json');
    const tree = await madge(targetAbs, {
      baseDir: projectRoot,
      tsConfig: existsSync(tsconfig) ? tsconfig : undefined,
      fileExtensions: ['ts', 'tsx', 'js', 'jsx', 'mjs', 'cjs'],
      detectiveOptions: { ts: { skipTypeImports: true } },
    });
    const circular = tree.circular();
    const depsOfTarget = tree.depends(relative(projectRoot, targetAbs));
    return {
      circular: circular.filter(cycle => cycle.some(f => f.includes(basename(targetAbs)))),
      directDependents: depsOfTarget,
    };
  } catch (e) {
    return { error: e.message };
  }
}

// --- Risk scoring ----------------------------------------------------------
function scoreRisk({ ast, graph }) {
  let score = 0;
  const reasons = [];

  if (ast?.uniqueCallerCount > 10) {
    score += 3;
    reasons.push(`High fan-in: ${ast.uniqueCallerCount} unique callers`);
  } else if (ast?.uniqueCallerCount > 5) {
    score += 1;
    reasons.push(`Moderate fan-in: ${ast.uniqueCallerCount} callers`);
  }

  if (ast?.exports.length > 10) {
    score += 1;
    reasons.push(`Large public surface: ${ast.exports.length} exports`);
  }

  if (graph?.circular?.length > 0) {
    score += 3;
    reasons.push(`Circular dependency involving this file`);
  }

  if (graph?.directDependents?.length > 15) {
    score += 2;
    reasons.push(`${graph.directDependents.length} direct dependents`);
  }

  // Path heuristics — core/shared/lib paths are riskier
  const rel = relative(projectRoot, targetAbs);
  if (/\b(lib|shared|core|constants|types|auth|api)\b/.test(rel)) {
    score += 2;
    reasons.push(`Path heuristic: shared/core module`);
  }

  const level = score >= 6 ? '🔴' : score >= 3 ? '🟡' : '🟢';
  return { score, level, reasons };
}

// --- Main ------------------------------------------------------------------
const [ast, graph] = await Promise.all([astAnalysis(), madgeAnalysis()]);
const risk = scoreRisk({ ast, graph });

const report = {
  target: relative(projectRoot, targetAbs),
  projectRoot,
  ast,
  graph,
  risk,
};

if (jsonOut) {
  console.log(JSON.stringify(report, null, 2));
} else {
  const bar = '='.repeat(60);
  console.log(`\n${bar}\nImpact analysis: ${report.target}\n${bar}`);

  if (ast?.error) {
    console.log(`AST: ${ast.error}`);
  } else if (ast) {
    console.log(`\n🔧 AST analysis`);
    console.log(`  Exports: ${ast.exports.length}`);
    console.log(`  Imports: ${ast.imports.length}`);
    console.log(`  Unique callers: ${ast.uniqueCallerCount}`);
    if (ast.uniqueCallerCount > 0 && ast.uniqueCallerCount <= 20) {
      console.log(`  Caller files:`);
      ast.uniqueCallers.forEach(c => console.log(`    - ${c}`));
    }
  }

  if (graph?.error) {
    console.log(`\n📊 Graph: ${graph.error}`);
  } else if (graph) {
    console.log(`\n📊 Dependency graph`);
    console.log(`  Direct dependents: ${graph.directDependents?.length ?? 0}`);
    console.log(`  Circular deps involving this file: ${graph.circular?.length ?? 0}`);
    if (graph.circular?.length > 0) {
      graph.circular.forEach(cycle => console.log(`    ! ${cycle.join(' → ')}`));
    }
  }

  console.log(`\n⚠️  Risk: ${risk.level} (score ${risk.score})`);
  risk.reasons.forEach(r => console.log(`   - ${r}`));
  console.log(`${bar}\n`);
}

process.exit(risk.level === '🔴' ? 2 : risk.level === '🟡' ? 1 : 0);
