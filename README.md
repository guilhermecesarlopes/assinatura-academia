# Assinatura Academia — API

Back-end: API em `apps/api` (Hono / Cloudflare Workers), banco em `packages/db` (Drizzle + Neon),
contratos em `packages/contracts` (Zod). O front fica em
[assinatura-academia-web](https://github.com/guilhermecesarlopes/assinatura-academia-web) e consome
`packages/contracts` deste repositório (ver [ADR 0003](docs/adr/0003-repos-front-back.md)).

## Começar

```bash
corepack enable
pnpm install
pnpm setup:env                    # cria .env e apps/api/.dev.vars com o branch Neon `dev`
                                  # (outro branch: pnpm setup:env dev-seunome)
pnpm dev                          # api: :8787
```

## Comandos

| Comando            | O que faz                        |
| ------------------ | -------------------------------- |
| `pnpm dev`         | sobe a API                       |
| `pnpm test`        | testes                           |
| `pnpm typecheck`   | checagem de tipos                |
| `pnpm db:generate` | gera migração a partir do schema |
| `pnpm db:migrate`  | aplica migrações                 |

Regras do projeto: [CLAUDE.md](CLAUDE.md). Decisões: [docs/adr](docs/adr).
