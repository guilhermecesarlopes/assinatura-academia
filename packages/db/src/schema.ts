import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  date,
  doublePrecision,
  index,
  integer,
  jsonb,
  numeric,
  pgEnum,
  pgTable,
  primaryKey,
  smallint,
  text,
  time,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';
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

const tstz = (name: string) => timestamp(name, { withTimezone: true });

// Tabela de exemplo para validar o pipeline de migração.
export const featureFlags = pgTable('feature_flags', {
  ...base,
  key: text('key').notNull().unique(),
  description: text('description'),
  enabledFor: text('enabled_for').notNull().default('none'),
});

// ─── Enums ──────────────────────────────────────────────────────────────────

export const userRole = pgEnum('user_role', ['athlete', 'gym_staff', 'admin']);
export const userStatus = pgEnum('user_status', ['active', 'blocked', 'deleted']);
export const gymStatus = pgEnum('gym_status', ['pending', 'approved', 'rejected', 'suspended']);
export const gymMemberRole = pgEnum('gym_member_role', ['owner', 'manager', 'receptionist']);
export const billingInterval = pgEnum('billing_interval', ['monthly', 'quarterly', 'yearly']);
export const subscriptionStatus = pgEnum('subscription_status', [
  'pending',
  'active',
  'past_due',
  'canceled',
  'expired',
]);
export const checkinSource = pgEnum('checkin_source', ['subscription', 'credit']);
export const checkinStatus = pgEnum('checkin_status', [
  'pending',
  'confirmed',
  'rejected',
  'expired',
  'canceled',
]);
export const confirmationMethod = pgEnum('confirmation_method', ['manual', 'auto']);
export const paymentKind = pgEnum('payment_kind', ['subscription_charge', 'checkin_pack']);
export const paymentMethod = pgEnum('payment_method', ['pix', 'credit_card', 'boleto']);
export const paymentStatus = pgEnum('payment_status', [
  'pending',
  'paid',
  'failed',
  'refunded',
  'canceled',
]);
export const payoutEntryStatus = pgEnum('payout_entry_status', ['accrued', 'settled', 'reversed']);
export const payoutStatus = pgEnum('payout_status', ['open', 'processing', 'paid', 'failed']);
export const workoutSource = pgEnum('workout_source', ['checkin', 'manual']);
export const devicePlatform = pgEnum('device_platform', ['ios', 'android', 'web']);

// ─── Usuários ───────────────────────────────────────────────────────────────
// Sessões/contas do Better Auth entram em tabelas próprias geradas pela lib (ADR 0001).

export const users = pgTable(
  'users',
  {
    ...base,
    role: userRole('role').notNull().default('athlete'),
    status: userStatus('status').notNull().default('active'),
    name: text('name').notNull(),
    email: text('email').notNull(),
    emailVerified: boolean('email_verified').notNull().default(false),
    phone: text('phone'),
    // CPF só com dígitos; exigido pelo Pagar.me para cobrar. Dado pessoal (LGPD): nunca logar.
    document: text('document'),
    birthDate: date('birth_date', { mode: 'string' }),
    sex: text('sex'),
    // Dados de saúde são sensíveis (LGPD art. 11): só gravar health_metrics com consentimento.
    healthConsentAt: tstz('health_consent_at'),
    pagarmeCustomerId: text('pagarme_customer_id'),
  },
  (t) => [
    uniqueIndex('users_email_uq').on(sql`lower(${t.email})`),
    uniqueIndex('users_document_uq').on(t.document),
    check('users_document_digits', sql`${t.document} IS NULL OR ${t.document} ~ '^[0-9]{11}$'`),
    check('users_sex', sql`${t.sex} IS NULL OR ${t.sex} IN ('female', 'male')`),
  ],
);

export const pushTokens = pgTable(
  'push_tokens',
  {
    ...base,
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    token: text('token').notNull().unique(),
    platform: devicePlatform('platform').notNull(),
  },
  (t) => [index('push_tokens_user_idx').on(t.userId)],
);

// ─── Categorias e planos ────────────────────────────────────────────────────
// Bronze < Prata < Ouro: plano de rank N dá acesso a academias de rank <= N.

export const categories = pgTable(
  'categories',
  {
    ...base,
    name: text('name').notNull().unique(),
    rank: smallint('rank').notNull().unique(),
    // Preço do check-in avulso nesta categoria de academia.
    singleCheckinPriceCents: integer('single_checkin_price_cents').notNull(),
  },
  (t) => [
    check('categories_rank_positive', sql`${t.rank} > 0`),
    check('categories_price_positive', sql`${t.singleCheckinPriceCents} > 0`),
  ],
);

