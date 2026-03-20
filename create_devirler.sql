-- Devir kayıtlarını tutan tablo
-- Bu tablo her gün kapanışta "kasada bırakılan para" bilgisini saklar.
CREATE TABLE IF NOT EXISTS devirler (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  amount numeric(10, 2) NOT NULL,
  description text NOT NULL DEFAULT '',
  created_at timestamptz DEFAULT now() NOT NULL
);

-- RLS Policy: Authenticated users can insert/select
ALTER TABLE devirler ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can select devirler"
  ON devirler FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert devirler"
  ON devirler FOR INSERT WITH CHECK (auth.role() = 'authenticated');
