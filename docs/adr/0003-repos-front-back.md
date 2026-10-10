# 0003 — Front e back em repositórios separados

Data: 2026-10-10 · Status: aceita · Substitui em parte: [0002](0002-monorepo-trunk-based.md)

## Decisão

Dois repositórios:

- `assinatura-academia-api`: `apps/api`, `packages/db`, `packages/contracts`, `packages/config`
  (continua um workspace pnpm + Turborepo).
- `assinatura-academia-web`: o Next.js na raiz.

`packages/contracts` continua sendo a fonte única dos tipos. O front instala o pacote direto deste
repositório via Git (`github:guilhermecesarlopes/assinatura-academia-api#path:/packages/contracts`),
sem copiar código. O resto do ADR 0002 (trunk-based, branches curtas, squash merge) vale para os dois.

## Consequências

- Feature que muda contrato: PR na API primeiro; depois PR no front atualizando o lockfile
  (`pnpm update @assinatura-academia/contracts`).
- Mudança de contrato precisa ser compatível com o front em produção (mesma regra de expand → contract).
- Deploy de front e back independentes.