export const plans = pgTable(
  'plans',
  {
    ...base,
    categoryId: uuid('category_id')
      .notNull()
      .references(() => categories.id),
    name: text('name').notNull(),
    priceCents: integer('price_cents').notNull(),
    interval: billingInterval('interval').notNull().default('monthly'),
    dailyCheckinLimit: smallint('daily_checkin_limit').notNull().default(1),
    active: boolean('active').notNull().default(true),
    pagarmePlanId: text('pagarme_plan_id').unique(),
  },
  (t) => [
    check('plans_price_positive', sql`${t.priceCents} > 0`),
    check('plans_daily_limit', sql`${t.dailyCheckinLimit} = 1`),
  ],
);

export const subscriptions = pgTable(
  'subscriptions',
  {
    ...base,
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id),
    planId: uuid('plan_id')
      .notNull()
      .references(() => plans.id),
    status: subscriptionStatus('status').notNull().default('pending'),
    currentPeriodStart: tstz('current_period_start'),
    currentPeriodEnd: tstz('current_period_end'),
    canceledAt: tstz('canceled_at'),
    pagarmeSubscriptionId: text('pagarme_subscription_id').unique(),
  },
  (t) => [
    // No máximo uma assinatura viva por atleta.
    uniqueIndex('subscriptions_one_live_per_user')
      .on(t.userId)
      .where(sql`${t.status} IN ('pending', 'active', 'past_due')`),
    check(
      'subscriptions_period',
      sql`${t.currentPeriodEnd} IS NULL OR ${t.currentPeriodEnd} > ${t.currentPeriodStart}`,
    ),
  ],
);

// ─── Academias ──────────────────────────────────────────────────────────────

export const gyms = pgTable(
  'gyms',
  {
    ...base,
    name: text('name').notNull(),
    slug: text('slug').notNull().unique(),
    legalName: text('legal_name'),
    cnpj: text('cnpj').unique(),
    categoryId: uuid('category_id')
      .notNull()
      .references(() => categories.id),
    status: gymStatus('status').notNull().default('pending'),
    phone: text('phone'),
    addressLine: text('address_line').notNull(),
    city: text('city').notNull(),
    state: text('state').notNull(),
    postalCode: text('postal_code').notNull(),
    latitude: doublePrecision('latitude').notNull(),
    longitude: doublePrecision('longitude').notNull(),
    // Raio do geofence do check-in.
    checkinRadiusM: smallint('checkin_radius_m').notNull().default(150),
    // Capacidade padrão por slot de 1h quando não há regra específica (limite_hora).
    defaultHourlyCapacity: smallint('default_hourly_capacity').notNull(),
    // true = check-in confirmado sem a recepção (só GPS + capacidade).
    autoConfirm: boolean('auto_confirm').notNull().default(false),
    timezone: text('timezone').notNull().default('America/Sao_Paulo'),
    pagarmeRecipientId: text('pagarme_recipient_id').unique(),
    approvedAt: tstz('approved_at'),
    approvedBy: uuid('approved_by').references(() => users.id),
  },
  (t) => [
    index('gyms_status_category_idx').on(t.status, t.categoryId),
    index('gyms_lat_lng_idx').on(t.latitude, t.longitude),
    check('gyms_lat', sql`${t.latitude} BETWEEN -90 AND 90`),
    check('gyms_lng', sql`${t.longitude} BETWEEN -180 AND 180`),
    check('gyms_radius', sql`${t.checkinRadiusM} BETWEEN 30 AND 1000`),
    check('gyms_capacity', sql`${t.defaultHourlyCapacity} > 0`),
    check('gyms_cnpj_digits', sql`${t.cnpj} IS NULL OR ${t.cnpj} ~ '^[0-9]{14}$'`),
    check(
      'gyms_approved',
      sql`${t.status} <> 'approved' OR (${t.approvedAt} IS NOT NULL AND ${t.pagarmeRecipientId} IS NOT NULL)`,
    ),
  ],
);

export const gymMembers = pgTable(
  'gym_members',
  {
    gymId: uuid('gym_id')
      .notNull()
      .references(() => gyms.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    role: gymMemberRole('role').notNull(),
    createdAt: tstz('created_at').notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.gymId, t.userId] }), index('gym_members_user_idx').on(t.userId)],
);

export const modalities = pgTable('modalities', {
  ...base,
  name: text('name').notNull().unique(),
});

