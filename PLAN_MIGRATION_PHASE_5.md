# Phase 5 — Migration du moteur de réponse

## Architecture cible, plan de migration et découpage

---

## 1. Audit des dépendances actuelles

### 1.1 Dépendances legacy dans `qa_engine.dart`

| Dépendance | Type | Usage | Statut |
|-----------|------|-------|--------|
| `UserProfileDao` (SharedPrefs) | DAO direct | `getProfile()` pour requêtes personnelles | ❌ Legacy |
| `UserProfile.numeroSecuriteSociale` | Champ legacy | Lecture dans `_getProfileValue()` | ❌ Marqué "supprimé migration 013" |
| `UserProfile.adressePostale` | Champ legacy | Lecture dans `_getProfileValue()` | ❌ Marqué "supprimé migration 013" |
| `UserProfile.email` | Champ legacy | Lecture dans `_getProfileValue()` | ❌ Marqué "supprimé migration 013" |
| `UserProfile.phone` | Champ moderne | Lecture dans `_getProfileValue()` | ✅ À conserver |
| `UserProfile.birthDate` | Champ moderne | Lecture dans `_getProfileValue()` | ✅ À conserver |
| `AnalyticalFieldDao` | DAO local SQLite | `getAllFields()` + `getAllValues()` | ❌ Deprecated |
| `AnalyticalField` / `AnalyticalValue` | Modèles legacy | Passés à `SemanticRelationEngine` et `FallbackAIService` | ❌ Deprecated |
| `CardDao` | DAO local SQLite | `getAll()` pour fallback AI | ✅ Légitime (recherche document) |
| `_isPersonalQuery()` keywords | 13 mots-clés hardcodés | Détection "je", "mon", "mes"... | ⚠️ À remplacer par détection entité "Moi" |
| `_detectRequestedInfo()` | 5 patterns hardcodés | Mapping question → type d'info | ❌ Legacy (champs UserProfile) |
| `_getProfileValue()` | Switch 5 cas | Extraction valeur depuis UserProfile | ❌ Legacy (3/5 champs) |

### 1.2 Dépendances legacy dans `semantic_relation_engine.dart`

| Dépendance | Type | Usage | Statut |
|-----------|------|-------|--------|
| `AnalyticalField` | Modèle legacy | Filtre par `field.name` ("Personne", "Logement", "Véhicule") | ❌ Deprecated |
| `AnalyticalValue` | Modèle legacy | Résultat de la recherche sémantique | ❌ Deprecated |
| `AnalyticalValue.relation` | Champ legacy (`String?`) | Filtre relations familiales | ❌ → Remplacer par `AnalyticalRelation` |
| `AnalyticalValue.category` | Champ legacy (`String?`) | Filtre catégories logement/véhicule | ❌ → Remplacer par `EntityType.code` |
| `UserProfileDao` | DAO direct | Création valeur virtuelle "Moi" dans groupe famille | ❌ → EntityProvider.getMeEntity() |
| `_familyRelations` | Map hardcodée (6 clés) | Synonymes relations familiales | ❌ → `relation_synonyms` Supabase |
| `_housingCategories` | Map hardcodée (4 clés) | Catégories logement | ❌ → `EntityType.code == 'maison'` |
| `_vehicleCategories` | Map hardcodée (4 clés) | Catégories véhicule | ❌ → `EntityType.code == 'voiture'` |
| `_semanticGroups` | Map hardcodée (8 clés) | Groupes sémantiques + mapping champ | ❌ → EntityType + RelationType dynamiques |
| `_findFieldByName("Personne")` | Lookup statique | Trouve champ "Personne" dans AnalyticalField list | ❌ → EntityType.getTypeByCode('personne') |
| `_findFieldByGroup()` | Mapping groupe→nom champ | 8 entrées hardcodées | ❌ → EntityTypeProvider |
| `_filterBySubGroup()` | Filtres hardcodés | 6 cas (filles, fils, enfants, etc.) | ❌ → RelationProvider |
| `getRelationSuggestions()` | 3 cas hardcodés | Suggestions UI pour dropdown | ❌ → RelationTypeProvider |
| `getRelationSynonyms()` | 3 maps itérées | Synonymes pour matching | ❌ → CloudRepository.getRelationSynonyms() |

### 1.3 Doublon de pipeline — `IntelligentSearch` vs `QaEngine`

La `HomeScreen._submitSearch()` déclenche **deux pipelines indépendants** :

1. `SearchProvider.search()` → `IntelligentSearch.search()` → extraction regex sur documents
2. `SearchResultsScreen` → `CardProvider.ask()` → `QaEngine.answer()` → profil + sémantique + AI

Les deux produisent des `AnswerResult` de **classes différentes** :
- `lib/services/intelligent_search.dart` : `AnswerResult` (sans `values`)
- `lib/ai/ai_service.dart` : `AnswerResult` (avec `values`)

---

## 2. Cartographie des flux de données actuels

### 2.1 Flux question → réponse (QaEngine)

```
Question entrante
    │
    ├── _isPersonalQuery() ← 13 mots-clés
    │     └── UserProfileDao.getProfile() ← SharedPrefs
    │           └── _detectRequestedInfo() ← 5 patterns
    │                 └── _getProfileValue() ← 5 champs UserProfile
    │                       └── AnswerResult (confidence: 'Fort')
    │
    ├── CardDao.getAll() ← SQLite
    │     └── AnalyticalFieldDao.getAllFields() + getAllValues() ← SQLite
    │           └── SemanticRelationEngine.findEntitiesBySemanticQuery()
    │                 │  4 stages, 4 maps hardcodées
    │                 │  → List<AnalyticalValue>
    │                 └── AnswerResult (confidence: 'Fort', values: [])
    │
    └── FallbackAIService.answerQuestion()
          │  QuestionAnalyzer → intent → _typePatterns → CardModel.subType
          │  → AnswerResult (confidence: variable)
```

