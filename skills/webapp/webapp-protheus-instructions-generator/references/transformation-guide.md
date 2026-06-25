# Transformation Guide — canonical template to tailored project instructions

This is the reusable algorithm the skill encodes: take the bundled canonical TOTVS AdvPL/TLPP
template ([advpl-tlpp-instructions.md](advpl-tlpp-instructions.md)) and turn it into agent
instructions that describe a **real** repo. The architecture is discovered, never assumed.

---

## 1. Keep vs. replace map

The template mixes durable rules with generic placeholders. Classify each section before writing:

| Template section | Action | Why |
|------------------|--------|-----|
| Language and Ecosystem | **Keep**, but trim claims that are false for the repo (e.g. "Python TIR tests" if there are none) | Reusable framing, but must not assert capabilities that do not exist |
| Project Structure (`Fontes_Doc/Master/Fontes/`, `Testes/Automação Protheus/`, `.agents/skills/`) | **Replace entirely** | Always fake for a real repo — this is the #1 thing to fix |
| Code Conventions — Naming | **Keep** | Durable Protheus convention |
| Type System (AdvPL vs TLPP, declaration syntax, class/method two-part rules) | **Keep** | Durable language rules |
| Mandatory Standards (D_E_L_E_T_, xFilial, FWExecStatement, forbidden `Function`/`IIF`/`cFilial`, encoding, FWRest) | **Keep** | Durable, high-value guardrails |
| SonarQube CA rules | **Keep** | Durable |
| MVC pattern / Modern TLPP | **Keep**, scope to the areas that actually use each | Both patterns rarely coexist in one area |
| API Symbol Validation / Completeness Verification | **Keep** | Durable process rules |
| Build and Compilation | **Rewrite to reality** | Template assumes a layout/toolchain the repo may not have |
| Tests | **Rewrite to reality** | Never claim a runner/TIR/CI that is not wired up |
| Available Skills catalog | **Validate, then keep only what resolves** | Template links `.agents/skills/...` paths that usually do not exist — see §4 |

Rule of thumb: **language rules are reusable, project framing is not.** Preserve the former; derive the latter from analysis.

---

## 2. Detect the project shape first

Map the repo before writing a single line. Dispatch the `Explore` agent for breadth, or inspect directly:

- **Single source tree** — one folder of `.prw`/`.tlpp`. One root file, no splits.
- **Monorepo** — e.g. a TypeScript front-end + a Protheus back-end. Root orientation table + per-area files; scope AdvPL rules to the Protheus areas only.
- **Classic MVC routines** — keep the MVC section prominent; the REST/Modern-TLPP sections are secondary.
- **Layered REST API** — document the layering as discovered (composition root → controller → use-case → repository, or whatever exists), and whether it is a mandate or current-state (§5).
- **Entry-points-only** — lead with the EP naming rules (no `U_` in the declaration, `_pe` file convention) and the host routines they hook.
- **Mixed / set-aside areas** — folders whose status is uncertain get an honest "status unconfirmed" guardrail, not a confident "legacy" label (§5).

The shape determines the section emphasis and whether to split. Do not pattern-match to the worked example — re-derive it for each repo.

---

## 3. Per-area splitting heuristics

Split into a sub-`CLAUDE.md`/`AGENTS.md` **only when an area genuinely diverges**:

**Split when** the area has its own architecture, toolchain, language, or guardrails — e.g. a TypeScript `web/` next to a TLPP `server/`; a "set-aside / unconfirmed" folder; a back-end with a layering worth a dedicated map.

**Do NOT split when** areas share the same conventions and a single root file with scoped sections reads cleanly. Over-splitting fragments the guidance and multiplies maintenance.

When you split:
- The **root** carries the orientation table (areas + roles + stacks + "has own CLAUDE.md?"), the request-flow diagram, the cross-links, and the shared language rules.
- Each **sub-file** opens by stating it complements the root and which root rules still apply, then covers only what is specific to that area.
- An area that already has its own up-to-date file (e.g. a hand-written `web/CLAUDE.md`) is **left untouched and only linked** — do not overwrite it.

---

## 4. Verify every reference before writing it (the biggest fix)

The template links skill paths and files that do not exist in an arbitrary repo. Never emit a dead reference.

- **Skill names** — validate against what the Skill tool actually lists in-session. If the template names a skill that is not installed, drop it or point to the Skill-tool equivalent. Mark availability as environment-dependent when relevant.
- **File links** — every `path/to/file` in the output must resolve in the real tree. Glob/stat before writing. Correct or remove anything that does not exist.
- **The `.agents/skills/...references/...md` paths from the template are placeholders** — they are not real in a target repo. Replace them with "invoke via the Skill tool" guidance or the repo's actual skill location.

A reference that 404s teaches the next agent to trust a fiction. Validate, then write.

---

## 5. Honesty rules

- **Build/Tests = reality.** Inspect for a runner, CI wiring, TIR/ProBat suites. If none exist, say so plainly. Do not inherit the template's assumptions.
- **Current-state, not mandate.** When the team signals a planned refactor, describe the existing structure as the current state and say new work is not bound to it (ask the user if the target is undecided) — do not freeze a soon-to-change layout into a rule.
- **Honest uncertainty over false confidence.** A folder named "eliminados"/"legacy"/"old" is not proof the code is dead. If status is unverified, write "status unconfirmed — verify against the RPO" rather than asserting "legacy". Tell the reader how to confirm.

---

## 6. Worked example — the CCM monorepo (one shape, not the contract)

This is the transformation the skill generalizes. Treat it as a **pattern reference**, not a template to copy.

**Starting point:** a monorepo whose root `CLAUDE.md` was a verbatim copy of the 24 KB generic template (fake `Fontes_Doc/...` layout included).

**Discovered shape:** two deployable products (`web/` Next.js + TypeScript; `server/` AdvPL/TLPP REST API + ERP customizations) and two source-only areas (`protheus/` deploy artifacts; `eliminados/` set-aside sources), plus `docs/`.

**Transformation decisions:**
- **Root** — replaced the fake Project Structure with an orientation table (Path | Role | Stack | Has own CLAUDE.md) + a request-flow diagram (`web → server REST → Protheus DB`). Kept all the TOTVS language rules **but scoped them to `server/` + `eliminados/`** with an explicit note that `web/` is TypeScript and follows `web/CLAUDE.md`.
- **`server/CLAUDE.md`** (new) — documented the current 4-layer REST layering (route → main → controller → use-case → repository) **as current-state, with a planned-refactor caveat**: keep the structure when touching existing endpoints; new routes are not required to replicate it.
- **`eliminados/CLAUDE.md`** (new) — downgraded "legacy" to **"status unconfirmed — verify against the RPO"**; rules say do not assume dead, do not modify, do read for porting.
- **`web/CLAUDE.md`** — already existed (TypeScript); **left untouched, only linked.**

The transferable moves: replace fake layout with a real orientation table + flow diagram; scope language rules to the Protheus areas; split per-area where they diverge; describe planned-refactor layering as current-state; turn an unverified "legacy" label into honest uncertainty; never overwrite a good pre-existing area file.

---

## 7. Finish

Before declaring done: every emitted link resolves, every referenced skill is real, Build/Tests reflect reality, and the user has seen the area map and the split decisions. Then write `AGENTS.md` + the `CLAUDE.md` symlink per [output-format.md](output-format.md).
