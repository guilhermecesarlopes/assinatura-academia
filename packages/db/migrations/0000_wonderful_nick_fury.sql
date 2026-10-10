CREATE TABLE "feature_flags" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"key" text NOT NULL,
	"description" text,
	"enabled_for" text DEFAULT 'none' NOT NULL,
	CONSTRAINT "feature_flags_key_unique" UNIQUE("key")
);