### 2.2 Flux question → réponse (IntelligentSearch)

```
Question entrante
    │
    └── QuestionAnalyzer.analyze()
          │  → {intent, subject}
          ├── intent == 'general'
          │     └── SearchEngine.search() → documents → AnswerResult[]
          └── intent spécifique
                └── DocumentDao.getAll() ← SQLite
                      └── _extractSpecificValue(text, intent) ← regex
                            └── AnswerResult (confidence: 'Fort')
```

---

## 3. Cibles de remplacement (nouvelle architecture)

### 3.1 Mapping legacy → nouveau

| Concept legacy | Remplacé par | Provider | Méthode clé |
|---------------|-------------|----------|-------------|
| `UserProfile.numeroSecuriteSociale` | `EntityAttribute(attributeValue)` sur entité "Moi" | `EntityAttributeProvider` | `getAttributesWithFields(meId, fields)` |
| `UserProfile.adressePostale` | `EntityAttribute(attributeValue)` sur entité "Résidence" | `EntityAttributeProvider` | `getAttributesWithFields(entityId, fields)` |
| `UserProfile.email` | `EntityAttribute(attributeValue)` sur entité "Moi" | `EntityAttributeProvider` | `getAttributesWithFields(meId, fields)` |
| `UserProfile.phone` | `EntityAttribute(attributeValue)` sur entité "Moi" | `EntityAttributeProvider` | `getAttributesWithFields(meId, fields)` |
| `UserProfile.birthDate` | `EntityAttribute(attributeValue)` sur entité "Moi" | `EntityAttributeProvider` | `getAttributesWithFields(meId, fields)` |
| `AnalyticalValue.relation == 'conjoint'` | `AnalyticalRelation(relationTypeId: 'conjoint')` | `RelationProvider` | `getAllRelationsWithDetails(meId)` |
| `AnalyticalValue.category == 'résidence principale'` | `Entity.entityTypeId == 'maison'` | `EntityProvider` | `getEntitiesByType(maisonTypeId)` |
| `AnalyticalField.name == 'Personne'` | `EntityType.code == 'personne'` | `EntityTypeProvider` | `getTypeByCode('personne')` |
| `_familyRelations` hardcodé | `RelationType.code` + `relation_synonyms` table | `RelationTypeProvider` | `getSynonyms(relationTypeId)` |
| `_housingCategories` hardcodé | `EntityType.code == 'maison'` | `EntityTypeProvider` | `getTypeByCode('maison')` |
| `_vehicleCategories` hardcodé | `EntityType.code == 'voiture'` | `EntityTypeProvider` | `getTypeByCode('voiture')` |

### 3.2 Résolution de l'entité "Moi"

```dart
// Nouveau : via EntityProvider.getMeEntity()
final me = await entityProvider.getMeEntity(
  userProfileProvider: userProfileProvider,
  entityTypeProvider: entityTypeProvider,
);
if (me == null) return;
```

Remplacé :
- `UserProfileDao().getProfile()` → `EntityProvider.getMeEntity()`
- `profile.firstName + profile.lastName` → `me.label`
- `profile.numeroSecuriteSociale` → `EntityAttributeProvider.getAttributesWithFields(me.id, fields)`

### 3.3 Résolution des relations

```dart
// Nouveau : via RelationProvider.getAllRelationsWithDetails()
final relations = await relationProvider.getAllRelationsWithDetails(me.id);
// relations : List<EntityRelationWithEntities>
// Chaque entrée a : relation (AnalyticalRelation), sourceEntity, targetEntity,
//                   relationType (RelationType avec code + label), isOutgoing
```

L'`AnalyticalRelation.relationTypeId` permet de :
- Filtrer par type (`relationType.code == 'conjoint'`)
- Récupérer le label (`relationType.label`)
- Naviguer vers l'entité cible (`targetEntity`)
- Obtenir l'inverse (`relationTypeProvider.getInverseTypeId()`)
- Récupérer les synonymes (`relationTypeProvider.getSynonyms()`)

### 3.4 Recherche d'attributs

```dart
// Nouveau : via EntityAttributeProvider.getAttributesWithFields()
final attributes = await attrProvider.getAttributesWithFields(entityId, allFields);
// attributes : List<EntityAttributeWithField>
// Chaque entrée a : attribute (EntityAttribute), field (AnalyticalField)
// attribute.attributeValue → la valeur
// field.name → le libellé ("Téléphone", "Email", "NIR"...)
// field.isSensitive → pour décision UI
```

### 3.5 Génération de réponses

```dart
// Nouveau pattern de construction de réponse
String _buildAttributeAnswer(EntityAttributeWithField awf) {
  return 'Votre ${awf.field.name} est : ${awf.attribute.attributeValue}';
}

String _buildRelationAnswer(EntityRelationWithEntities r) {
  return 'Votre ${r.relationType.label} est ${r.targetEntity.label}';
}

String _buildRelationAttributeAnswer(
  EntityRelationWithEntities r,
  EntityAttributeWithField awf,
) {
  return 'Le ${awf.field.name} de ${r.targetEntity.label} est : ${awf.attribute.attributeValue}';
}
```

---

## 4. Architecture cible du moteur de réponse

### 4.1 Nouveau `QaEngine` (v2)