export const gymModalities = pgTable(
  'gym_modalities',
  {
    gymId: uuid('gym_id')
      .notNull()
      .references(() => gyms.id, { onDelete: 'cascade' }),
    modalityId: uuid('modality_id')
      .notNull()
      .references(() => modalities.id),
  },
  (t) => [primaryKey({ columns: [t.gymId, t.modalityId] })],
);

// Capacidade por faixa de horário e dia da semana (0 = domingo). Sem regra → default_hourly_capacity.
export const gymCapacityRules = pgTable(
  'gym_capacity_rules',
  {
    ...base,
    gymId: uuid('gym_id')
      .notNull()
      .references(() => gyms.id, { onDelete: 'cascade' }),
    weekday: smallint('weekday').notNull(),
    startTime: time('start_time').notNull(),
    endTime: time('end_time').notNull(),
    capacity: smallint('capacity').notNull(),
  },
  (t) => [
    index('gym_capacity_rules_gym_idx').on(t.gymId, t.weekday),
    check('gym_capacity_rules_weekday', sql`${t.weekday} BETWEEN 0 AND 6`),
    check('gym_capacity_rules_range', sql`${t.endTime} > ${t.startTime}`),
    check('gym_capacity_rules_capacity', sql`${t.capacity} >= 0`),
  ],
);

// Ocupação por slot de 1h. Reserva atômica num único UPDATE (driver HTTP do Neon não tem
// transação interativa): UPDATE ... SET used = used + 1 WHERE used < capacity RETURNING.
export const gymSlotOccupancy = pgTable(
  'gym_slot_occupancy',
  {
    gymId: uuid('gym_id')
      .notNull()
      .references(() => gyms.id, { onDelete: 'cascade' }),
    slotStart: tstz('slot_start').notNull(),
    capacity: smallint('capacity').notNull(),
    used: smallint('used').notNull().default(0),
  },
  (t) => [
    primaryKey({ columns: [t.gymId, t.slotStart] }),
    check('gym_slot_occupancy_used', sql`${t.used} >= 0 AND ${t.used} <= ${t.capacity}`),
    check('gym_slot_occupancy_hour', sql`date_trunc('hour', ${t.slotStart}) = ${t.slotStart}`),
  ],
);

// ─── Pagamentos (Pagar.me) ──────────────────────────────────────────────────

export const payments = pgTable(
  'payments',
  {
    ...base,
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id),
    kind: paymentKind('kind').notNull(),
    subscriptionId: uuid('subscription_id').references(() => subscriptions.id),
    method: paymentMethod('method').notNull(),
    status: paymentStatus('status').notNull().default('pending'),
    amountCents: integer('amount_cents').notNull(),
    pagarmeOrderId: text('pagarme_order_id'),
    pagarmeChargeId: text('pagarme_charge_id').unique(),
    paidAt: tstz('paid_at'),
    failureReason: text('failure_reason'),
  },
  (t) => [
    index('payments_user_idx').on(t.userId, t.createdAt),
    check('payments_amount_positive', sql`${t.amountCents} > 0`),
    check(
      'payments_kind_subscription',
      sql`(${t.kind} = 'subscription_charge') = (${t.subscriptionId} IS NOT NULL)`,
    ),
    check('payments_paid_at', sql`${t.status} <> 'paid' OR ${t.paidAt} IS NOT NULL`),
  ],
);

// Regras de split enviadas ao Pagar.me na cobrança (gym_id NULL = plataforma).
export const paymentSplits = pgTable(
  'payment_splits',
  {
    ...base,
    paymentId: uuid('payment_id')
      .notNull()
      .references(() => payments.id, { onDelete: 'cascade' }),
    gymId: uuid('gym_id').references(() => gyms.id),
    pagarmeRecipientId: text('pagarme_recipient_id').notNull(),
    amountCents: integer('amount_cents').notNull(),
  },
  (t) => [
    index('payment_splits_payment_idx').on(t.paymentId),
    check('payment_splits_amount', sql`${t.amountCents} >= 0`),
  ],
);

