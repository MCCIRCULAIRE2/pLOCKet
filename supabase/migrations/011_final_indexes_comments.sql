-- 011_final_indexes_comments.sql
-- Index finaux et commentaires

-- Vérifier que tous les index sont en place
-- (La plupart ont été créés dans les migrations précédentes)

-- Commentaires supplémentaires
COMMENT ON COLUMN entity_types.is_system IS 'true = type système (non modifiable en V2.1), false = type utilisateur (V2.2+)';
COMMENT ON COLUMN relation_types.is_system IS 'true = type système (non modifiable en V2.1), false = type utilisateur (V2.2+)';
COMMENT ON COLUMN entities.entity_type_id IS 'Type d''entité (personne, maison, voiture, etc.)';
COMMENT ON COLUMN analytical_fields.entity_type_id IS 'Type d''entité applicable (NULL = tous types)';
COMMENT ON COLUMN analytical_fields.is_sensitive IS 'true = donnée sensible (masquage recommandé)';
COMMENT ON COLUMN entity_attributes.provenance IS 'Origine de l''information (manual, ocr_validated, etc.)';
COMMENT ON COLUMN analytical_relations.relation_type_id IS 'Type de relation (conjoint, parent, enfant, etc.)';
COMMENT ON COLUMN user_profiles.onboarding_completed IS 'true = onboarding terminé, false = en cours';