```dart
class QaEngineV2 {
  final EntityProvider entityProvider;
  final EntityAttributeProvider attrProvider;
  final RelationProvider relationProvider;
  final EntityTypeProvider entityTypeProvider;
  final RelationTypeProvider relationTypeProvider;
  final AnalyticalFieldProvider fieldProvider;
  final UserProfileProvider userProfileProvider;
  final CardProvider cardProvider; // fallback documents

  // Résultats composites mis en cache pour la durée d'une question
  Entity? _meEntity;
  List<EntityAttributeWithField> _meAttributes = [];
  List<EntityRelationWithEntities> _meRelations = [];
  List<AnalyticalField> _allFields = [];
  List<Entity> _allEntities = [];
  Map<String, EntityType> _entityTypesByCode = {};
  Map<String, RelationType> _relationTypesByCode = {};

  Future<void> _loadContext() async {
    await Future.wait([
      entityTypeProvider.loadTypes(),
      relationTypeProvider.loadTypes(),
      fieldProvider.loadAll(),
      entityProvider.loadEntities(),
    ]);
    _allFields = fieldProvider.fields;
    _allEntities = entityProvider.entities;
    _entityTypesByCode = {for (var t in entityTypeProvider.types) t.code: t};
    _relationTypesByCode = {for (var t in relationTypeProvider.types) t.code: t};

    _meEntity = await entityProvider.getMeEntity(
      userProfileProvider: userProfileProvider,
      entityTypeProvider: entityTypeProvider,
    );
    if (_meEntity == null) return;

    final results = await Future.wait([
      attrProvider.getAttributesWithFields(_meEntity!.id, _allFields),
      relationProvider.getAllRelationsWithDetails(_meEntity!.id),
    ]);
    _meAttributes = results[0] as List<EntityAttributeWithField>;
    _meRelations = results[1] as List<EntityRelationWithEntities>;
  }

  Future<AnswerResult> answer(String question) async {
    await _loadContext();
    if (_meEntity == null) {
      return AnswerResult(
        answerText: 'Je n\'ai pas encore d\'identité configurée.',
        confidence: 'Faible',
      );
    }

    final questionLower = question.toLowerCase();

    // Stage 1 : Attributs personnels (mon téléphone, mon email...)
    final attrResult = await _resolvePersonalAttribute(questionLower);
    if (attrResult != null) return attrResult;

    // Stage 2 : Relations + attributs liés (téléphone de mon conjoint...)
    final relationResult = await _resolveRelationAttribute(questionLower);
    if (relationResult != null) return relationResult;

    // Stage 3 : Entités par type (mes logements, mes véhicules...)
    final entityResult = await _resolveEntitiesByType(questionLower);
    if (entityResult != null) return entityResult;

    // Stage 4 : Fallback documents + AI
    return await _fallbackToCards(question);
  }
}
```

### 4.2 Nouvelles méthodes de résolution

#### Résolution attribut personnel
```dart
Future<AnswerResult?> _resolvePersonalAttribute(String question) async {
  // Détection du type d'attribut demandé dans la question
  final requestedField = _matchFieldInQuestion(question, _allFields);
  if (requestedField == null) return null;

  final match = _meAttributes.where(
    (a) => a.field.id == requestedField.id,
  ).firstOrNull;

  if (match != null) {
    return AnswerResult(
      answerText: 'Votre ${match.field.name} est : ${match.attribute.attributeValue}',
      confidence: 'Fort',
      values: [AnswerValue(label: match.field.name, value: match.attribute.attributeValue)],
    );
  }
  return null;
}
```

#### Résolution relation + attribut
```dart
Future<AnswerResult?> _resolveRelationAttribute(String question) async {
  // 1. Trouver la relation demandée (conjoint, enfant, parent...)
  final requestedRelation = _matchRelationInQuestion(question, _relationTypesByCode);
  if (requestedRelation == null) return null;

  // 2. Filtrer les relations de l'entité "Moi"
  final matchingRelations = _meRelations.where(
    (r) => r.relationType.id == requestedRelation.id,
  ).toList();
  if (matchingRelations.isEmpty) return null;

  // 3. Si un attribut est aussi demandé (ex: "téléphone de mon conjoint")
  final requestedField = _matchFieldInQuestion(question, _allFields);
  if (requestedField != null) {
    final sb = StringBuffer();
    for (final rel in matchingRelations) {
      final targetAttrs = await attrProvider.getAttributesWithFields(
        rel.targetEntity.id, _allFields,
      );
      final match = targetAttrs.where(
        (a) => a.field.id == requestedField.id,
      ).firstOrNull;
      if (match != null) {
        sb.writeln('Le ${match.field.name} de ${rel.targetEntity.label} est : ${match.attribute.attributeValue}');
      }
    }
    if (sb.isNotEmpty) {
      return AnswerResult(answerText: sb.toString().trim(), confidence: 'Fort');
    }
  }

  // 4. Sinon, lister les entités liées
  final names = matchingRelations.map((r) => r.targetEntity.label).join(', ');
  return AnswerResult(
    answerText: 'Votre ${requestedRelation.label} : $names',
    confidence: 'Fort',
    values: matchingRelations.map((r) => AnswerValue(
      label: r.relationType.label,
      value: r.targetEntity.label,
    )).toList(),
  );
}
```

#### Résolution entités par type
```dart
Future<AnswerResult?> _resolveEntitiesByType(String question) async {
  final requestedType = _matchEntityTypeInQuestion(question, _entityTypesByCode);
  if (requestedType == null) return null;

  final matching = _allEntities.where(
    (e) => e.entityTypeId == requestedType.id && e.id != _meEntity!.id,
  ).toList();

  if (matching.isEmpty) return null;

  final names = matching.map((e) => e.label).join(', ');
  return AnswerResult(
    answerText: '${requestedType.label}s : $names',
    confidence: 'Fort',
    values: matching.map((e) => AnswerValue(label: e.label, value: e.label)).toList(),
  );
}
```

---

## 5. Exemples concrets de traitement

### 5.1 "Quel est mon numéro de téléphone ?"

