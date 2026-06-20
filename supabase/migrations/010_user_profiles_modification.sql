-- 010_user_profiles_modification.sql
-- Modifier la table user_profiles pour cohérence avec V2.1
-- NOTE : Les anciennes colonnes sont conservées pour la migration applicative
--        Elles seront supprimées par migration 012 après 30 jours

-- Renommer les colonnes pour cohérence snake_case
ALTER TABLE user_profiles RENAME COLUMN nom TO last_name;
ALTER TABLE user_profiles RENAME COLUMN prenom TO first_name;
ALTER TABLE user_profiles RENAME COLUMN date_naissance TO birth_date;
ALTER TABLE user_profiles RENAME COLUMN telephone TO phone;

-- NE PAS supprimer les colonnes migrées (email, adresse_postale, numero_securite_sociale, iban, informations_libres)
-- Elles seront supprimées par migration 012 APRÈS migration applicative

-- Ajouter la colonne onboarding_completed
ALTER TABLE user_profiles 
  ADD COLUMN onboarding_completed BOOLEAN NOT NULL DEFAULT false;

COMMENT ON TABLE user_profiles IS 'Profil utilisateur minimaliste (V2.1 : anciennes colonnes conservées pour migration)';
