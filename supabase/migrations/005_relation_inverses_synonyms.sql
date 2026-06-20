-- 005_relation_inverses_synonyms.sql
-- Créer les tables de relations inverses et synonymes avec FK vers relation_types

-- Table relation_inverses avec FK
CREATE TABLE relation_inverses (
  relation_type_id UUID PRIMARY KEY REFERENCES relation_types(id) ON DELETE CASCADE,
  inverse_type_id UUID NOT NULL REFERENCES relation_types(id) ON DELETE CASCADE
);

-- Insertion des relations inverses (via sous-requêtes pour récupérer les IDs)
INSERT INTO relation_inverses (relation_type_id, inverse_type_id) VALUES
  ((SELECT id FROM relation_types WHERE code = 'conjoint'),
   (SELECT id FROM relation_types WHERE code = 'conjoint')),
  
  ((SELECT id FROM relation_types WHERE code = 'parent'),
   (SELECT id FROM relation_types WHERE code = 'enfant')),
  
  ((SELECT id FROM relation_types WHERE code = 'enfant'),
   (SELECT id FROM relation_types WHERE code = 'parent')),
  
  ((SELECT id FROM relation_types WHERE code = 'frere_soeur'),
   (SELECT id FROM relation_types WHERE code = 'frere_soeur')),
  
  ((SELECT id FROM relation_types WHERE code = 'ami'),
   (SELECT id FROM relation_types WHERE code = 'ami')),
  
  ((SELECT id FROM relation_types WHERE code = 'collegue'),
   (SELECT id FROM relation_types WHERE code = 'collegue'));

-- Table relation_synonyms avec FK
CREATE TABLE relation_synonyms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  relation_type_id UUID NOT NULL REFERENCES relation_types(id) ON DELETE CASCADE,
  synonym TEXT NOT NULL,
  UNIQUE(relation_type_id, synonym)
);

-- Index
CREATE INDEX idx_relation_synonyms_relation_type_id ON relation_synonyms(relation_type_id);
CREATE INDEX idx_relation_synonyms_synonym ON relation_synonyms(synonym);

-- Insertion des synonymes
INSERT INTO relation_synonyms (relation_type_id, synonym) VALUES
  ((SELECT id FROM relation_types WHERE code = 'conjoint'), 'femme'),
  ((SELECT id FROM relation_types WHERE code = 'conjoint'), 'mari'),
  ((SELECT id FROM relation_types WHERE code = 'conjoint'), 'épouse'),
  ((SELECT id FROM relation_types WHERE code = 'conjoint'), 'époux'),
  ((SELECT id FROM relation_types WHERE code = 'conjoint'), 'partenaire'),
  ((SELECT id FROM relation_types WHERE code = 'conjoint'), 'compagne'),
  ((SELECT id FROM relation_types WHERE code = 'conjoint'), 'compagnon'),
  ((SELECT id FROM relation_types WHERE code = 'enfant'), 'fils'),
  ((SELECT id FROM relation_types WHERE code = 'enfant'), 'fille'),
  ((SELECT id FROM relation_types WHERE code = 'enfant'), 'gamin'),
  ((SELECT id FROM relation_types WHERE code = 'enfant'), 'gamine'),
  ((SELECT id FROM relation_types WHERE code = 'parent'), 'père'),
  ((SELECT id FROM relation_types WHERE code = 'parent'), 'mère'),
  ((SELECT id FROM relation_types WHERE code = 'parent'), 'papa'),
  ((SELECT id FROM relation_types WHERE code = 'parent'), 'maman');

-- RLS
ALTER TABLE relation_inverses ENABLE ROW LEVEL SECURITY;
ALTER TABLE relation_synonyms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view relation inverses"
  ON relation_inverses FOR SELECT
  USING (true);

CREATE POLICY "Anyone can view relation synonyms"
  ON relation_synonyms FOR SELECT
  USING (true);

COMMENT ON TABLE relation_inverses IS 'Relations inverses automatiques (parent ↔ enfant)';
COMMENT ON TABLE relation_synonyms IS 'Synonymes de relations pour QA Engine (femme → conjoint)';