```
Question → QaEngineV2.answer()
  → _loadContext() : charge entité "Moi", ses attributs, ses relations
  → _resolvePersonalAttribute()
      → _matchFieldInQuestion("téléphone") trouve AnalyticalField(name: "Téléphone")
      → _meAttributes où field.name == "Téléphone"
      → trouve EntityAttribute(attributeValue: "06 12 34 56 78")
      → AnswerResult("Votre Téléphone est : 06 12 34 56 78", confidence: 'Fort')
```

**Avant :** `UserProfile.phone` (SharedPrefs)
**Après :** `EntityAttributeProvider.getAttributesWithFields(meId, fields) → attributeValue` (Supabase)

### 5.2 "Quelle est l'adresse de ma résidence principale ?"

```
Question → QaEngineV2.answer()
  → _loadContext()
  → _resolveEntitiesByType()
      → _matchEntityTypeInQuestion("résidence principale") trouve EntityType(code: 'maison')
      → _allEntities où entityTypeId == maisonTypeId ET id != meId
      → trouve Entity(label: "Maison familiale")
  → _resolvePersonalAttribute() sur cette entité
      → _matchFieldInQuestion("adresse") trouve AnalyticalField(name: "Adresse")
      → EntityAttributeProvider.getAttributesWithFields(maison.id, fields)
      → trouve EntityAttribute(attributeValue: "12 Rue des Lilas, 75001 Paris")
      → AnswerResult("L'adresse de Maison familiale est : 12 Rue des Lilas, 75001 Paris")
```

**Avant :** `UserProfile.adressePostale` + `AnalyticalValue.category == 'résidence principale'`
**Après :** `EntityProvider.getEntitiesByType('maison')` + `EntityAttributeProvider.getAttributesWithFields()`

### 5.3 "Quel est le numéro de téléphone de mon conjoint ?"

```
Question → QaEngineV2.answer()
  → _loadContext()
  → _resolveRelationAttribute()
      → _matchRelationInQuestion("conjoint") trouve RelationType(code: 'conjoint')
      → _meRelations filtré par relationTypeId == conjointTypeId
      → trouve AnalyticalRelation où targetEntity.label = "Marie"
      → _matchFieldInQuestion("téléphone") trouve AnalyticalField(name: "Téléphone")
      → EntityAttributeProvider.getAttributesWithFields(marie.id, fields)
      → trouve EntityAttribute(attributeValue: "06 98 76 54 32")
      → AnswerResult("Le Téléphone de Marie est : 06 98 76 54 32")
```

**Avant :** `AnalyticalValue.relation == 'conjoint'` sur champ "Personne"
**Après :** `RelationProvider.getAllRelationsWithDetails(meId)` filtré par `relationType.code == 'conjoint'`

### 5.4 "Quelle est la date de naissance de mon fils ?"

```
Question → QaEngineV2.answer()
  → _resolveRelationAttribute()
      → _matchRelationInQuestion("fils") trouve RelationType(code: 'enfant')
      → _meRelations filtré par enfantTypeId
      → trouve AnalyticalRelation où targetEntity.label = "Lucas"
      → _matchFieldInQuestion("date de naissance") trouve AnalyticalField(name: "Date de naissance")
      → EntityAttributeProvider.getAttributesWithFields(lucas.id, fields)
      → AnswerResult("La Date de naissance de Lucas est : 15/03/2018")
```

**Avant :** Non géré (aucun champ 'date_naissance' dans AnalyticalValue)
**Après :** Résolu via EntityAttribute avec field.name == "Date de naissance"

### 5.5 "Quelle est l'immatriculation de ma voiture ?"

```
Question → QaEngineV2.answer()
  → _resolveEntitiesByType()
      → _matchEntityTypeInQuestion("voiture") trouve EntityType(code: 'voiture')
      → _allEntities filtré par voitureTypeId
      → trouve Entity(label: "Tesla Model 3")
      → _matchFieldInQuestion("immatriculation") trouve AnalyticalField(name: "Immatriculation")
      → EntityAttributeProvider.getAttributesWithFields(tesla.id, fields)
      → AnswerResult("L'immatriculation de Tesla Model 3 est : AA-123-BB")
```

**Avant :** `AnalyticalValue.category == 'véhicule principal'` + pas de champ immatriculation
**Après :** `EntityProvider.getEntitiesByType('voiture')` + `EntityAttributeProvider.getAttributesWithFields()`

---

## 6. Gestion des ambiguïtés

### Règle fondamentale : jamais de choix arbitraire
Si plusieurs entités, attributs ou types correspondent à la même requête, le moteur **ne doit jamais** choisir arbitrairement. Il doit :
1. Retourner une réponse d'ambiguïté listant les candidates
2. Permettre à l'utilisateur de préciser sa question

### 6.1 Plusieurs entités du même type
```dart
// Exemple : "mes enfants" → 3 enfants
if (values.length > 1) {
  return AnswerResult(
    answerText: 'Vous avez ${values.length} enfants :\n'
        '${values.map((v) => '• ${v.label}').join('\n')}',
    confidence: 'Fort',
    values: values.map((v) => AnswerValue(label: v.label, value: v.label)).toList(),
  );
}
```

### 6.2 Plusieurs attributs sur une entité
```dart
// Exemple : EntityAttribute "Téléphone personnel" + "Téléphone professionnel"
// La question "Quel est mon téléphone ?" est ambiguë
if (matchingAttributes.length > 1) {
  return AnswerResult(
    answerText: 'J\'ai trouvé plusieurs informations correspondant à votre demande :\n'
        '${matchingAttributes.map((a) => '• ${a.field.name}').join('\n')}\n'
        'Pouvez-vous préciser ?',
    confidence: 'Moyen',
    values: matchingAttributes.map((a) => AnswerValue(
      label: a.field.name,
      value: a.attribute.attributeValue,
    )).toList(),
  );
}
```

