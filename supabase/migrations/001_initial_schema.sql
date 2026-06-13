-- pLOCKet - Initial Schema Migration
-- Version: 1.0.0
-- Date: 2026-06-13

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- TABLES
-- ============================================================================

-- Documents (métadonnées uniquement, fichiers dans Storage)
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  file_path TEXT,
  mime_type TEXT,
  ocr_text TEXT,
  storage_path TEXT,
  file_size BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  document_date TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Tags (prédéfinis + personnalisés)
CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  category TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Cards (fiches d'information)
CREATE TABLE cards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  type TEXT NOT NULL,
  sub_type TEXT NOT NULL DEFAULT 'general',
  raw_text TEXT NOT NULL DEFAULT '',
  value TEXT,
  date TIMESTAMPTZ,
  fields JSONB NOT NULL DEFAULT '{}',
  tags TEXT[] DEFAULT '{}',
  source_document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
  file_path TEXT,
  mime_type TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Entities (personnes, organismes, etc.)
CREATE TABLE entities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  name TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Events
CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  entity_id UUID REFERENCES entities(id) ON DELETE SET NULL,
  date TIMESTAMPTZ NOT NULL,
  description TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Procedures
CREATE TABLE procedures (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Analytical Fields (référentiels)
CREATE TABLE analytical_fields (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  icon TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Analytical Values (valeurs des référentiels)
CREATE TABLE analytical_values (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  field_id UUID NOT NULL REFERENCES analytical_fields(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  aliases JSONB DEFAULT '[]',
  identifiers JSONB DEFAULT '{}',
  role TEXT,
  category TEXT,
  relation TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- User Profiles
CREATE TABLE user_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nom TEXT,
  prenom TEXT,
  date_naissance TIMESTAMPTZ,
  email TEXT,
  telephone TEXT,
  adresse_postale TEXT,
  numero_securite_sociale TEXT,
  iban TEXT,
  informations_libres TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- ASSOCIATION TABLES
-- ============================================================================

-- Document-Tag relation
CREATE TABLE document_tags (
  document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  PRIMARY KEY (document_id, tag_id)
);

-- Document-Entity relation
CREATE TABLE document_entities (
  document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  PRIMARY KEY (document_id, entity_id)
);

-- Procedure-Document relation
CREATE TABLE procedure_documents (
  procedure_id UUID NOT NULL REFERENCES procedures(id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  PRIMARY KEY (procedure_id, document_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_documents_user ON documents(user_id);
CREATE INDEX idx_documents_created ON documents(created_at DESC);
CREATE INDEX idx_documents_deleted ON documents(deleted_at) WHERE deleted_at IS NULL;

CREATE INDEX idx_cards_user ON cards(user_id);
CREATE INDEX idx_cards_type ON cards(type);
CREATE INDEX idx_cards_created ON cards(created_at DESC);
CREATE INDEX idx_cards_deleted ON cards(deleted_at) WHERE deleted_at IS NULL;

CREATE INDEX idx_entities_user ON entities(user_id);
CREATE INDEX idx_entities_type ON entities(entity_type);

CREATE INDEX idx_events_user ON events(user_id);
CREATE INDEX idx_events_date ON events(date DESC);
CREATE INDEX idx_events_entity ON events(entity_id);

CREATE INDEX idx_procedures_user ON procedures(user_id);

CREATE INDEX idx_analytical_fields_user ON analytical_fields(user_id);
CREATE INDEX idx_analytical_values_field ON analytical_values(field_id);
CREATE INDEX idx_analytical_values_user ON analytical_values(user_id);

CREATE INDEX idx_tags_user ON tags(user_id);
CREATE INDEX idx_tags_category ON tags(category);

CREATE INDEX idx_document_tags_document ON document_tags(document_id);
CREATE INDEX idx_document_tags_tag ON document_tags(tag_id);

CREATE INDEX idx_document_entities_document ON document_entities(document_id);
CREATE INDEX idx_document_entities_entity ON document_entities(entity_id);

CREATE INDEX idx_procedure_documents_procedure ON procedure_documents(procedure_id);
CREATE INDEX idx_procedure_documents_document ON procedure_documents(document_id);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_documents_updated_at BEFORE UPDATE ON documents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cards_updated_at BEFORE UPDATE ON cards
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_entities_updated_at BEFORE UPDATE ON entities
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_procedures_updated_at BEFORE UPDATE ON procedures
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_analytical_fields_updated_at BEFORE UPDATE ON analytical_fields
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_analytical_values_updated_at BEFORE UPDATE ON analytical_values
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- DEFAULT TAGS (inserted for each new user)
-- ============================================================================

CREATE OR REPLACE FUNCTION create_default_tags_for_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO tags (id, user_id, label, category) VALUES
    ('type_facture', NEW.id, 'Facture', 'type'),
    ('type_contrat', NEW.id, 'Contrat', 'type'),
    ('type_attestation', NEW.id, 'Attestation', 'type'),
    ('type_identite', NEW.id, 'Identité', 'type'),
    ('type_bulletin', NEW.id, 'Bulletin de salaire', 'type'),
    ('type_courrier', NEW.id, 'Courrier', 'type'),
    ('domaine_automobile', NEW.id, 'Automobile', 'domain'),
    ('domaine_habitation', NEW.id, 'Habitation', 'domain'),
    ('domaine_sante', NEW.id, 'Santé', 'domain'),
    ('domaine_banque', NEW.id, 'Banque', 'domain'),
    ('domaine_fiscalite', NEW.id, 'Fiscalité', 'domain'),
    ('domaine_travail', NEW.id, 'Travail', 'domain'),
    ('sousdomaine_assurance', NEW.id, 'Assurance', 'subdomain'),
    ('sousdomaine_entretien', NEW.id, 'Entretien', 'subdomain'),
    ('sousdomaine_credit', NEW.id, 'Crédit', 'subdomain'),
    ('sousdomaine_garantie', NEW.id, 'Garantie', 'subdomain'),
    ('statut_actif', NEW.id, 'Actif', 'status'),
    ('statut_expire', NEW.id, 'Expiré', 'status'),
    ('statut_resilie', NEW.id, 'Résilié', 'status');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_default_tags_for_user();

-- ============================================================================
-- AUTO-CREATE USER PROFILE
-- ============================================================================

CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (user_id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_auth_user_created_profile
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_user_profile();
