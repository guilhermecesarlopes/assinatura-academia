# Assinatura Academia — API

Monorepo pnpm + Turborepo. TypeScript strict. Hono em Cloudflare Workers (apps/api),
Drizzle + Neon Postgres (packages/db), contratos Zod (packages/contracts).
O front (Next.js) está no repositório assinatura-academia-web e importa packages/contracts via Git (docs/adr/0003).

## Comandos

- pnpm dev | pnpm test | pnpm typecheck | pnpm lint | pnpm format
- pnpm db:generate (gera migração a partir do schema) — nunca `drizzle-kit push` fora de dev local

## Regras invioláveis

- Tipos de domínio só em packages/contracts. Não duplicar.
- Toda entrada externa validada com Zod na rota; toda resposta da API validada no front.
- Sem `any`, sem `@ts-ignore`, sem `!` non-null.
- Escrita em múltiplas tabelas = transação.
- Constraints no banco (NOT NULL, FK, UNIQUE, CHECK), não só no código.
- Migração: expand → migrate → contract. Nunca renomear/apagar coluna em uso no mesmo deploy.
- Nunca ler/escrever .env nem logar segredo ou dado pessoal.
- Chamada a LLM só via apps/api/src/services/llm.ts.
- apps/* importam de packages/*; o contrário nunca. services/ não importa nada de HTTP.

## Onde está

- Arquitetura: docs/architecture.md | Decisões: docs/adr/ | Runbooks: docs/runbooks/
- Regras de back: apps/api/CLAUDE.md
- Contrato é API pública do front: mudança em packages/contracts precisa ser compatível com o front em produção.

## Fluxo

Branch `feat|fix|chore/<id-monday>-slug`. PR com título Conventional Commits + `[#<id>]`.
Squash merge. Teste junto com a mudança.
