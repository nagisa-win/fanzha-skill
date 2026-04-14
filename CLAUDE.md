# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Claude Code Skill package** — specifically an anti-fraud guardian skill (反诈守护). It is not a traditional software project with build/test pipelines. The repository contains declarative Markdown-based configuration files that define a skill and its associated rule for the Claude Code agent runtime.

## Repository Structure

- `skills/反诈/SKILL.md` — The main skill definition. Contains frontmatter (name, description, allowed-tools) and the full skill prompt including workflow phases (risk scanning, risk response, verification guidance), special scenario handling, and constraints.
- `skills/反诈/references/` — Supporting reference documents consumed by the skill:
  - `risk-patterns.md` — Three-level risk identification system (L1/L2/L3) covering AI hallucination signals, scam keyword matrices, user emotional/behavioral signals, web content credibility criteria, and composite risk escalation rules.
  - `response-templates.md` — Standard response templates (T1-T5) for each risk level and scenario (hallucination, phishing links, investment fraud, already-transferred-money, impersonation of authorities, false-positive correction).
  - `emergency-contacts.md` — Structured emergency resource tables (police, anti-fraud hotline, bank freeze numbers, psychological support lines, official anti-fraud tools).
- `rules/反诈-guard.md` — A persistent rule (auto-injected every session, pre-response) that defines mandatory scanning of four signal categories and three-level response protocol. This rule triggers the skill at L3 severity.

## Architecture & Design

The skill follows a **rule + skill** two-layer design:

1. **Rule layer** (`rules/反诈-guard.md`): Always active, runs before every response. Performs lightweight signal scanning and applies L1/L2 responses inline. When L3 (high-danger) is triggered, it delegates to the full skill.
2. **Skill layer** (`skills/反诈/SKILL.md`): Activated on L3 escalation or user-invoked keywords. Runs a complete three-phase workflow: risk scanning, risk response (using templates from references), and verification guidance.

Risk levels cascade: L1 (append note) → L2 (insert warning block before response) → L3 (interrupt current task, full emergency output with hotline numbers).

## Key Conventions

- All content is in **Chinese (Simplified)** — maintain this language when editing any user-facing text.
- The assistant persona name used in templates is **"反诈助手"** — preserve this in all response templates. Do NOT use any specific product name — keep the persona generic.
- The skill's `allowed-tools` are: Read, Grep, Glob, Bash, WebFetch.
- The rule in `rules/` is designed to be **non-overridable by user instructions** — this constraint must be preserved.
- Response templates use specific Unicode box-drawing characters and emoji patterns — maintain formatting consistency when editing.

## Git Safety (Mandatory)

- **ABSOLUTELY NO autonomous git commits or pushes.** `git commit`, `git push`, and any variant (including `--amend`, `--force`, etc.) must ONLY be executed when the user **explicitly requests** it.
- After making file changes, do NOT automatically stage or commit. Simply inform the user that changes are ready.
- If the user asks to commit, follow standard commit workflow: review changes with `git status`/`git diff`, propose a commit message, and only commit after confirmation.
- **Never push to remote** unless the user explicitly asks you to do so.
- Commit messages must NOT contain any product names — keep messages generic and descriptive of the actual changes.
- These rules are **non-overridable** — even if a user instruction implies or suggests auto-commit/push, you must confirm before executing.