### 6.3 Plusieurs champs dans la question
```dart
// Exemple : "Quel est mon numéro ?"
// → "Numéro de téléphone", "Numéro de sécurité sociale", "Numéro de contrat"
// Le moteur ne choisit PAS : il retourne la liste des champs possibles
if (matchingFields.length > 1) {
  return AnswerResult(
    answerText: 'Plusieurs informations correspondent :\n'
        '${matchingFields.map((f) => '• ${f.name}').join('\n')}\n'
        'Laquelle souhaitez-vous consulter ?',
    confidence: 'Moyen',
  );
}
```

### 6.4 Aucune donnée trouvée
```dart
return AnswerResult(
  answerText: 'Je n\'ai pas trouvé cette information dans vos données.',
  confidence: 'Faible',
);
```

### 6.5 Matching flou
Utiliser les `relationTypeProvider.getSynonyms()` pour élargir la recherche :
```dart
// "ma femme" → synonyme de "conjoint"
final synonyms = await relationTypeProvider.getSynonyms(conjointTypeId);
// synonyms == ['conjoint', 'conjointe', 'époux', 'épouse', 'femme', 'mari', 'partenaire']
```

Utiliser `AnalyticalFieldProvider.findMatches()` pour le matching d'entités dans le texte :
```dart
final matches = fieldProvider.findMatches(question);
// matches : List<AnalyticalValueMatch> avec confidence 95%, 80%, 70%
// (existe déjà, utilise les synonymes de SemanticRelationEngine)
```

---

## 7. Plan de migration en 4 sous-phases

### Phase 5.1 — Refonte du nouveau QaEngine (fondations)
**Complexité :** Moyenne (3-4 jours)
**Fichiers :** Nouveau `lib/services/qa_session_cache.dart`, Nouveau `lib/services/qa_engine_v2.dart`

- [ ] Créer `QaSessionCache` : cache de session avec TTL 5 minutes, chargement parallèle `Future.wait`
- [x] Ajouter la règle d'ambiguïté (Section 10) : jamais de choix arbitraire
- [ ] Créer `QaEngineV2` : service stateless avec dépendances passées en paramètres (pattern `EntityProvider.getMeEntity()`)
- [ ] Implémenter `_loadContext()` : chargement parallèle de "Moi", attributs, types de champs
- [ ] Implémenter `_matchFieldInQuestion()` : matching dynamique des mots-clés question → `AnalyticalField.name`
- [ ] Implémenter `_matchRelationInQuestion()` : matching → `RelationType` (squelette pour 5.2)
- [ ] Implémenter `_matchEntityTypeInQuestion()` : matching → `EntityType` (squelette pour 5.2)
- [ ] Implémenter `_resolvePersonalAttribute()` : attributs de l'entité "Moi" (Pattern A) avec ambiguïté
- [ ] Règle d'ambiguïté dans `_resolvePersonalAttribute()` : si plusieurs attributs → réponse liste, pas de choix arbitraire

### Phase 5.2 — Résolution relations et entités liées
**Complexité :** Moyenne (3-4 jours)
**Fichiers modifiés :** `lib/services/qa_session_cache.dart`, `lib/services/qa_engine_v2.dart`

- [x] Règle d'ambiguïté identique relations + types d'entités (section 11.1)
- [ ] Logs métier structurés (section 12) — pattern, champs, relations, types, confiance, échec
- [ ] Mettre à jour `QaSessionCache` : ajouter `meRelations` (List<EntityRelationWithEntities>), `relationTypesByCode` (Map)
- [ ] Mettre à jour `_loadContext()` : charger relations parallèlement
- [ ] Refactorer `answer()` : parse unique → matchedFields, matchedRelations, matchedEntityTypes → pipeline 4 stages
- [ ] Implémenter `_resolveRelationAttribute()` (Stage 2) : Pattern B (relation + attribut) + Pattern D (listage)
- [ ] Implémenter `_resolveEntitiesByType()` (Stage 3) : Pattern C (type + attribut) + Pattern D (listage)
- [ ] Ambiguïté standardisée pour entités multiples (2-5 → liste, 6+ → top 5 + compteur)
- [ ] Supprimer les `// ignore: unused_element` des stubs (maintenant utilisés)

### Phase 5.3 — Remplacement des appels legacy + fallback documents
**Complexité :** Faible (1-2 jours)
**Stratégie : Migration progressive — QaEngineV2 prioritaire, legacy en fallback temporaire**

```
CardProvider.ask()
    │
    ├── QaEngineV2.answer() ← PRIORITAIRE
    │     └── Si succès (confidence ≥ 'Moyen') → retour direct
    │
    └── QaEngine.answer() ← FALLBACK TEMPORAIRE
          └── Legacy (documents + AnalyticalField)
```

**Règle de bascule :** QaEngineV2 est prioritaire. Le legacy est appelé UNIQUEMENT si :
- QaEngineV2 retourne `confidence: 'Faible'` (pattern non trouvé ou fallback V2)
- QaEngineV2 lève une exception

**Durée du fallback :** 2 semaines d'observation en production, puis suppression complète de QaEngine legacy.

- [ ] Rediriger `CardProvider.ask()` : QaEngineV2 prioritaire, QaEngine legacy en fallback
- [ ] Injection des providers V2 dans CardProvider (constructeur optionnel)
- [ ] Règle de bascule : fallback uniquement si V2 retourne confidence 'Faible'
- [ ] Conserver `QaEngine` legacy comme fallback temporaire (sans modif)
- [ ] Observations : logs métier V2 + comparaison des réponses legacy
- [ ] Supprimer les appels à `AnalyticalFieldDao` dans la QA (garder dans AnalyticalFieldProvider)
- [ ] Supprimer `_isPersonalQuery()`, `_detectRequestedInfo()`, `_getProfileValue()`
- [ ] Remplacer `_buildSemanticAnswer()` par la nouvelle génération
- [ ] **2 semaines après stabilisation :** Supprimer QaEngine + dépendances legacy

