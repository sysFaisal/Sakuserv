-- Initial schema for nyobarust (fresh/empty database)
-- Run on the server with:
--   psql "$DATABASE_URL" -f migrations/0000_init.sql
-- Safe to re-run: all objects use IF NOT EXISTS / CREATE OR REPLACE where possible.

BEGIN;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
DO $$ BEGIN
    CREATE TYPE bottle_status AS ENUM ('available', 'empty', 'inactive');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE order_status AS ENUM ('success', 'failed', 'pending', 'refund');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE reason_stock_movement AS ENUM ('initial', 'sale', 'refund', 'adjustment');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE "role.model" AS ENUM ('dev', 'seller');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE type_stock_movement AS ENUM ('in', 'out');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    username      varchar(50)  NOT NULL,
    email         varchar(255),
    created_at    timestamptz  NOT NULL DEFAULT now(),
    updated_at    timestamptz  NOT NULL DEFAULT now(),
    password_hash text         NOT NULL,
    role          "role.model" NOT NULL,
    CONSTRAINT username CHECK (length(trim(username)) >= 3 AND username = trim(username)),
    CONSTRAINT email   CHECK (email IS NULL OR (length(trim(email)) >= 5 AND email = trim(email))),
    CONSTRAINT password_hash CHECK (length(password_hash) >= 8 AND password_hash = trim(password_hash)),
    CONSTRAINT users_username_key UNIQUE (username),
    CONSTRAINT users_email_key    UNIQUE (email)
);

CREATE TABLE IF NOT EXISTS brands (
    owner_id    uuid        NOT NULL REFERENCES users(id),
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name        varchar(100) NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    deleted_at  timestamptz,
    CONSTRAINT brands_owner_name_unique UNIQUE (owner_id, name)
);

CREATE TABLE IF NOT EXISTS parfume (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    brands_id    uuid        NOT NULL REFERENCES brands(id),
    name         varchar(150) NOT NULL,
    concentration varchar(50),
    description  text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    deleted_at   timestamptz,
    CONSTRAINT parfume_name_key UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS batch_parfume (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    parfume_id     uuid        NOT NULL REFERENCES parfume(id),
    quantity_ml    numeric(8,2) NOT NULL,
    purchase_price numeric(12,2) NOT NULL,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz
);

CREATE TABLE IF NOT EXISTS batch_parfume_bottle (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_parfume_id uuid         NOT NULL REFERENCES batch_parfume(id),
    remaining_ml     numeric(8,2) NOT NULL,
    status           bottle_status NOT NULL DEFAULT 'available',
    deleted_at       timestamptz
);

CREATE TABLE IF NOT EXISTS decant (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    parfume_id  uuid        NOT NULL REFERENCES parfume(id),
    size_ml     integer     NOT NULL,
    sell_price  numeric(10,2) NOT NULL,
    is_active   boolean     NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    deleted_at  timestamptz
);

CREATE TABLE IF NOT EXISTS order_items (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    bottle_id    uuid        NOT NULL REFERENCES batch_parfume_bottle(id),
    decant_id    uuid        NOT NULL REFERENCES decant(id),
    total_price  numeric(12,2) NOT NULL,
    quantity     integer     NOT NULL,
    price        numeric(12,2) NOT NULL,
    status       order_status NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS refresh_token (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL REFERENCES users(id),
    token_hash  text        NOT NULL,
    created_at  timestamptz(6) NOT NULL DEFAULT now(),
    expire_at   timestamptz NOT NULL,
    revoked_at  timestamptz,
    family_id   uuid        NOT NULL,
    CONSTRAINT refresh_token_token_hash_unique UNIQUE (token_hash)
);

CREATE TABLE IF NOT EXISTS stock_movements (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_items_id uuid        REFERENCES order_items(id),
    bottle_id      uuid        NOT NULL REFERENCES batch_parfume_bottle(id),
    quantity       numeric(8,2) NOT NULL,
    type           type_stock_movement NOT NULL,
    created_at     timestamptz NOT NULL DEFAULT now(),
    reason         reason_stock_movement NOT NULL
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS users_username_uidx
    ON users (username);

CREATE INDEX IF NOT EXISTS brands_owner_id_idx
    ON brands (owner_id) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS parfume_brands_id_idx
    ON parfume (brands_id) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS batch_parfume_parfume_id_idx
    ON batch_parfume (parfume_id) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS batch_parfume_bottle_batch_id_idx
    ON batch_parfume_bottle (batch_parfume_id) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS decant_parfume_id_idx
    ON decant (parfume_id) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS order_items_bottle_id_idx
    ON order_items (bottle_id);

CREATE INDEX IF NOT EXISTS order_items_decant_id_idx
    ON order_items (decant_id);

CREATE INDEX IF NOT EXISTS order_items_success_created_at_idx
    ON order_items (created_at DESC)
    WHERE status = 'success';

CREATE INDEX IF NOT EXISTS stock_movements_bottle_id_idx
    ON stock_movements (bottle_id);

CREATE INDEX IF NOT EXISTS stock_movements_order_items_id_idx
    ON stock_movements (order_items_id)
    WHERE order_items_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS refresh_token_family_id_idx
    ON refresh_token (family_id);

CREATE INDEX IF NOT EXISTS refresh_token_user_id_idx
    ON refresh_token (user_id);

COMMIT;

-- ---------------------------------------------------------------------------
-- Seed: 3 dev users (password: Ciamis270306, role: dev)
-- Idempotent: skip if username already exists.
-- ---------------------------------------------------------------------------
INSERT INTO users (username, password_hash, role) VALUES
    ('Dadang',  '$argon2id$v=19$m=12288,t=2,p=1$uHDrV19ODdoNcNK5Hl94AA$Gt5NHQU/TsRFA+VkHJl2bQiromLWYCKHMTpeJ9epuYo', 'dev'),
    ('Diding',  '$argon2id$v=19$m=12288,t=2,p=1$uHDrV19ODdoNcNK5Hl94AA$Gt5NHQU/TsRFA+VkHJl2bQiromLWYCKHMTpeJ9epuYo', 'dev'),
    ('Dudung',  '$argon2id$v=19$m=12288,t=2,p=1$uHDrV19ODdoNcNK5Hl94AA$Gt5NHQU/TsRFA+VkHJl2bQiromLWYCKHMTpeJ9epuYo', 'dev')
ON CONFLICT (username) DO NOTHING;
