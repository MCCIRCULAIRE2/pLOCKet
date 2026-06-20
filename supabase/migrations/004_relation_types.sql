-- 004_relation_types.sql
-- Créer la table des types de relations (lecture seule en V2.1)

CREATE TABLE relation_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  is_system BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index
CREATE INDEX idx_relation_types_code ON relation_types(code);

-- Types système (15 types)
INSERT INTO relation_types (code, label, is_system) VALUES
  ('conjoint', 'Conjoint(e)', true),
  ('parent', 'Parent', true),
  ('enfant', 'Enfant', true),
  ('frere_soeur', 'Frère/Sœur', true),
  ('ami', 'Ami(e)', true),
  ('collegue', 'Collègue', true),
  ('proprietaire', 'Propriétaire', true),
  ('locataire', 'Locataire', true),
  ('occupant', 'Occupant', true),
  ('conducteur_principal', 'Conducteur principal', true),
  ('titulaire', 'Titulaire', true),
  ('beneficiaire', 'Bénéficiaire', true),
  ('employeur', 'Employeur', true),
  ('concerne', 'Concerne', true),
  ('lie_a', 'Lié à', true);

-- RLS : LECTURE UNIQUEMENT en V2.1
ALTER TABLE relation_types ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view relation types"
  ON relation_types FOR SELECT
  USING (true);

-- PAS de policies INSERT/UPDATE/DELETE en V2.1 (types système uniquement)

COMMENT ON TABLE relation_types IS 'Types de relations système (V2.1 : lecture seule)';