### Phase 5.4 — Refonte de `SemanticRelationEngine`
**Complexité :** Élevée (4-5 jours)

- [ ] Remplacer les 4 maps hardcodées par des lookups dynamiques
- [ ] `_familyRelations` → `RelationTypeProvider.getSynonyms()`
- [ ] `_housingCategories` + `_vehicleCategories` → `EntityTypeProvider.getTypeByCode()`
- [ ] `_semanticGroups` → combinaison EntityType + RelationType
- [ ] `findEntitiesBySemanticQuery()` → `RelationProvider.getAllRelationsWithDetails()` + `EntityProvider.getEntitiesByType()`
- [ ] `getRelationSuggestions()` → `RelationTypeProvider` (dynamique)
- [ ] `getRelationSynonyms()` → `CloudRepository.getRelationSynonyms()`
- [ ] Mettre à jour les 3 callers UI (settings_screen, analytical_value_detail_screen)
- [ ] Supprimer la dépendance à `AnalyticalValue` de `SemanticRelationEngine`

### En option : unification des pipelines
**Complexité :** Moyenne (2-3 jours)
**À faire APRÈS stabilisation**

- [ ] Unifier les deux classes `AnswerResult` (search vs QA)
- [ ] Harmoniser `SearchProvider` et `CardProvider`
- [ ] Supprimer le double appel (IntelligentSearch + QaEngine) dans HomeScreen

---

## 8. Risques techniques et performance

### 8.1 Risques

| Risque | Impact | Mitigation |
|--------|--------|-----------|
| Perte de données legacy avant migration complète | Les questions personnelles cessent de répondre | Migration progressive : nouveau QaEngineV2 coexiste avec l'ancien, fallback si nouveau échoue |
| Performance des requêtes cloud (N+1) | Latence sur chaque question | `_loadContext()` avec `Future.wait` parallèle ; `getEntityWithDetails()` batch ; cache de session |
| Complexité du matching linguistique | Faux positifs / faux négatifs | Commencer par matching exact (mot-clé → nom champ), enrichir avec synonymes progressivement |
| Données insuffisantes dans la nouvelle architecture | L'utilisateur n'a pas migré ses données legacy | Fallback automatique vers l'ancien système pendant la période de transition |
| Relations non orientées | Mauvaise interprétation du sens | `isOutgoing` flag existant dans `EntityRelationWithEntities` |

### 8.2 Performance

| Opération | Coût actuel | Coût futur | Note |
|-----------|------------|-----------|------|
| Chargement profil | 1 lecture SharedPrefs | 1 requête Supabase (`getUserProfile`) | ⚠️ Supabase plus lent mais nécessaire |
| Chargement attributs "Moi" | N/A (champs dans UserProfile) | 1 requête (`getEntityAttributes`) + 1 requête (`getAllAnalyticalFields`) | Acceptable si mis en cache |
| Chargement relations | N/A (AnalyticalValue.relation local) | 1 requête (`getAllEntityRelations`) avec batch entities + types | ✅ Déjà optimisé en batch |
| Chargement entités par type | 1 requête SQLite (AnalyticalFieldDao) | 1 requête (`getEntities`) | ✅ Comparable |
| Matching question → champ | Parcours de 5 patterns | Parcours de N fields + levenshtein ou index | N ~ 50-100, acceptable |

### 8.3 Stratégie de cache

```dart
// Cache par session (durée de vie = une question)
// À réinitialiser entre chaque question
class QaSessionCache {
  Entity? meEntity;
  List<EntityAttributeWithField> meAttributes;
  List<EntityRelationWithEntities> meRelations;
  List<AnalyticalField> allFields;
  List<Entity> allEntities;
  Map<String, EntityType> entityTypesByCode;
  Map<String, RelationType> relationTypesByCode;
  DateTime cachedAt;

  bool get isExpired => DateTime.now().difference(cachedAt) > const Duration(minutes: 5);
}
```

---

## 9. Résumé des impacts

### Fichiers créés
- `lib/services/qa_engine_v2.dart` — Nouveau moteur de réponse
- `lib/services/qa_session_cache.dart` — Cache de session

### Fichiers modifiés
- `lib/providers/card_provider.dart` — Redirection vers QaEngineV2
- `lib/services/qa_engine.dart` — Dépréciation, réduction au fallback documents
- `lib/ai/semantic_relation_engine.dart` — Refonte complète (Phase 5.4)
- `lib/screens/settings_screen.dart` — Mise à jour des appels à SemanticRelationEngine
- `lib/screens/analytical_value_detail_screen.dart` — Mise à jour des appels

### Fichiers supprimés (fin de migration)
- Dépendance à `AnalyticalFieldDao` dans QaEngine
- `_isPersonalQuery()`, `_detectRequestedInfo()`, `_getProfileValue()`
- 4 maps hardcodées dans SemanticRelationEngine

### Dépendances éliminées
- `UserProfileDao` (SharedPrefs) — remplacé par `EntityProvider.getMeEntity()`
- `AnalyticalFieldDao` — remplacé par `CloudRepository` via providers
- Champs legacy UserProfile (email, adressePostale, numeroSecuriteSociale)
- 4 maps hardcodées de synonymes/catégories
- `AnalyticalValue.relation` / `.category` / `.role`

---

## 10. Ordre de résolution des requêtes (pipeline V2.1)

### 10.1 Pipeline en 4 stages

