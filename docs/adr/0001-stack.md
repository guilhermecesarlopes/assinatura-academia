# 0001 — Stack

Data: 2026-10-10 · Status: aceita

## Contexto
Time de 2 pessoas, bootstrapped. Prioridades: custo baixo, escala sem reescrita, integridade de dados,
pouco contexto para a IA ler.

## Decisão
TypeScript strict em tudo; Next.js no front; Hono no back (Cloudflare Workers); Neon Postgres + Drizzle;
Zod como contrato compartilhado; Better Auth para autenticação (a implementar).

## Consequências
- Uma linguagem e um sistema de tipos para o time e para o Claude.
- Hono roda em Workers e em Node: saída para containers (Fly.io/Render) sem reescrita.
- Postgres padrão: sai do Neon com `pg_dump` se precisar.
- Pendente: escolher host do front (Cloudflare via OpenNext ou Vercel Pro).
