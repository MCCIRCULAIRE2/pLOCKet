-- 006_entities_extension.sql
-- Étendre la table entities existante

-- Renommer name → label
ALTER TABLE entities RENAME COLUMN name TO label;

-- Supprimer les anciennes colonnes
ALTER TABLE entities 
  DROP COLUMN IF EXISTS entity_type,
  DROP COLUMN IF EXISTS metadata;

-- Ajouter entity_type_id (FK vers entity_types)
ALTER TABLE entities 
  ADD COLUMN entity_type_id UUID REFERENCES entity_types(id);

-- Index
CREATE INDEX idx_entities_entity_type_id ON entities(entity_type_id);
CREATE INDEX idx_entities_user_type_deleted ON entities(user_id, entity_type_id) WHERE deleted_at IS NULL;

COMMENT ON TABLE entities IS 'Entités du monde réel (personnes, lieux, véhicules, etc.)';
