-- 007_analytical_fields_extension.sql
-- Étendre la table analytical_fields existante

-- Ajouter entity_type_id (NULL = applicable à tous les types d'entités)
ALTER TABLE analytical_fields 
  ADD COLUMN entity_type_id UUID REFERENCES entity_types(id);

-- Index
CREATE INDEX idx_analytical_fields_entity_type_id ON analytical_fields(entity_type_id);
CREATE INDEX idx_analytical_fields_user_name_type ON analytical_fields(user_id, name, entity_type_id) WHERE deleted_at IS NULL;

-- Contrainte d'unicité
ALTER TABLE analytical_fields 
  ADD CONSTRAINT unique_user_name_type UNIQUE (user_id, name, entity_type_id);

COMMENT ON TABLE analytical_fields IS 'Définition centralisée des types d''attributs';
