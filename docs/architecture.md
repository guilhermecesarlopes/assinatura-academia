# Arquitetura

Monólito modular serverless: um front, uma API, um Postgres.

```
Usuário → Cloudflare (DNS, SSL, WAF, DDoS)
            ├─ apps/web: Next.js
            └─ apps/api: Hono em Workers ──→ Neon Postgres (driver HTTP)
```

## Camadas da API
- routes/: HTTP → valida com Zod → chama service → responde.
- services/: regra de negócio, recebe `db`, sem dependência de HTTP.
- packages/db: schema Drizzle, migrações, cliente.
- packages/contracts: schemas Zod, fonte única dos tipos.

## Ambientes
| Ambiente | Banco | Deploy |
| --- | --- | --- |
| preview | branch Neon por PR | por PR |
| staging | branch Neon `staging` | push em main |
| production | branch Neon `production` | manual, com aprovação |
