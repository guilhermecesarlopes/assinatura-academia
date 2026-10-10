import { pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { uuidv7 } from 'uuidv7';

// Colunas padrão de toda tabela: id uuid v7 (ordenável, gerado na aplicação) + timestamps.
const base = {
  id: uuid('id')
    .primaryKey()
    .$defaultFn(() => uuidv7()),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
};

// Tabela de exemplo para validar o pipeline de migração. Substituir pelo domínio real.
export const featureFlags = pgTable('feature_flags', {
  ...base,
  key: text('key').notNull().unique(),
  description: text('description'),
  enabledFor: text('enabled_for').notNull().default('none'),
});
