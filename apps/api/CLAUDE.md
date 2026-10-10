# apps/api — Hono em Cloudflare Workers

- Uma rota por recurso em src/routes/<recurso>.ts; montar em src/index.ts.
- Validar body/query/params com `zValidator` + schema de @assinatura-academia/contracts. Nunca confiar em entrada.
- Regra de negócio em src/services/ (funções puras que recebem `db`); rotas só traduzem HTTP.
- Banco: `createDb(c.env.DATABASE_URL)` de @assinatura-academia/db. Escrita em várias tabelas = `db.transaction`.
- Erros: lançar `HTTPException`; o handler em middleware/error.ts formata. Nunca expor stack.
- Novo segredo/variável: declarar em src/env.ts e em wrangler.toml (vars) ou `wrangler secret put`.
- Teste junto: test/<recurso>.test.ts usando `app.request(...)`.