// Pacotes de check-in avulso comprados (válidos em academias até a categoria indicada).
export const checkinCredits = pgTable(
  'checkin_credits',
  {
    ...base,
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id),
    paymentId: uuid('payment_id')
      .notNull()
      .unique()
      .references(() => payments.id),
    categoryId: uuid('category_id')
      .notNull()
      .references(() => categories.id),
    quantityTotal: smallint('quantity_total').notNull(),
    quantityUsed: smallint('quantity_used').notNull().default(0),
    expiresAt: tstz('expires_at').notNull(),
  },
  (t) => [
    index('checkin_credits_user_idx').on(t.userId, t.expiresAt),
    check(
      'checkin_credits_quantity',
      sql`${t.quantityTotal} > 0 AND ${t.quantityUsed} >= 0 AND ${t.quantityUsed} <= ${t.quantityTotal}`,
    ),
  ],
);

// Valor do repasse por check-in confirmado, por categoria, com vigência (parametrizado pelo admin).
export const payoutRules = pgTable(
  'payout_rules',
  {
    ...base,
    categoryId: uuid('category_id')
      .notNull()
      .references(() => categories.id),
    amountPerCheckinCents: integer('amount_per_checkin_cents').notNull(),
    effectiveFrom: date('effective_from', { mode: 'string' }).notNull(),
    createdBy: uuid('created_by')
      .notNull()
      .references(() => users.id),
  },
  (t) => [
    uniqueIndex('payout_rules_category_from_uq').on(t.categoryId, t.effectiveFrom),
    check('payout_rules_amount', sql`${t.amountPerCheckinCents} >= 0`),
  ],
);

export const payouts = pgTable(
  'payouts',
  {
    ...base,
    gymId: uuid('gym_id')
      .notNull()
      .references(() => gyms.id),
    periodStart: date('period_start', { mode: 'string' }).notNull(),
    periodEnd: date('period_end', { mode: 'string' }).notNull(),
    totalCents: integer('total_cents').notNull(),
    status: payoutStatus('status').notNull().default('open'),
    pagarmeTransferId: text('pagarme_transfer_id').unique(),
    paidAt: tstz('paid_at'),
  },
  (t) => [
    uniqueIndex('payouts_gym_period_uq').on(t.gymId, t.periodStart),
    check('payouts_period', sql`${t.periodEnd} >= ${t.periodStart}`),
    check('payouts_total', sql`${t.totalCents} >= 0`),
  ],
);

// ─── Check-ins ──────────────────────────────────────────────────────────────

export const checkins = pgTable(
  'checkins',
  {
    ...base,
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id),
    gymId: uuid('gym_id')
      .notNull()
      .references(() => gyms.id),
    source: checkinSource('source').notNull(),
    subscriptionId: uuid('subscription_id').references(() => subscriptions.id),
    creditId: uuid('credit_id').references(() => checkinCredits.id),
    status: checkinStatus('status').notNull().default('pending'),
    // Coordenadas enviadas pelo app e distância calculada no servidor (antifraude).
    latitude: doublePrecision('latitude').notNull(),
    longitude: doublePrecision('longitude').notNull(),
    gpsAccuracyM: smallint('gps_accuracy_m'),
    distanceM: smallint('distance_m').notNull(),
    // Dia local da academia: base do limite de 1 check-in/dia.
    localDate: date('local_date', { mode: 'string' }).notNull(),
    slotStart: tstz('slot_start').notNull(),
    expiresAt: tstz('expires_at').notNull(),
    confirmedAt: tstz('confirmed_at'),
    confirmedBy: uuid('confirmed_by').references(() => users.id),
    confirmationMethod: confirmationMethod('confirmation_method'),
    rejectionReason: text('rejection_reason'),
  },
  (t) => [
    // Limite rígido: 1 check-in vivo por assinatura por dia.
    uniqueIndex('checkins_one_per_day_per_subscription')
      .on(t.subscriptionId, t.localDate)
      .where(sql`${t.source} = 'subscription' AND ${t.status} IN ('pending', 'confirmed')`),
    // Fila da recepção e job de expiração.
    index('checkins_gym_pending_idx')
      .on(t.gymId, t.expiresAt)
      .where(sql`${t.status} = 'pending'`),
    index('checkins_user_idx').on(t.userId, t.createdAt),
    check(
      'checkins_source_ref',
      sql`(${t.source} = 'subscription' AND ${t.subscriptionId} IS NOT NULL AND ${t.creditId} IS NULL)
        OR (${t.source} = 'credit' AND ${t.creditId} IS NOT NULL AND ${t.subscriptionId} IS NULL)`,
    ),
    check('checkins_expires', sql`${t.expiresAt} > ${t.createdAt}`),
    check(
      'checkins_confirmed',
      sql`${t.status} <> 'confirmed' OR (${t.confirmedAt} IS NOT NULL AND ${t.confirmationMethod} IS NOT NULL)`,
    ),
    check(
      'checkins_manual_by',
      sql`${t.confirmationMethod} IS DISTINCT FROM 'manual' OR ${t.confirmedBy} IS NOT NULL`,
    ),
  ],
);

