# Procédure de migration vers Supabase Cloud

## Pré-requis

1. Créer un projet Supabase sur https://supabase.com
2. Choisir la région EU (Francfort ou Irlande)
3. Noter l'URL du projet et la clé anon

## Étape 1 : Configuration Supabase

### 1.1 Appliquer les migrations SQL

Dans le dashboard Supabase → SQL Editor :

1. Exécuter `supabase/migrations/001_initial_schema.sql`
2. Exécuter `supabase/migrations/002_rls_policies.sql`

### 1.2 Configurer l'authentification

Dans Authentication → Providers :
- Activer **Email** (avec confirmation email activée)
- Activer **Email Links** (Magic Link)

Dans Authentication → URL Configuration :
- Site URL : `https://mccirculaire2.github.io/pLOCKet/`
- Redirect URLs : ajouter l'URL de l'app

### 1.3 Configurer le Storage

Le bucket `documents` est créé automatiquement par la migration 002.

Vérifier dans Storage → `documents` :
- Public : **Non**
- File size limit : 50 MB

### 1.4 Configurer les variables d'environnement

Pour le build Flutter, passer les variables :

```bash
flutter build web --release \
  --base-href /pLOCKet/ \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

Ou créer un fichier `.env` (non commité) :

```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```

## Étape 2 : Sauvegarde des données existantes

### 2.1 Export SQLite (natif)

```bash
# Copier le fichier SQLite
cp ~/Documents/plocket.db ~/Documents/plocket_backup_$(date +%Y%m%d).db
```

### 2.2 Export localStorage (web)

Dans la console du navigateur :
```javascript
// Copier le contenu
copy(localStorage.getItem('plocket_db'));
// Coller dans un fichier plocket_backup_YYYYMMDD.json
```

## Étape 3 : Migration des données

Après connexion de l'utilisateur, les données locales seront migrées automatiquement vers le cloud.

Le SplashScreen détecte les données locales et propose la migration.

## Procédure de rollback

### Si la migration échoue

1. **Restaurer SQLite** :
```bash
cp ~/Documents/plocket_backup_YYYYMMDD.db ~/Documents/plocket.db
```

2. **Restaurer localStorage** :
```javascript
localStorage.setItem('plocket_db', contenuDuBackup);
```

3. **Revenir à la version précédente** :
```bash
git checkout <commit-avant-migration>
flutter build web --release --base-href /pLOCKet/
```

### Si Supabase est indisponible

L'application bascule en mode lecture seule avec le cache local.
Aucune donnée n'est perdue.

## Vérification post-migration

- [ ] Connexion fonctionnelle (email + mot de passe)
- [ ] Inscription fonctionnelle
- [ ] Magic link fonctionnel
- [ ] Fiches visibles après connexion
- [ ] Documents uploadés dans Storage
- [ ] Champs analytiques migrés
- [ ] Profil utilisateur migré
- [ ] Déconnexion fonctionnelle
- [ ] Reconnexion sur un second appareil → données présentes
