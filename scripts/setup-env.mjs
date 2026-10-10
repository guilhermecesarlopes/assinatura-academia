// Cria .env e apps/api/.dev.vars a partir do .env.example, com o DATABASE_URL do branch Neon pedido.
// Uso: pnpm setup:env [branch-neon]   (padrão: dev)   --force sobrescreve arquivos existentes.
// A connection string vem do neonctl (login no navegador na primeira vez); nada é impresso no terminal.
import { execSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const PROJECT_ID = 'divine-recipe-77484327';
const args = process.argv.slice(2);
const force = args.includes('--force');
const branch = args.find((a) => !a.startsWith('--')) ?? 'dev';
const targets = ['.env', 'apps/api/.dev.vars'];

const pending = targets.filter((t) => force || !existsSync(t));
if (pending.length === 0) {
  console.log('Arquivos já existem (use --force para sobrescrever):', targets.join(', '));
  process.exit(0);
}

console.log(`Buscando a connection string do branch Neon "${branch}"...`);
const url = execSync(
  `npx --yes neonctl@latest connection-string ${branch} --project-id ${PROJECT_ID} --pooled`,
  { encoding: 'utf8', stdio: ['inherit', 'pipe', 'inherit'] },
).trim();
if (!url.startsWith('postgres')) {
  console.error('Não foi possível obter a connection string.');
  process.exit(1);
}

const content = readFileSync('.env.example', 'utf8').replace(
  /^DATABASE_URL=.*$/m,
  `DATABASE_URL=${url}`,
);
for (const t of pending) {
  writeFileSync(t, content);
  console.log(`Criado: ${t}`);
}