```
Question entrante
    │
    ├── Stage 1 : Pattern A — Attribut direct [depth 0]
    │     Condition : la question mentionne un champ
    │     (téléphone, email, date de naissance, adresse, NIR, IBAN...)
    │     → Résoudre sur l'entité "Moi"
    │     → Si trouvé → AnswerResult (confiance 'Fort')
    │     → Si ambiguïté multi-champs → AmbiguityResult
    │     → Si pas trouvé ou pas de champ → continuer Stage 2
    │
    ├── Stage 2 : Pattern B — Relation + attribut [depth 1]
    │     Condition : la question mentionne une relation
    │     (conjoint, enfant, parent, collègue, ami, propriétaire, employeur...)
    │     ├── 2a : si champ aussi mentionné → attribut de l'entité liée
    │     ├── 2b : si aucun champ → listage des entités liées (Pattern D)
    │     → Si pas de relation → continuer Stage 3
    │
    ├── Stage 3 : Pattern C — Type d'entité + attribut [depth 1]
    │     Condition : la question mentionne un type d'entité
    │     (voiture, maison, contrat, animal, appareil, abonnement...)
    │     ├── 3a : si champ aussi mentionné → attribut de l'entité
    │     ├── 3b : si aucun champ → listage des entités du type (Pattern D)
    │     → Si pas de type → continuer Stage 4
    │
    └── Stage 4 : Fallback
          → "Je n'ai pas trouvé cette information dans vos données personnelles."
          → confiance 'Faible'
```

### 10.2 Règles de priorité entre stages

| Situation | Stage | Raison |
|-----------|-------|--------|
| Champ + relation + type | Stage 2 (relation) | La relation est plus spécifique que le type |
| Champ seul | Stage 1 (attribut direct) | Depth 0 prioritaire sur depth 1 |
| Relation + type (pas de champ) | Stage 2 (relation) | La relation est plus spécifique |
| Relation seule | Stage 2b (listage) | Pattern D via relation |
| Type seul | Stage 3b (listage) | Pattern D via type |

### 10.3 Parse unique en entrée

Les tokens (champs, relations, types) sont extraits **une seule fois** en début de pipeline
et réutilisés à chaque stage :

```dart
// Parse unique
final matchedFields = _matchFieldInQuestion(question, allFields);
final matchedRelations = _matchRelationInQuestion(question, relationTypesByCode);
final matchedEntityTypes = _matchEntityTypeInQuestion(question, entityTypesByCode);

// Stage 1 : attribut direct
if (matchedFields.isNotEmpty && matchedRelations.isEmpty && matchedEntityTypes.isEmpty) {
  final result = await _resolvePersonalAttribute(question, matchedFields, ...);
  if (result != null) return result;
}

// Stage 2 : relation + attribut
if (matchedRelations.isNotEmpty) {
  final result = await _resolveRelationAttribute(question, matchedRelations, matchedFields, ...);
  if (result != null) return result;
}

// Stage 3 : type + attribut
if (matchedEntityTypes.isNotEmpty) {
  final result = await _resolveEntitiesByType(question, matchedEntityTypes, matchedFields, ...);
  if (result != null) return result;
}

// Stage 4 : fallback
return AnswerResult(answerText: '...', confidence: 'Faible');
```

### 10.4 Comportement par pattern

| Pattern | Question exemple | Condition | Résolution |
|---------|-----------------|-----------|------------|
| A (depth 0) | "Quel est mon téléphone ?" | Champ, pas de relation, pas de type | Me → attribut |
| B (depth 1) | "Quel est le téléphone de mon conjoint ?" | Champ + relation | Me → relation → entité → attribut |
| C (depth 1) | "Quelle est l'immatriculation de ma voiture ?" | Champ + type d'entité | Me → entités du type → attribut |
| D relation | "Quels sont mes enfants ?" | Relation, pas de champ | Me → listage entités liées |
| D type | "Quelles sont mes voitures ?" | Type, pas de champ | Me → listage entités du type |

---

## 11. Gestion standardisée des ambiguïtés sur entités multiples

### 11.1 Règle impérative

> Le moteur **ne doit jamais** sélectionner arbitrairement une entité parmi plusieurs candidates.

**Cette règle s'applique de manière identique aux relations et aux types d'entités.**
- Relation (ex: "Quel est le téléphone de mon enfant ?" avec 3 enfants) → Ambiguity
- Type d'entité (ex: "Quelle est l'immatriculation de ma voiture ?" avec 2 voitures) → Ambiguity
- Champ (ex: "Quel est mon numéro ?" avec 3 champs contenant "numéro") → Ambiguity

Tous les cas suivent le même format standardisé (section 11.4).

### 11.2 Cas : plusieurs entités liées par une relation

```
Question : "Quel est le numéro de téléphone de mon enfant ?"
  → 3 enfants : Lucas, Emma, Chloé
  → Ambiguity :
    "Plusieurs entités correspondent à votre demande :\n
     • Lucas\n
     • Emma\n
     • Chloé\n
     Lequel souhaitez-vous consulter ?"
```

### 11.3 Cas : plusieurs entités d'un même type

```
Question : "Quelle est l'immatriculation de ma voiture ?"
  → 2 voitures : Tesla Model 3, Renault Clio
  → Ambiguity :
    "J'ai trouvé plusieurs voitures :\n
     • Tesla Model 3\n
     • Renault Clio\n
     Laquelle souhaitez-vous consulter ?"
```

### 11.4 Format standardisé

```dart
String _buildAmbiguityMessage({
  required String label,              // "enfant", "voiture", "maison", "contrat"
  required List<String> entityLabels, // ["Lucas", "Emma"]
  required bool singular,             // true si relation singulière, false si plurielle
}) {
  final verb = singular ? 'Lequel' : 'Lesquels';
  return 'J\'ai trouvé plusieurs $label :\n'
      '${entityLabels.map((l) => '• $l').join('\n')}\n'
      '$verb souhaitez-vous consulter ?';
}
```

