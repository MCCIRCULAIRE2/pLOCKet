-- 007_analytical_fields_extension.sql
-- Étendre la table analytical_fields existante

-- Ajouter entity_type_id (NULL = applicable à tous les types d'entités)
ALTER TABLE analytical_fields 
  ADD COLUMN entity_type_id UUID REFERENCES entity_types(id);

-- NOTE : La contrainte UNIQUE et les index seront créés dans 007b
-- pour gérer correctement le cas entity_type_id IS NULL

COMMENT ON TABLE analytical_fields IS 'Définition centralisée des types d''attributs';
