---
name: research
description: Investigate a question against high-trust primary sources and capture the working findings as a local Markdown note. Use when the user wants a topic researched or docs/API facts gathered.
---

In this pack, research is root-owned. Work locally unless the root explicitly assigns
an open read-only question to a separate top-level coworker session. Never create a
native subagent or background-agent control plane from this skill.

Its job:

1. Investigate the question against **primary sources** — official docs, source code, specs, first-party APIs — not a secondary write-up of them. Follow every claim back to the source that owns it.
2. Write the working findings to a single Markdown file, citing each claim's source.
3. Prefer the ignored `docs/research/` workbench when the repository provides it. Do
   not create that directory as an install/setup step; create it only when a real
   research task needs a note.
4. Treat the note as local working material, not canonical project evidence. When a
   conclusion becomes durable, promote the decision-lossless subset into the repo's
   accepted owner such as an ADR, foundation receipt, `CONTEXT.md`, or governing
   design document. Do not push raw research/process notes merely because the skill
   produced them.