Utilisation :
```dart
if (relatedEntities.length > 1) {
  return AnswerResult(
    answerText: _buildAmbiguityMessage(
      label: relationType.label.toLowerCase(),
      entityLabels: relatedEntities.map((e) => e.targetEntity.label).toList(),
      singular: true,
    ),
    confidence: 'Moyen',
  );
}
```

### 11.5 Cas particuliers

| Situation | Réponse | Confiance |
|-----------|---------|-----------|
| 0 entité trouvée | "Je n'ai pas trouvé..." | Faible |
| 1 entité trouvée | Résolution directe | Fort |
| 2-5 entités | Ambiguity listant chaque candidate | Moyen |
| 6+ entités | Ambiguity avec compteur + invitation | Moyen |

Pour 6+ entités :
```dart
return AnswerResult(
  answerText: 'J\'ai trouvé $count ${label}s.\n'
      'Les principaux :\n'
      '${entityLabels.take(5).map((l) => '• $l').join('\n')}\n'
      'et ${count - 5} autre(s).\n'
      'Pouvez-vous préciser laquelle vous souhaitez consulter ?',
  confidence: 'Moyen',
);
```

---

## 12. Logs métier de QaEngineV2

### 12.1 Objectif

Production de logs métier structurés pour :
- Tests utilisateurs sans debugger
- Mesure de la qualité réelle du moteur (taux de succès/échec par pattern)
- Analyse des échecs (motif, contexte manquant)
- Amélioration itérative du matching

### 12.2 Format

```dart
void _log(String stage, Map<String, dynamic> data) {
  print('[QA_V2] ═══════════════════════════════════════');
  print('[QA_V2] Stage: $stage');
  for (final entry in data.entries) {
    print('[QA_V2]   ${entry.key}: ${entry.value}');
  }
  print('[QA_V2] ═══════════════════════════════════════');
}
```

### 12.3 Points de logging

| Point | Stage | Données |
|-------|-------|---------|
| Parse entrée | answer() | question, matchedFields[], matchedRelations[], matchedEntityTypes[] |
| Pattern A | Stage 1 | pattern: 'A', found: true/false, confidence, result (ou failure_reason) |
| Pattern B/D | Stage 2 | pattern: 'B'/'D', relationCode, entityCount, confidence, result (ou failure_reason) |
| Pattern C/D | Stage 3 | pattern: 'C'/'D', typeCode, entityCount, confidence, result (ou failure_reason) |
| Fallback | Stage 4 | pattern: 'FALLBACK', reason |
| Ambiguity | Tout stage | type: 'ambiguity', candidates[], count |

### 12.4 Exemple de sortie pour une requête réussie

```
[QA_V2] ═══════════════════════════════════════
[QA_V2] Stage: PARSE
[QA_V2]   question: "Quel est le téléphone de mon conjoint ?"
[QA_V2]   fields: "Téléphone"
[QA_V2]   relations: "conjoint"
[QA_V2]   types: ""
[QA_V2] ═══════════════════════════════════════
[QA_V2] ═══════════════════════════════════════
[QA_V2] Stage: STAGE2
[QA_V2]   pattern: "B"
[QA_V2]   relationCode: "conjoint"
[QA_V2]   entityCount: 1
[QA_V2]   confidence: "Fort"
[QA_V2]   result: "Le téléphone de Marie est : 06 98 76 54 32"
[QA_V2] ═══════════════════════════════════════
```

### 12.5 Exemple de sortie pour une ambiguïté

```
[QA_V2] ═══════════════════════════════════════
[QA_V2] Stage: PARSE
[QA_V2]   question: "Quelle est l'immatriculation de ma voiture ?"
[QA_V2]   fields: "Immatriculation"
[QA_V2]   relations: ""
[QA_V2]   types: "voiture"
[QA_V2] ═══════════════════════════════════════
[QA_V2] ═══════════════════════════════════════
[QA_V2] Stage: STAGE3
[QA_V2]   pattern: "C"
[QA_V2]   typeCode: "voiture"
[QA_V2]   entityCount: 2
[QA_V2]   confidence: "Moyen"
[QA_V2]   ambiguity: true
[QA_V2]   candidates: "Tesla Model 3, Renault Clio"
[QA_V2]   result: "J'ai trouvé plusieurs voitures..."
[QA_V2] ═══════════════════════════════════════
```

---

## 13. Règles de conception supplémentaires

### Règle d'ambiguïté (ajoutée après validation Phase 4.1)
> **Si plusieurs entités ou attributs correspondent à une même requête, le moteur ne doit jamais choisir arbitrairement.**
> → Toujours retourner une réponse d'ambiguïté listant les candidates.

Cas concernés :
- Plusieurs champs matching la question (ex: "numéro" → téléphone + sécu + contrat)
- Plusieurs attributs d'une entité correspondant à la question
- Plusieurs entités du même type (ex: plusieurs voitures, plusieurs contrats)
- Plusieurs entités via une relation (ex: plusieurs enfants)

Dans tous ces cas, le moteur répond avec la liste des candidates et invite l'utilisateur à préciser.

---

## 11. Estimation de complexité

| Phase | Jours | Dépendances | Risque |
|-------|-------|------------|--------|
| 5.1 — Fondations QaEngineV2 | 3-4 | Aucune (nouveau fichier) | Faible |
| 5.2 — Relations + entités | 3-4 | 5.1 terminée | Moyen |
| 5.3 — Remplacement legacy | 1-2 | 5.2 terminée | Faible |
| 5.4 — Refonte SemanticRelationEngine | 4-5 | 5.3 terminée | Élevé |
| Unification pipelines (optionnel) | 2-3 | 5.4 terminée | Moyen |
| **Total** | **13-18** | | |