// Razão de repasse: 1 lançamento por check-in confirmado; liquidado em lote (payouts).
export const payoutEntries = pgTable(
  'payout_entries',
  {
    ...base,
    checkinId: uuid('checkin_id')
      .notNull()
      .unique()
      .references(() => checkins.id),
    gymId: uuid('gym_id')
      .notNull()
      .references(() => gyms.id),
    amountCents: integer('amount_cents').notNull(),
    status: payoutEntryStatus('status').notNull().default('accrued'),
    payoutId: uuid('payout_id').references(() => payouts.id),
  },
  (t) => [
    index('payout_entries_gym_status_idx').on(t.gymId, t.status),
    check('payout_entries_amount', sql`${t.amountCents} >= 0`),
    check('payout_entries_settled', sql`${t.status} <> 'settled' OR ${t.payoutId} IS NOT NULL`),
  ],
);

// Idempotência dos webhooks do Pagar.me (o mesmo evento pode chegar mais de uma vez).
export const webhookEvents = pgTable('webhook_events', {
  ...base,
  provider: text('provider').notNull().default('pagarme'),
  eventId: text('event_id').notNull().unique(),
  type: text('type').notNull(),
  payload: jsonb('payload').notNull(),
  processedAt: tstz('processed_at'),
  error: text('error'),
});

// ─── Atleta: treinos e saúde ────────────────────────────────────────────────

export const workouts = pgTable(
  'workouts',
  {
    ...base,
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    checkinId: uuid('checkin_id')
      .unique()
      .references(() => checkins.id),
    gymId: uuid('gym_id').references(() => gyms.id),
    modalityId: uuid('modality_id').references(() => modalities.id),
    source: workoutSource('source').notNull(),
    startedAt: tstz('started_at').notNull(),
    durationMin: smallint('duration_min').notNull().default(60),
    notes: text('notes'),
  },
  (t) => [
    index('workouts_user_idx').on(t.userId, t.startedAt),
    check('workouts_duration', sql`${t.durationMin} BETWEEN 1 AND 600`),
    check('workouts_source_ref', sql`(${t.source} = 'checkin') = (${t.checkinId} IS NOT NULL)`),
  ],
);

export const healthMetrics = pgTable(
  'health_metrics',
  {
    ...base,
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    measuredAt: tstz('measured_at').notNull(),
    weightKg: numeric('weight_kg', { precision: 5, scale: 2, mode: 'number' }).notNull(),
    heightCm: numeric('height_cm', { precision: 4, scale: 1, mode: 'number' }).notNull(),
    // IMC calculado pelo banco: peso / altura².
    bmi: numeric('bmi', { precision: 4, scale: 1, mode: 'number' }).generatedAlwaysAs(
      sql`round(weight_kg / ((height_cm / 100) * (height_cm / 100)), 1)`,
    ),
    // % de gordura informada (bioimpedância) ou estimada no app (método registrado).
    bodyFatPct: numeric('body_fat_pct', { precision: 4, scale: 1, mode: 'number' }),
    bodyFatMethod: text('body_fat_method'),
  },
  (t) => [
    index('health_metrics_user_idx').on(t.userId, t.measuredAt),
    check('health_metrics_weight', sql`${t.weightKg} BETWEEN 20 AND 400`),
    check('health_metrics_height', sql`${t.heightCm} BETWEEN 100 AND 250`),
    check('health_metrics_fat', sql`${t.bodyFatPct} IS NULL OR ${t.bodyFatPct} BETWEEN 2 AND 70`),
    check(
      'health_metrics_fat_method',
      sql`${t.bodyFatMethod} IS NULL OR ${t.bodyFatMethod} IN ('reported', 'deurenberg', 'navy')`,
    ),
  ],
);

// ─── Auditoria (ações do admin e da academia) ───────────────────────────────

export const auditLogs = pgTable(
  'audit_logs',
  {
    ...base,
    actorId: uuid('actor_id').references(() => users.id),
    action: text('action').notNull(),
    entity: text('entity').notNull(),
    entityId: uuid('entity_id'),
    // Nunca gravar segredo ou dado pessoal aqui.
    metadata: jsonb('metadata'),
  },
  (t) => [index('audit_logs_entity_idx').on(t.entity, t.entityId)],
);
