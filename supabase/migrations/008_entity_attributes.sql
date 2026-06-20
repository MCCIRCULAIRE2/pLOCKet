-- 008_entity_attributes.sql
-- Créer la table des attributs d'entités

CREATE TABLE entity_attributes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  field_id UUID NOT NULL REFERENCES analytical_fields(id) ON DELETE CASCADE,
  attribute_value TEXT NOT NULL,
  provenance TEXT NOT NULL DEFAULT 'manual',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_provenance CHECK (provenance IN (
    'manual', 
    'ocr_unvalidated', 
    'ocr_validated', 
    'ai_suggestion', 
    'document_official', 
    'sync', 
    'import'
  ))
);

-- Index
CREATE INDEX idx_entity_attributes_entity_id ON entity_attributes(entity_id);
CREATE INDEX idx_entity_attributes_field_id ON entity_attributes(field_id);
CREATE INDEX idx_entity_attributes_provenance ON entity_attributes(provenance);
CREATE INDEX idx_entity_attributes_entity_field ON entity_attributes(entity_id, field_id);

-- RLS
ALTER TABLE entity_attributes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own entity attributes"
  ON entity_attributes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM entities 
      WHERE entities.id = entity_attributes.entity_id 
      AND entities.user_id = auth.uid()
      AND entities.deleted_at IS NULL
    )
  );

CREATE POLICY "Users can insert own entity attributes"
  ON entity_attributes FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM entities 
      WHERE entities.id = entity_attributes.entity_id 
      AND entities.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own entity attributes"
  ON entity_attributes FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM entities 
      WHERE entities.id = entity_attributes.entity_id 
      AND entities.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own entity attributes"
  ON entity_attributes FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM entities 
      WHERE entities.id = entity_attributes.entity_id 
      AND entities.user_id = auth.uid()
    )
  );

COMMENT ON TABLE entity_attributes IS 'Valeurs des attributs pour chaque entité';
