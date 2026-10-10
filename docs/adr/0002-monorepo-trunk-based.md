# 0002 — Monorepo e trunk-based

Data: 2026-10-10 · Status: aceita

## Decisão
Um repositório (pnpm workspaces + Turborepo). `main` protegida e sempre deployável; branches curtas
(`feat|fix|chore|hotfix/<id-monday>-slug`); squash merge; Conventional Commits no título do PR;
1 aprovação, com SLA de 4h úteis para PRs pequenos (revisão pós-merge permitida).

## Consequências
Uma feature = um PR (front + back + migração). Changelog gerado a partir dos títulos.
