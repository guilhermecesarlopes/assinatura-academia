CREATE TYPE "public"."billing_interval" AS ENUM('monthly', 'quarterly', 'yearly');--> statement-breakpoint
CREATE TYPE "public"."checkin_source" AS ENUM('subscription', 'credit');--> statement-breakpoint
CREATE TYPE "public"."checkin_status" AS ENUM('pending', 'confirmed', 'rejected', 'expired', 'canceled');--> statement-breakpoint
CREATE TYPE "public"."confirmation_method" AS ENUM('manual', 'auto');--> statement-breakpoint
CREATE TYPE "public"."device_platform" AS ENUM('ios', 'android', 'web');--> statement-breakpoint
CREATE TYPE "public"."gym_member_role" AS ENUM('owner', 'manager', 'receptionist');--> statement-breakpoint
CREATE TYPE "public"."gym_status" AS ENUM('pending', 'approved', 'rejected', 'suspended');--> statement-breakpoint
CREATE TYPE "public"."payment_kind" AS ENUM('subscription_charge', 'checkin_pack');--> statement-breakpoint
CREATE TYPE "public"."payment_method" AS ENUM('pix', 'credit_card', 'boleto');--> statement-breakpoint
CREATE TYPE "public"."payment_status" AS ENUM('pending', 'paid', 'failed', 'refunded', 'canceled');--> statement-breakpoint
CREATE TYPE "public"."payout_entry_status" AS ENUM('accrued', 'settled', 'reversed');--> statement-breakpoint
CREATE TYPE "public"."payout_status" AS ENUM('open', 'processing', 'paid', 'failed');--> statement-breakpoint
CREATE TYPE "public"."subscription_status" AS ENUM('pending', 'active', 'past_due', 'canceled', 'expired');--> statement-breakpoint
CREATE TYPE "public"."user_role" AS ENUM('athlete', 'gym_staff', 'admin');--> statement-breakpoint
CREATE TYPE "public"."user_status" AS ENUM('active', 'blocked', 'deleted');--> statement-breakpoint
CREATE TYPE "public"."workout_source" AS ENUM('checkin', 'manual');--> statement-breakpoint
CREATE TABLE "audit_logs" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"actor_id" uuid,
	"action" text NOT NULL,
	"entity" text NOT NULL,
	"entity_id" uuid,
	"metadata" jsonb
);
--> statement-breakpoint
CREATE TABLE "categories" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"name" text NOT NULL,
	"rank" smallint NOT NULL,
	"single_checkin_price_cents" integer NOT NULL,
	CONSTRAINT "categories_name_unique" UNIQUE("name"),
	CONSTRAINT "categories_rank_unique" UNIQUE("rank"),
	CONSTRAINT "categories_rank_positive" CHECK ("categories"."rank" > 0),
	CONSTRAINT "categories_price_positive" CHECK ("categories"."single_checkin_price_cents" > 0)
);
--> statement-breakpoint
CREATE TABLE "checkin_credits" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"user_id" uuid NOT NULL,
	"payment_id" uuid NOT NULL,
	"category_id" uuid NOT NULL,
	"quantity_total" smallint NOT NULL,
	"quantity_used" smallint DEFAULT 0 NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	CONSTRAINT "checkin_credits_payment_id_unique" UNIQUE("payment_id"),
	CONSTRAINT "checkin_credits_quantity" CHECK ("checkin_credits"."quantity_total" > 0 AND "checkin_credits"."quantity_used" >= 0 AND "checkin_credits"."quantity_used" <= "checkin_credits"."quantity_total")
);
--> statement-breakpoint
CREATE TABLE "checkins" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"user_id" uuid NOT NULL,
	"gym_id" uuid NOT NULL,
	"source" "checkin_source" NOT NULL,
	"subscription_id" uuid,
	"credit_id" uuid,
	"status" "checkin_status" DEFAULT 'pending' NOT NULL,
	"latitude" double precision NOT NULL,
	"longitude" double precision NOT NULL,
	"gps_accuracy_m" smallint,
	"distance_m" smallint NOT NULL,
	"local_date" date NOT NULL,
	"slot_start" timestamp with time zone NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"confirmed_at" timestamp with time zone,
	"confirmed_by" uuid,
	"confirmation_method" "confirmation_method",
	"rejection_reason" text,
	CONSTRAINT "checkins_source_ref" CHECK (("checkins"."source" = 'subscription' AND "checkins"."subscription_id" IS NOT NULL AND "checkins"."credit_id" IS NULL)
        OR ("checkins"."source" = 'credit' AND "checkins"."credit_id" IS NOT NULL AND "checkins"."subscription_id" IS NULL)),
	CONSTRAINT "checkins_expires" CHECK ("checkins"."expires_at" > "checkins"."created_at"),
	CONSTRAINT "checkins_confirmed" CHECK ("checkins"."status" <> 'confirmed' OR ("checkins"."confirmed_at" IS NOT NULL AND "checkins"."confirmation_method" IS NOT NULL)),
	CONSTRAINT "checkins_manual_by" CHECK ("checkins"."confirmation_method" IS DISTINCT FROM 'manual' OR "checkins"."confirmed_by" IS NOT NULL)
);
--> statement-breakpoint
CREATE TABLE "gym_capacity_rules" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"gym_id" uuid NOT NULL,
	"weekday" smallint NOT NULL,
	"start_time" time NOT NULL,
	"end_time" time NOT NULL,
	"capacity" smallint NOT NULL,
	CONSTRAINT "gym_capacity_rules_weekday" CHECK ("gym_capacity_rules"."weekday" BETWEEN 0 AND 6),
	CONSTRAINT "gym_capacity_rules_range" CHECK ("gym_capacity_rules"."end_time" > "gym_capacity_rules"."start_time"),
	CONSTRAINT "gym_capacity_rules_capacity" CHECK ("gym_capacity_rules"."capacity" >= 0)
);
--> statement-breakpoint
CREATE TABLE "gym_members" (
	"gym_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"role" "gym_member_role" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "gym_members_gym_id_user_id_pk" PRIMARY KEY("gym_id","user_id")
);
--> statement-breakpoint
CREATE TABLE "gym_modalities" (
	"gym_id" uuid NOT NULL,
	"modality_id" uuid NOT NULL,
	CONSTRAINT "gym_modalities_gym_id_modality_id_pk" PRIMARY KEY("gym_id","modality_id")
);
--> statement-breakpoint
CREATE TABLE "gym_slot_occupancy" (
	"gym_id" uuid NOT NULL,
	"slot_start" timestamp with time zone NOT NULL,
	"capacity" smallint NOT NULL,
	"used" smallint DEFAULT 0 NOT NULL,
	CONSTRAINT "gym_slot_occupancy_gym_id_slot_start_pk" PRIMARY KEY("gym_id","slot_start"),
	CONSTRAINT "gym_slot_occupancy_used" CHECK ("gym_slot_occupancy"."used" >= 0 AND "gym_slot_occupancy"."used" <= "gym_slot_occupancy"."capacity"),
	CONSTRAINT "gym_slot_occupancy_hour" CHECK (date_trunc('hour', "gym_slot_occupancy"."slot_start") = "gym_slot_occupancy"."slot_start")
);
--> statement-breakpoint
CREATE TABLE "gyms" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"name" text NOT NULL,
	"slug" text NOT NULL,
	"legal_name" text,
	"cnpj" text,
	"category_id" uuid NOT NULL,
	"status" "gym_status" DEFAULT 'pending' NOT NULL,
	"phone" text,
	"address_line" text NOT NULL,
	"city" text NOT NULL,
	"state" text NOT NULL,
	"postal_code" text NOT NULL,
	"latitude" double precision NOT NULL,
	"longitude" double precision NOT NULL,
	"checkin_radius_m" smallint DEFAULT 150 NOT NULL,
	"default_hourly_capacity" smallint NOT NULL,
	"auto_confirm" boolean DEFAULT false NOT NULL,
	"timezone" text DEFAULT 'America/Sao_Paulo' NOT NULL,
	"pagarme_recipient_id" text,
	"approved_at" timestamp with time zone,
	"approved_by" uuid,
	CONSTRAINT "gyms_slug_unique" UNIQUE("slug"),
	CONSTRAINT "gyms_cnpj_unique" UNIQUE("cnpj"),
	CONSTRAINT "gyms_pagarme_recipient_id_unique" UNIQUE("pagarme_recipient_id"),
	CONSTRAINT "gyms_lat" CHECK ("gyms"."latitude" BETWEEN -90 AND 90),
	CONSTRAINT "gyms_lng" CHECK ("gyms"."longitude" BETWEEN -180 AND 180),
	CONSTRAINT "gyms_radius" CHECK ("gyms"."checkin_radius_m" BETWEEN 30 AND 1000),
	CONSTRAINT "gyms_capacity" CHECK ("gyms"."default_hourly_capacity" > 0),
	CONSTRAINT "gyms_cnpj_digits" CHECK ("gyms"."cnpj" IS NULL OR "gyms"."cnpj" ~ '^[0-9]{14}$'),
	CONSTRAINT "gyms_approved" CHECK ("gyms"."status" <> 'approved' OR ("gyms"."approved_at" IS NOT NULL AND "gyms"."pagarme_recipient_id" IS NOT NULL))
);
--> statement-breakpoint
CREATE TABLE "health_metrics" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"user_id" uuid NOT NULL,
	"measured_at" timestamp with time zone NOT NULL,
	"weight_kg" numeric(5, 2) NOT NULL,
	"height_cm" numeric(4, 1) NOT NULL,
	"bmi" numeric(4, 1) GENERATED ALWAYS AS (round(weight_kg / ((height_cm / 100) * (height_cm / 100)), 1)) STORED,
	"body_fat_pct" numeric(4, 1),
	"body_fat_method" text,
	CONSTRAINT "health_metrics_weight" CHECK ("health_metrics"."weight_kg" BETWEEN 20 AND 400),
	CONSTRAINT "health_metrics_height" CHECK ("health_metrics"."height_cm" BETWEEN 100 AND 250),
	CONSTRAINT "health_metrics_fat" CHECK ("health_metrics"."body_fat_pct" IS NULL OR "health_metrics"."body_fat_pct" BETWEEN 2 AND 70),
	CONSTRAINT "health_metrics_fat_method" CHECK ("health_metrics"."body_fat_method" IS NULL OR "health_metrics"."body_fat_method" IN ('reported', 'deurenberg', 'navy'))
);
--> statement-breakpoint
CREATE TABLE "modalities" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"name" text NOT NULL,
	CONSTRAINT "modalities_name_unique" UNIQUE("name")
);
--> statement-breakpoint
CREATE TABLE "payment_splits" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"payment_id" uuid NOT NULL,
	"gym_id" uuid,
	"pagarme_recipient_id" text NOT NULL,
	"amount_cents" integer NOT NULL,
	CONSTRAINT "payment_splits_amount" CHECK ("payment_splits"."amount_cents" >= 0)
);
--> statement-breakpoint
CREATE TABLE "payments" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"user_id" uuid NOT NULL,
	"kind" "payment_kind" NOT NULL,
	"subscription_id" uuid,
	"method" "payment_method" NOT NULL,
	"status" "payment_status" DEFAULT 'pending' NOT NULL,
	"amount_cents" integer NOT NULL,
	"pagarme_order_id" text,
	"pagarme_charge_id" text,
	"paid_at" timestamp with time zone,
	"failure_reason" text,
	CONSTRAINT "payments_pagarme_charge_id_unique" UNIQUE("pagarme_charge_id"),
	CONSTRAINT "payments_amount_positive" CHECK ("payments"."amount_cents" > 0),
	CONSTRAINT "payments_kind_subscription" CHECK (("payments"."kind" = 'subscription_charge') = ("payments"."subscription_id" IS NOT NULL)),
	CONSTRAINT "payments_paid_at" CHECK ("payments"."status" <> 'paid' OR "payments"."paid_at" IS NOT NULL)
);
--> statement-breakpoint
CREATE TABLE "payout_entries" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"checkin_id" uuid NOT NULL,
	"gym_id" uuid NOT NULL,
	"amount_cents" integer NOT NULL,
	"status" "payout_entry_status" DEFAULT 'accrued' NOT NULL,
	"payout_id" uuid,
	CONSTRAINT "payout_entries_checkin_id_unique" UNIQUE("checkin_id"),
	CONSTRAINT "payout_entries_amount" CHECK ("payout_entries"."amount_cents" >= 0),
	CONSTRAINT "payout_entries_settled" CHECK ("payout_entries"."status" <> 'settled' OR "payout_entries"."payout_id" IS NOT NULL)
);
--> statement-breakpoint
CREATE TABLE "payout_rules" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"category_id" uuid NOT NULL,
	"amount_per_checkin_cents" integer NOT NULL,
	"effective_from" date NOT NULL,
	"created_by" uuid NOT NULL,
	CONSTRAINT "payout_rules_amount" CHECK ("payout_rules"."amount_per_checkin_cents" >= 0)
);
--> statement-breakpoint
CREATE TABLE "payouts" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"gym_id" uuid NOT NULL,
	"period_start" date NOT NULL,
	"period_end" date NOT NULL,
	"total_cents" integer NOT NULL,
	"status" "payout_status" DEFAULT 'open' NOT NULL,
	"pagarme_transfer_id" text,
	"paid_at" timestamp with time zone,
	CONSTRAINT "payouts_pagarme_transfer_id_unique" UNIQUE("pagarme_transfer_id"),
	CONSTRAINT "payouts_period" CHECK ("payouts"."period_end" >= "payouts"."period_start"),
	CONSTRAINT "payouts_total" CHECK ("payouts"."total_cents" >= 0)
);
--> statement-breakpoint
CREATE TABLE "plans" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"category_id" uuid NOT NULL,
	"name" text NOT NULL,
	"price_cents" integer NOT NULL,
	"interval" "billing_interval" DEFAULT 'monthly' NOT NULL,
	"daily_checkin_limit" smallint DEFAULT 1 NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"pagarme_plan_id" text,
	CONSTRAINT "plans_pagarme_plan_id_unique" UNIQUE("pagarme_plan_id"),
	CONSTRAINT "plans_price_positive" CHECK ("plans"."price_cents" > 0),
	CONSTRAINT "plans_daily_limit" CHECK ("plans"."daily_checkin_limit" = 1)
);
--> statement-breakpoint
CREATE TABLE "push_tokens" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"user_id" uuid NOT NULL,
	"token" text NOT NULL,
	"platform" "device_platform" NOT NULL,
	CONSTRAINT "push_tokens_token_unique" UNIQUE("token")
);
--> statement-breakpoint
CREATE TABLE "subscriptions" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"user_id" uuid NOT NULL,
	"plan_id" uuid NOT NULL,
	"status" "subscription_status" DEFAULT 'pending' NOT NULL,
	"current_period_start" timestamp with time zone,
	"current_period_end" timestamp with time zone,
	"canceled_at" timestamp with time zone,
	"pagarme_subscription_id" text,
	CONSTRAINT "subscriptions_pagarme_subscription_id_unique" UNIQUE("pagarme_subscription_id"),
	CONSTRAINT "subscriptions_period" CHECK ("subscriptions"."current_period_end" IS NULL OR "subscriptions"."current_period_end" > "subscriptions"."current_period_start")
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"role" "user_role" DEFAULT 'athlete' NOT NULL,
	"status" "user_status" DEFAULT 'active' NOT NULL,
	"name" text NOT NULL,
	"email" text NOT NULL,
	"email_verified" boolean DEFAULT false NOT NULL,
	"phone" text,
	"document" text,
	"birth_date" date,
	"sex" text,
	"health_consent_at" timestamp with time zone,
	"pagarme_customer_id" text,
	CONSTRAINT "users_document_digits" CHECK ("users"."document" IS NULL OR "users"."document" ~ '^[0-9]{11}$'),
	CONSTRAINT "users_sex" CHECK ("users"."sex" IS NULL OR "users"."sex" IN ('female', 'male'))
);
--> statement-breakpoint
CREATE TABLE "webhook_events" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"provider" text DEFAULT 'pagarme' NOT NULL,
	"event_id" text NOT NULL,
	"type" text NOT NULL,
	"payload" jsonb NOT NULL,
	"processed_at" timestamp with time zone,
	"error" text,
	CONSTRAINT "webhook_events_event_id_unique" UNIQUE("event_id")
);
--> statement-breakpoint
CREATE TABLE "workouts" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"user_id" uuid NOT NULL,
	"checkin_id" uuid,
	"gym_id" uuid,
	"modality_id" uuid,
	"source" "workout_source" NOT NULL,
	"started_at" timestamp with time zone NOT NULL,
	"duration_min" smallint DEFAULT 60 NOT NULL,
	"notes" text,
	CONSTRAINT "workouts_checkin_id_unique" UNIQUE("checkin_id"),
	CONSTRAINT "workouts_duration" CHECK ("workouts"."duration_min" BETWEEN 1 AND 600),
	CONSTRAINT "workouts_source_ref" CHECK (("workouts"."source" = 'checkin') = ("workouts"."checkin_id" IS NOT NULL))
);
--> statement-breakpoint
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_actor_id_users_id_fk" FOREIGN KEY ("actor_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "checkin_credits" ADD CONSTRAINT "checkin_credits_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "checkin_credits" ADD CONSTRAINT "checkin_credits_payment_id_payments_id_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "checkin_credits" ADD CONSTRAINT "checkin_credits_category_id_categories_id_fk" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "checkins" ADD CONSTRAINT "checkins_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "checkins" ADD CONSTRAINT "checkins_gym_id_gyms_id_fk" FOREIGN KEY ("gym_id") REFERENCES "public"."gyms"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "checkins" ADD CONSTRAINT "checkins_subscription_id_subscriptions_id_fk" FOREIGN KEY ("subscription_id") REFERENCES "public"."subscriptions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "checkins" ADD CONSTRAINT "checkins_credit_id_checkin_credits_id_fk" FOREIGN KEY ("credit_id") REFERENCES "public"."checkin_credits"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "checkins" ADD CONSTRAINT "checkins_confirmed_by_users_id_fk" FOREIGN KEY ("confirmed_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "gym_capacity_rules" ADD CONSTRAINT "gym_capacity_rules_gym_id_gyms_id_fk" FOREIGN KEY ("gym_id") REFERENCES "public"."gyms"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "gym_members" ADD CONSTRAINT "gym_members_gym_id_gyms_id_fk" FOREIGN KEY ("gym_id") REFERENCES "public"."gyms"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "gym_members" ADD CONSTRAINT "gym_members_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "gym_modalities" ADD CONSTRAINT "gym_modalities_gym_id_gyms_id_fk" FOREIGN KEY ("gym_id") REFERENCES "public"."gyms"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "gym_modalities" ADD CONSTRAINT "gym_modalities_modality_id_modalities_id_fk" FOREIGN KEY ("modality_id") REFERENCES "public"."modalities"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "gym_slot_occupancy" ADD CONSTRAINT "gym_slot_occupancy_gym_id_gyms_id_fk" FOREIGN KEY ("gym_id") REFERENCES "public"."gyms"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "gyms" ADD CONSTRAINT "gyms_category_id_categories_id_fk" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "gyms" ADD CONSTRAINT "gyms_approved_by_users_id_fk" FOREIGN KEY ("approved_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "health_metrics" ADD CONSTRAINT "health_metrics_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payment_splits" ADD CONSTRAINT "payment_splits_payment_id_payments_id_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payment_splits" ADD CONSTRAINT "payment_splits_gym_id_gyms_id_fk" FOREIGN KEY ("gym_id") REFERENCES "public"."gyms"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payments" ADD CONSTRAINT "payments_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payments" ADD CONSTRAINT "payments_subscription_id_subscriptions_id_fk" FOREIGN KEY ("subscription_id") REFERENCES "public"."subscriptions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payout_entries" ADD CONSTRAINT "payout_entries_checkin_id_checkins_id_fk" FOREIGN KEY ("checkin_id") REFERENCES "public"."checkins"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payout_entries" ADD CONSTRAINT "payout_entries_gym_id_gyms_id_fk" FOREIGN KEY ("gym_id") REFERENCES "public"."gyms"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payout_entries" ADD CONSTRAINT "payout_entries_payout_id_payouts_id_fk" FOREIGN KEY ("payout_id") REFERENCES "public"."payouts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payout_rules" ADD CONSTRAINT "payout_rules_category_id_categories_id_fk" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payout_rules" ADD CONSTRAINT "payout_rules_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payouts" ADD CONSTRAINT "payouts_gym_id_gyms_id_fk" FOREIGN KEY ("gym_id") REFERENCES "public"."gyms"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "plans" ADD CONSTRAINT "plans_category_id_categories_id_fk" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "push_tokens" ADD CONSTRAINT "push_tokens_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_plan_id_plans_id_fk" FOREIGN KEY ("plan_id") REFERENCES "public"."plans"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workouts" ADD CONSTRAINT "workouts_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workouts" ADD CONSTRAINT "workouts_checkin_id_checkins_id_fk" FOREIGN KEY ("checkin_id") REFERENCES "public"."checkins"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workouts" ADD CONSTRAINT "workouts_gym_id_gyms_id_fk" FOREIGN KEY ("gym_id") REFERENCES "public"."gyms"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workouts" ADD CONSTRAINT "workouts_modality_id_modalities_id_fk" FOREIGN KEY ("modality_id") REFERENCES "public"."modalities"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "audit_logs_entity_idx" ON "audit_logs" USING btree ("entity","entity_id");--> statement-breakpoint
CREATE INDEX "checkin_credits_user_idx" ON "checkin_credits" USING btree ("user_id","expires_at");--> statement-breakpoint
CREATE UNIQUE INDEX "checkins_one_per_day_per_subscription" ON "checkins" USING btree ("subscription_id","local_date") WHERE "checkins"."source" = 'subscription' AND "checkins"."status" IN ('pending', 'confirmed');--> statement-breakpoint
CREATE INDEX "checkins_gym_pending_idx" ON "checkins" USING btree ("gym_id","expires_at") WHERE "checkins"."status" = 'pending';--> statement-breakpoint
CREATE INDEX "checkins_user_idx" ON "checkins" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE INDEX "gym_capacity_rules_gym_idx" ON "gym_capacity_rules" USING btree ("gym_id","weekday");--> statement-breakpoint
CREATE INDEX "gym_members_user_idx" ON "gym_members" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "gyms_status_category_idx" ON "gyms" USING btree ("status","category_id");--> statement-breakpoint
CREATE INDEX "gyms_lat_lng_idx" ON "gyms" USING btree ("latitude","longitude");--> statement-breakpoint
CREATE INDEX "health_metrics_user_idx" ON "health_metrics" USING btree ("user_id","measured_at");--> statement-breakpoint
CREATE INDEX "payment_splits_payment_idx" ON "payment_splits" USING btree ("payment_id");--> statement-breakpoint
CREATE INDEX "payments_user_idx" ON "payments" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE INDEX "payout_entries_gym_status_idx" ON "payout_entries" USING btree ("gym_id","status");--> statement-breakpoint
CREATE UNIQUE INDEX "payout_rules_category_from_uq" ON "payout_rules" USING btree ("category_id","effective_from");--> statement-breakpoint
CREATE UNIQUE INDEX "payouts_gym_period_uq" ON "payouts" USING btree ("gym_id","period_start");--> statement-breakpoint
CREATE INDEX "push_tokens_user_idx" ON "push_tokens" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "subscriptions_one_live_per_user" ON "subscriptions" USING btree ("user_id") WHERE "subscriptions"."status" IN ('pending', 'active', 'past_due');--> statement-breakpoint
CREATE UNIQUE INDEX "users_email_uq" ON "users" USING btree (lower("email"));--> statement-breakpoint
CREATE UNIQUE INDEX "users_document_uq" ON "users" USING btree ("document");--> statement-breakpoint
CREATE INDEX "workouts_user_idx" ON "workouts" USING btree ("user_id","started_at");