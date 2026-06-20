-- 003_entity_types.sql
-- Créer la table des types d'entités (lecture seule en V2.1)

CREATE TABLE entity_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  icon TEXT,
  is_system BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index
CREATE INDEX idx_entity_types_code ON entity_types(code);

-- Types système (11 types)
INSERT INTO entity_types (code, label, icon, is_system) VALUES
  ('personne', 'Personne', 'person', true),
  ('maison', 'Maison', 'home', true),
  ('voiture', 'Voiture', 'car', true),
  ('contrat', 'Contrat', 'contract', true),
  ('entreprise', 'Entreprise', 'business', true),
  ('document', 'Document', 'document', true),
  ('animal', 'Animal', 'pet', true),
  ('appareil', 'Appareil', 'device', true),
  ('abonnement', 'Abonnement', 'subscription', true),
  ('liste', 'Liste', 'list', true),
  ('objectif', 'Objectif', 'target', true);

-- RLS : LECTURE UNIQUEMENT en V2.1
ALTER TABLE entity_types ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view entity types"
  ON entity_types FOR SELECT
  USING (true);

-- PAS de policies INSERT/UPDATE/DELETE en V2.1 (types système uniquement)

COMMENT ON TABLE entity_types IS 'Types d''entités système (V2.1 : lecture seule)';
