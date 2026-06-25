---
name: webapp-protheus-instructions-generator
description: "Generate project-tailored AdvPL/TLPP agent-instruction files (a canonical AGENTS.md plus a CLAUDE.md symlink) for a TOTVS Protheus repo. Starts from the canonical TOTVS instruction template bundled in the skill, analyzes the target repo's real structure, and emits a root file plus per-area sub-files only where areas diverge — replacing the template's generic layout with the discovered one, scoping the language rules to the Protheus areas, and validating every reference before writing. Architecture-agnostic: single source tree, monorepo, MVC routines, layered REST API, or entry-points-only. Use when the user wants to generate, create, init, or scaffold a CLAUDE.md / AGENTS.md for a Protheus project, adapt the TOTVS AdvPL/TLPP instructions to a real repo, run a Protheus-aware /init, or set up agent guidance for an AdvPL/TLPP codebase. Triggers: 'gerar CLAUDE.md', 'adaptar AGENTS.md', 'init Protheus instructions', 'criar CLAUDE.md do projeto'."
license: MIT
metadata:
  domain: Protheus
  maintainer: AdvPL/TLPP Customizations
  author: Vinicius M. Barbosa
  version: 1.0.0
  category: Project Setup & Documentation
---

# AdvPL/TLPP Agent-Instructions Generator

Produce a **tailored** `AGENTS.md` (plus a `CLAUDE.md` symlink) for a real TOTVS Protheus repo by **adapting** the canonical TOTVS AdvPL/TLPP template — never by copying it verbatim.

The bundled template ships two kinds of content: reusable language/convention rules (keep these) **and** a generic "Project Structure" block that is almost always wrong for a real repo (replace this). The skill's job is to keep the rules, swap the framing for the repo's real architecture, scope the rules to the Protheus areas, and verify every reference.

## Inputs

- **Target repo** — the Protheus project to document (default: current working directory).
- **Bundled template** — [references/advpl-tlpp-instructions.md](references/advpl-tlpp-instructions.md). Source-of-truth for the language/type/naming/SonarQube/class-syntax/forbidden-function rules. Upstream origin: the engpro `instructions/CLAUDE.md`; re-sync this copy manually if upstream changes.

## Workflow (checklist)

1. **Detect the project shape — do not assume.** Map the repo (dispatch the `Explore` agent for breadth): single source tree vs monorepo, classic MVC routines, layered REST API, entry-points-only, mixed non-AdvPL areas. The architecture is an OUTPUT of analysis, never a template constant.
2. **Read the bundled template** and [references/transformation-guide.md](references/transformation-guide.md). Keep the language/type/naming/SonarQube/class-syntax/forbidden-function rules; mark the template's "Project Structure" (and its TIR/Build claims) for replacement.
3. **Replace the generic layout** with the discovered one — an orientation table of areas, plus a request-flow diagram when the repo has a runtime flow.
4. **Scope rules to where they apply.** If any area is non-AdvPL (TypeScript web, Python, etc.), state explicitly that the AdvPL/TLPP rules cover only the Protheus areas, and point elsewhere for the rest.
5. **Split per-area ONLY when areas diverge** (an area with its own architecture/guardrails). Cross-link from the root with a table. A single-area repo stays one file. See [references/output-format.md](references/output-format.md).
6. **Verify every reference before writing it.** Validate skill names against what the Skill tool actually lists; validate file links against the real tree. Drop or correct dead refs — never emit a path that does not exist. This was the single biggest fix in the worked example.
7. **State Build/Tests as reality.** Inspect first; do not claim a runner, TIR suite, or CI exists if it does not.
8. **Current-state, not mandate; honest uncertainty.** Describe a planned-refactor area as current-state (not a rule); flag an unconfirmed assumption as unconfirmed instead of asserting it.
9. **Emit the files** per [references/output-format.md](references/output-format.md): `AGENTS.md` canonical + `CLAUDE.md` symlink, root plus diverging areas. Prefix the root with the standard `# CLAUDE.md` / "This file provides guidance to Claude Code..." block.
10. **Review with the user** — show the planned area map and the proposed splits before writing the files.

## Output targets

Canonical content lives in **`AGENTS.md`**; **`CLAUDE.md` is a symlink** to it so the two never drift. Per area, the same pair lives in the area directory. Symlink mechanics (Windows/POSIX) and the privilege-denied fallback are in [references/output-format.md](references/output-format.md).

## Hard constraints

- **`CLAUDE.md` / `AGENTS.md` are Markdown → UTF-8.** Safe to Write directly. **Never** Write/Edit an AdvPL/TLPP **source** (`.prw`/`.tlpp`/`.ch`) — those are CP-1252 and corrupt on a UTF-8 round-trip (`ç`/`ã`/`é` → U+FFFD). Use the `utf8-to-cp1252-conversion` skill if a source ever needs touching. This skill writes Markdown only.
- **Match the target repo's house language.** Protheus default is pt-BR, but the existing CLAUDE.md files in this ecosystem are written in English — mirror the repo's existing style; do not force a language.
- **`/init` discipline.** Do not restate obvious practices, do not enumerate every file, do not invent "Common Tasks / Tips" sections.
- **Architecture-agnostic.** The monorepo in the worked example is ONE shape, not the contract.

## References

- [references/advpl-tlpp-instructions.md](references/advpl-tlpp-instructions.md) — the canonical TOTVS template to adapt (bundled byte-copy).
- [references/transformation-guide.md](references/transformation-guide.md) — the full algorithm, keep-vs-replace map, per-area heuristics, dead-ref validation, and the CCM monorepo worked example.
- [references/output-format.md](references/output-format.md) — file skeletons, the standard header block, root orientation table + request-flow diagram patterns, and AGENTS.md/CLAUDE.md symlink mechanics & fallback.
