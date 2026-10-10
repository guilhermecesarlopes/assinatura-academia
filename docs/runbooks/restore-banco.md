# Runbook — Restaurar o banco

1. No console do Neon, criar um branch a partir do ponto no tempo desejado (antes do incidente).
2. Validar os dados nesse branch (consultas de sanidade).
3. Apontar `DATABASE_URL` do ambiente afetado para o branch restaurado (GitHub Environment + `wrangler secret put`).
4. Registrar o incidente e testar este runbook de novo no próximo trimestre.
