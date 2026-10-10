# Arquitetura

Monólito modular serverless: um front, uma API, um Postgres. Front e back em repositórios separados
(ver [ADR 0003](adr/0003-repos-front-back.md)).

```
Usuário → Cloudflare (DNS, SSL, WAF, DDoS)
            ├─ assinatura-academia-web: Next.js
            └─ assinatura-academia-api (apps/api): Hono em Workers ──→ Neon Postgres (driver HTTP)
```

## Camadas da API

- routes/: HTTP → valida com Zod → chama service → responde.
- services/: regra de negócio, recebe `db`, sem dependência de HTTP.
- packages/db: schema Drizzle, migrações, cliente.
- packages/contracts: schemas Zod, fonte única dos tipos. O front instala via Git.

## Ambientes

| Ambiente    | Banco                    | Deploy                                                    |
| ----------- | ------------------------ | --------------------------------------------------------- |
| dev (local) | branch Neon `dev`        | —                                                         |
| staging     | branch Neon `staging`    | push em main (Cloudflare Workers Builds; migração manual) |
| production  | branch Neon `production` | manual, com aprovação                                     |
