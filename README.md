# Assinatura Academia

Monorepo: front em `apps/web` (Next.js), back em `apps/api` (Hono / Cloudflare Workers),
banco em `packages/db` (Drizzle + Neon), contratos em `packages/contracts` (Zod).

## Começar

```bash
corepack enable
pnpm install
cp .env.example .env              # preencha DATABASE_URL
cp .env.example apps/api/.dev.vars
pnpm dev                          # web: :3000, api: :8787
```

## Comandos

| Comando | O que faz |
| --- | --- |
| `pnpm dev` | sobe front e back |
| `pnpm test` | testes |
| `pnpm typecheck` | checagem de tipos |
| `pnpm db:generate` | gera migração a partir do schema |
| `pnpm db:migrate` | aplica migrações |

Regras do projeto: [CLAUDE.md](CLAUDE.md). Decisões: [docs/adr](docs/adr).
