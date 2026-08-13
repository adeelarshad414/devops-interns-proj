-- Daig schema. ADDITIVE ONLY.
-- New columns are nullable or defaulted. No DROP, no destructive ALTER.
-- Rows are temporal: we mark state, we do not delete history.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS restaurants (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name         TEXT        NOT NULL,
    area         TEXT        NOT NULL,
    prep_minutes INT         NOT NULL DEFAULT 20,
    is_open      BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS menu_items (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    restaurant_id UUID        NOT NULL REFERENCES restaurants(id),
    name          TEXT        NOT NULL,
    price_paisa   INT         NOT NULL,
    is_available  BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    restaurant_id UUID        NOT NULL REFERENCES restaurants(id),
    customer_area TEXT        NOT NULL,
    total_paisa   INT         NOT NULL DEFAULT 0,
    state         TEXT        NOT NULL DEFAULT 'PLACED',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT orders_state_ck CHECK (state IN
        ('PLACED','ACCEPTED','REJECTED','COOKING','READY','ASSIGNED','DELIVERED','CANCELLED'))
);

CREATE TABLE IF NOT EXISTS order_items (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id     UUID NOT NULL REFERENCES orders(id),
    menu_item_id UUID NOT NULL REFERENCES menu_items(id),
    qty          INT  NOT NULL DEFAULT 1,
    price_paisa  INT  NOT NULL
);

-- Temporal: every state change appends a row. Nothing is overwritten.
CREATE TABLE IF NOT EXISTS order_events (
    id         BIGSERIAL PRIMARY KEY,
    order_id   UUID        NOT NULL REFERENCES orders(id),
    from_state TEXT,
    to_state   TEXT        NOT NULL,
    actor      TEXT        NOT NULL,
    trace_id   TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS riders (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT        NOT NULL,
    area       TEXT        NOT NULL,
    is_on_shift BOOLEAN    NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS assignments (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id   UUID        NOT NULL REFERENCES orders(id),
    rider_id   UUID        NOT NULL REFERENCES riders(id),
    state      TEXT        NOT NULL DEFAULT 'ASSIGNED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Deliberately NOT indexed. Day 4 makes them add this and measure the
-- difference in the trace. Uncommenting it is the fix, not the starting point.
-- CREATE INDEX idx_assignments_order ON assignments(order_id);
-- CREATE INDEX idx_orders_state_created ON orders(state, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_menu_items_restaurant ON menu_items(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_order_events_order    ON order_events(order_id);
