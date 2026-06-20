-- 007b_analytical_fields_add_columns.sql
-- Ajouter les colonnes manquantes dans analytical_fields
-- Corrige l'incohérence entre le modèle Dart et le schéma SQL

-- Ajouter category et is_sensitive
ALTER TABLE analytical_fields 
  ADD COLUMN category TEXT,
  ADD COLUMN is_sensitive BOOLEAN NOT NULL DEFAULT false;

-- Supprimer la contrainte UNIQUE actuelle qui ne gère pas correctement NULL
ALTER TABLE analytical_fields 
  DROP CONSTRAINT IF EXISTS unique_user_name_type;

-- Supprimer l'index partiel existant (s'il existe)
DROP INDEX IF EXISTS idx_analytical_fields_user_name_type;

-- Créer deux index partiels pour gérer correctement le cas NULL
-- Cas 1 : entity_type_id IS NOT NULL
CREATE UNIQUE INDEX idx_analytical_fields_unique_with_type 
  ON analytical_fields(user_id, name, entity_type_id) 
  WHERE entity_type_id IS NOT NULL AND deleted_at IS NULL;

-- Cas 2 : entity_type_id IS NULL
CREATE UNIQUE INDEX idx_analytical_fields_unique_without_type 
  ON analytical_fields(user_id, name) 
  WHERE entity_type_id IS NULL AND deleted_at IS NULL;

-- Garder un index pour les recherches par entity_type_id
CREATE INDEX idx_analytical_fields_entity_type_id ON analytical_fields(entity_type_id);

COMMENT ON COLUMN analytical_fields.category IS 'Catégorie du champ (ex: contact, identité, finance)';
COMMENT ON COLUMN analytical_fields.is_sensitive IS 'true = donnée sensible (masquage recommandé)';
