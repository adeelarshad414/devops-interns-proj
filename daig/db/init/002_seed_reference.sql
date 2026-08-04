-- Reference data only. Idempotent: safe to run twice.
INSERT INTO restaurants (name, area, prep_minutes) VALUES
  ('Butt Karahi',        'Lakshmi Chowk', 25),
  ('Cafe Aylanto',       'Gulberg',       30),
  ('Sadaf Fish',         'Burns Road',    18),
  ('Kolachi',            'Do Darya',      35),
  ('Student Biryani',    'Saddar',        12),
  ('Bundu Khan',         'Tariq Road',    22)
ON CONFLICT DO NOTHING;

INSERT INTO riders (name, area) VALUES
  ('Rider 01','Gulberg'), ('Rider 02','Gulberg'), ('Rider 03','Saddar'),
  ('Rider 04','Saddar'),  ('Rider 05','Tariq Road'), ('Rider 06','Burns Road'),
  ('Rider 07','Do Darya'),('Rider 08','Lakshmi Chowk')
ON CONFLICT DO NOTHING;
