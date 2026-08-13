#!/usr/bin/env bash
# Loads menu items for every restaurant. Reference data is already in
# db/init/002_seed_reference.sql; this adds the per-restaurant menus.
set -euo pipefail

SVC=${SVC:-postgres}
DB=${POSTGRES_DB:-daig}
USER=${POSTGRES_USER:-daig}

echo "seeding menu items..."
docker compose exec -T "$SVC" psql -U "$USER" -d "$DB" <<'SQL'
INSERT INTO menu_items (restaurant_id, name, price_paisa)
SELECT r.id, m.name, m.price
FROM restaurants r
CROSS JOIN (VALUES
  ('Chicken Karahi',      145000),
  ('Mutton Karahi',       225000),
  ('Chicken Biryani',      45000),
  ('Beef Nihari',         120000),
  ('Seekh Kabab (6pc)',    95000),
  ('Garlic Naan',          12000),
  ('Raita',                 8000),
  ('Kheer',                25000)
) AS m(name, price)
WHERE NOT EXISTS (
  SELECT 1 FROM menu_items x WHERE x.restaurant_id = r.id AND x.name = m.name
);

SELECT r.name AS restaurant, count(m.id) AS items
FROM restaurants r LEFT JOIN menu_items m ON m.restaurant_id = r.id
GROUP BY r.name ORDER BY r.name;
SQL

echo "seed complete"
