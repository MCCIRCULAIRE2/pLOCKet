-- 012_user_profile_primary_entity_link.sql
-- Ajouter le lien stable entre UserProfile et l'entité "Moi"

ALTER TABLE user_profiles
  ADD COLUMN primary_person_entity_id UUID REFERENCES entities(id);

COMMENT ON COLUMN user_profiles.primary_person_entity_id IS
  'Lien vers l''entité personne principale (Moi) dans le graphe d''entités V2.1';

