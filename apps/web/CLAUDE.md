# apps/web — Next.js (App Router)

- Rotas em src/app/; componentes reutilizáveis em src/components/.
- Server Components por padrão; `'use client'` só quando houver estado/evento no navegador.
- Chamadas à API só via src/lib/api.ts, validando a resposta com o schema de @assinatura-academia/contracts.
- Nenhum segredo no front: só variáveis `NEXT_PUBLIC_*` chegam ao navegador.
- Import interno com `@/` (ex.: `@/lib/api`).
