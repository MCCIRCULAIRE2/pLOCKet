-- pLOCKet - Row Level Security Policies
-- Version: 1.0.0
-- Date: 2026-06-13

-- ============================================================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE procedures ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytical_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytical_values ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE procedure_documents ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- DOCUMENTS
-- ============================================================================

CREATE POLICY "Users can view own documents"
  ON documents FOR SELECT
  USING (auth.uid() = user_id AND deleted_at IS NULL);

CREATE POLICY "Users can insert own documents"
  ON documents FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own documents"
  ON documents FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can soft-delete own documents"
  ON documents FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id AND deleted_at IS NOT NULL);

-- ============================================================================
-- TAGS
-- ============================================================================

CREATE POLICY "Users can view own tags"
  ON tags FOR SELECT
  USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can insert own tags"
  ON tags FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tags"
  ON tags FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own tags"
  ON tags FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- CARDS
-- ============================================================================

CREATE POLICY "Users can view own cards"
  ON cards FOR SELECT
  USING (auth.uid() = user_id AND deleted_at IS NULL);

CREATE POLICY "Users can insert own cards"
  ON cards FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own cards"
  ON cards FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can soft-delete own cards"
  ON cards FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id AND deleted_at IS NOT NULL);

-- ============================================================================
-- ENTITIES
-- ============================================================================

CREATE POLICY "Users can view own entities"
  ON entities FOR SELECT
  USING (auth.uid() = user_id AND deleted_at IS NULL);

CREATE POLICY "Users can insert own entities"
  ON entities FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own entities"
  ON entities FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can soft-delete own entities"
  ON entities FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id AND deleted_at IS NOT NULL);

-- ============================================================================
-- EVENTS
-- ============================================================================

CREATE POLICY "Users can view own events"
  ON events FOR SELECT
  USING (auth.uid() = user_id AND deleted_at IS NULL);

CREATE POLICY "Users can insert own events"
  ON events FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own events"
  ON events FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can soft-delete own events"
  ON events FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id AND deleted_at IS NOT NULL);

-- ============================================================================
-- PROCEDURES
-- ============================================================================

CREATE POLICY "Users can view own procedures"
  ON procedures FOR SELECT
  USING (auth.uid() = user_id AND deleted_at IS NULL);

CREATE POLICY "Users can insert own procedures"
  ON procedures FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own procedures"
  ON procedures FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can soft-delete own procedures"
  ON procedures FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id AND deleted_at IS NOT NULL);

-- ============================================================================
-- ANALYTICAL FIELDS
-- ============================================================================

CREATE POLICY "Users can view own analytical fields"
  ON analytical_fields FOR SELECT
  USING (auth.uid() = user_id AND deleted_at IS NULL);

CREATE POLICY "Users can insert own analytical fields"
  ON analytical_fields FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own analytical fields"
  ON analytical_fields FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can soft-delete own analytical fields"
  ON analytical_fields FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id AND deleted_at IS NOT NULL);

-- ============================================================================
-- ANALYTICAL VALUES
-- ============================================================================

CREATE POLICY "Users can view own analytical values"
  ON analytical_values FOR SELECT
  USING (auth.uid() = user_id AND deleted_at IS NULL);

CREATE POLICY "Users can insert own analytical values"
  ON analytical_values FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own analytical values"
  ON analytical_values FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can soft-delete own analytical values"
  ON analytical_values FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id AND deleted_at IS NOT NULL);

-- ============================================================================
-- USER PROFILES
-- ============================================================================

CREATE POLICY "Users can view own profile"
  ON user_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
  ON user_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- DOCUMENT TAGS
-- ============================================================================

CREATE POLICY "Users can view own document tags"
  ON document_tags FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own document tags"
  ON document_tags FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own document tags"
  ON document_tags FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- DOCUMENT ENTITIES
-- ============================================================================

CREATE POLICY "Users can view own document entities"
  ON document_entities FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own document entities"
  ON document_entities FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own document entities"
  ON document_entities FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- PROCEDURE DOCUMENTS
-- ============================================================================

CREATE POLICY "Users can view own procedure documents"
  ON procedure_documents FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own procedure documents"
  ON procedure_documents FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own procedure documents"
  ON procedure_documents FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- STORAGE BUCKET (documents)
-- ============================================================================

-- Create private bucket for documents
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false);

-- Storage policies
CREATE POLICY "Users can upload own documents"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can view own documents"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can update own documents"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own documents"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
