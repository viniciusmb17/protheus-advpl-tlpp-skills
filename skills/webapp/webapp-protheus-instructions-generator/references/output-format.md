# Output Format — files, skeletons, and the AGENTS.md/CLAUDE.md symlink

How to emit the tailored instructions: which files, what each contains, and how to wire the
canonical-file-plus-symlink so the two never drift.

---

## File layout per area

Canonical content lives in **`AGENTS.md`**. **`CLAUDE.md` is a symlink** pointing at the `AGENTS.md`
in the **same directory**. One pair at the repo root; one pair inside each diverging area.

```
<repo>/
├── AGENTS.md            # canonical (the real content)
├── CLAUDE.md            # symlink → AGENTS.md
├── server/
│   ├── AGENTS.md        # area-specific canonical
│   └── CLAUDE.md        # symlink → AGENTS.md  (relative, same dir)
└── web/
    └── CLAUDE.md        # pre-existing, hand-written → leave as-is, only link from root
```

Write the canonical `AGENTS.md` first, then create the `CLAUDE.md` symlink beside it.

---

## Symlink mechanics

The symlink target is **relative and same-directory** (`AGENTS.md`), so each area's `CLAUDE.md`
resolves to that area's `AGENTS.md`.

**POSIX (Bash):**

```bash
ln -sf AGENTS.md "<dir>/CLAUDE.md"   # run with cwd = <dir>, or use a relative target
```

**Windows (PowerShell):**

```powershell
New-Item -ItemType SymbolicLink -Path "<dir>\CLAUDE.md" -Target "AGENTS.md"
```

**Fallback — symlink creation denied** (Windows without Developer Mode / admin, or a filesystem
that rejects symlinks): do **not** silently diverge. Either:

1. Write `CLAUDE.md` as a **copy** of `AGENTS.md` and add a top-of-file note
   `<!-- Keep in sync with AGENTS.md (symlink unavailable on this host). -->`, then **warn the user**
   they must re-copy on every edit; or
2. Ask the user to enable Developer Mode / run elevated, then retry the symlink.

Always tell the user which path was taken. A copy that silently drifts is worse than a visible warning.

---

## Root file skeleton

Prefix with the standard block (matches `/init` output):

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
```

Then, in order:

1. **What this repository is** — one short paragraph: the product, the ERP it fronts, the shape
   (monorepo / single tree / EP-only).
2. **Orientation table** (only if multiple areas):

   ```markdown
   | Path | Role | Stack | Has own CLAUDE.md |
   |------|------|-------|-------------------|
   | server/ | Protheus back-end | AdvPL/TLPP | ✅ server/CLAUDE.md |
   | web/    | Front-end portal  | Next.js/TS | ✅ web/CLAUDE.md |
   ```

3. **Request-flow diagram** (only if there is a runtime flow):

   ```
   web (Next.js) ──HTTP──> server REST (/v1/...) ──> Protheus DB + ERP routines
   ```

4. **Scope note** — if any area is non-AdvPL, state that the AdvPL/TLPP rules below apply only to the
   Protheus areas, and point elsewhere for the rest.
5. **The kept language rules** — Naming, Type System, Mandatory Standards, SonarQube, class/method
   syntax, forbidden functions, encoding, API Symbol Validation, Completeness Verification
   (from the bundled template, scoped to where they apply).
6. **Build and Compilation** — the real toolchain (RDMake via TOTVS Language Server, RPO), honestly.
7. **Tests** — what actually exists (or "no automated runner wired into CI", if true).
8. **Available Skills** — only entries that resolve (validated per the transformation guide §4);
   note availability is environment-dependent.
9. **Fallback escalation chain** — codebase → area CLAUDE.md → root CLAUDE.md → skills/TOTVS docs → ask.

Keep it lean: no restating obvious practices, no enumerating every file, no invented "Tips" sections.

---

## Per-area sub-file skeleton

```markdown
# CLAUDE.md — `server/` (Protheus back-end)

This file provides guidance to Claude Code when working in `server/`. It complements the root
[CLAUDE.md](../CLAUDE.md), whose AdvPL/TLPP language rules **all apply here**. This file covers only
what is specific to this area.

## What this is
<area role in one paragraph>

## <Architecture / layering / conventions specific to this area>
...

## <Build / Tests notes specific to this area, if any>
```

Open by stating it complements the root and which root rules still apply; then cover only the
area-specific architecture, conventions, and guardrails. Cross-link back to the root and to sibling
areas where useful.

---

## Both-file sync invariant

Because `CLAUDE.md` is a symlink to `AGENTS.md`, editing `AGENTS.md` updates both. Never edit the
symlink target name without re-pointing it. If the fallback copy path was used, every edit to
`AGENTS.md` must be mirrored into `CLAUDE.md` — flag this to the user explicitly.
