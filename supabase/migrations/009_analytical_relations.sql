-- 009_analytical_relations.sql
-- Créer la table des relations entre entités

CREATE TABLE analytical_relations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  target_entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  relation_type_id UUID NOT NULL REFERENCES relation_types(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  UNIQUE(source_entity_id, target_entity_id, relation_type_id)
);

-- Index
CREATE INDEX idx_analytical_relations_user_id ON analytical_relations(user_id);
CREATE INDEX idx_analytical_relations_source_entity_id ON analytical_relations(source_entity_id);
CREATE INDEX idx_analytical_relations_target_entity_id ON analytical_relations(target_entity_id);
CREATE INDEX idx_analytical_relations_relation_type_id ON analytical_relations(relation_type_id);
CREATE INDEX idx_analytical_relations_deleted_at ON analytical_relations(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_analytical_relations_user_type_deleted ON analytical_relations(user_id, relation_type_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_analytical_relations_source_target_type ON analytical_relations(source_entity_id, target_entity_id, relation_type_id) WHERE deleted_at IS NULL;

-- RLS
ALTER TABLE analytical_relations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own relations"
  ON analytical_relations FOR SELECT
  USING (user_id = auth.uid() AND deleted_at IS NULL);

CREATE POLICY "Users can insert own relations"
  ON analytical_relations FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own relations"
  ON analytical_relations FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can soft-delete own relations"
  ON analytical_relations FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid() AND deleted_at IS NOT NULL);

COMMENT ON TABLE analytical_relations IS 'Relations entre entités';
