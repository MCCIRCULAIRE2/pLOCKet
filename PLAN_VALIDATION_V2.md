# Plan de validation fonctionnelle — QaEngineV2

## Prérequis

- Entité "Moi" créée (via `EntityProvider.getMeEntity()`)
- Au moins un attribut sur "Moi" (ex: Téléphone, Email)
- Au moins une entité liée avec une relation (ex: Conjoint avec téléphone)
- Au moins une entité par type (ex: Voiture, Maison)

## Pattern A — Attributs directs (Stage 1)

### Succès

| # | Question | Condition | Réponse attendue | Confiance |
|---|----------|-----------|-----------------|-----------|
| A1 | "Quel est mon téléphone ?" | Me possède Téléphone | "Votre téléphone est : 06 12 34 56 78" | Fort |
| A2 | "Quel est mon email ?" | Me possède Email | "Votre email est : jean@example.com" | Fort |
| A3 | "Quelle est ma date de naissance ?" | Me possède Date de naissance | "Votre date de naissance est : 15/03/1985" | Fort |
| A4 | "Quel est mon nom ?" | Me possède Nom complet | "Votre nom complet est : Jean Dupont" | Fort |

### Ambiguïté

| # | Question | Condition | Réponse attendue | Confiance |
|---|----------|-----------|-----------------|-----------|
| A5 | "Quel est mon numéro ?" | Champs multiples (téléphone, sécu, contrat) | "Plusieurs informations correspondent : • Téléphone • Numéro de sécurité sociale • Numéro de contrat" | Moyen |

### Absence

| # | Question | Condition | Réponse attendue | Confiance |
|---|----------|-----------|-----------------|-----------|
| A6 | "Quel est mon IBAN ?" | Champ matché mais pas d'attribut | "Je n'ai pas trouvé votre iban dans vos données." | Faible |
| A7 | "Quel est mon code postal ?" | Aucun champ matché | Stage 4 : "Je n'ai pas trouvé cette information..." | Faible |

---

## Pattern B — Relations (Stage 2)

### Succès

| # | Question | Condition | Réponse attendue | Confiance |
|---|----------|-----------|-----------------|-----------|
| B1 | "Quel est le téléphone de mon conjoint ?" | 1 conjoint + attribut téléphone | "Le téléphone de Marie est : 06 98 76 54 32" | Fort |
| B2 | "Quelle est la date de naissance de mon fils ?" | 1 enfant + attribut date naissance | "La date de naissance de Lucas est : 15/03/2018" | Fort |
| B3 | "Quelle est l'adresse de mon employeur ?" | 1 employeur + attribut adresse | "L'adresse de Acme Corp est : 12 Rue du Commerce" | Fort |

### Ambiguïté

| # | Question | Condition | Réponse attendue | Confiance |
|---|----------|-----------|-----------------|-----------|
| B4 | "Quel est le téléphone de mon enfant ?" | Relation enfant, 3 entités | "J'ai trouvé plusieurs enfants : • Lucas • Emma • Chloé\nPouvez-vous préciser ?" | Moyen |
| B5 | "Quel est le téléphone de mon collègue ?" | Relation collègue, 6+ entités | "J'ai trouvé plusieurs collègues : • Alice • Bob • Charles • Diane • Eric\net 3 autre(s).\nPouvez-vous préciser ?" | Moyen |

### Absence

| # | Question | Condition | Réponse attendue | Confiance |
|---|----------|-----------|-----------------|-----------|
| B6 | "Quel est le téléphone de mon conjoint ?" | Conjoint existe, pas de téléphone | "Je n'ai pas trouvé votre téléphone pour Marie." | Faible |
| B7 | "Quel est le téléphone de mon conjoint ?" | Aucun conjoint enregistré | Stage 3 puis Stage 4 : "Je n'ai pas trouvé..." | Faible |
| B8 | "Quel est le téléphone de mon chien ?" | Relation "chien" inconnue du système | Stage 3 puis Stage 4 : "Je n'ai pas trouvé..." | Faible |

---

## Pattern C — Types d'entités (Stage 3)

### Succès

| # | Question | Condition | Réponse attendue | Confiance |
|---|----------|-----------|-----------------|-----------|
| C1 | "Quelle est l'immatriculation de ma voiture ?" | 1 voiture + attribut immatriculation | "L'immatriculation de Tesla Model 3 est : AA-123-BB" | Fort |
| C2 | "Quelle est l'adresse de ma maison ?" | 1 maison + attribut adresse | "L'adresse de Maison familiale est : 12 Rue des Lilas" | Fort |
| C3 | "Quel est le numéro de mon contrat ?" | 1 contrat + attribut numéro | "Le numéro de contrat de Assurance habitation est : CONT-456" | Fort |

### Ambiguïté

| # | Question | Condition | Réponse attendue | Confiance |
|---|----------|-----------|-----------------|-----------|
| C4 | "Quelle est l'immatriculation de ma voiture ?" | 2 voitures | "J'ai trouvé plusieurs voitures : • Tesla Model 3 • Renault Clio\nPouvez-vous préciser ?" | Moyen |
| C5 | "Quelle est l'adresse de ma maison ?" | 3 maisons | "J'ai trouvé plusieurs maisons : • Résidence principale • Villa vacances • Appartement\nPouvez-vous préciser ?" | Moyen |

### Absence

| # | Question | Condition | Réponse attendue | Confiance |
|---|----------|-----------|-----------------|-----------|
| C6 | "Quelle est l'immatriculation de ma voiture ?" | Voiture existe, pas d'immatriculation | "Je n'ai pas trouvé votre immatriculation pour Tesla Model 3." | Faible |
| C7 | "Quelle est l'immatriculation de ma voiture ?" | Aucune voiture enregistrée | Stage 4 : "Je n'ai pas trouvé cette information..." | Faible |
| C8 | "Quelle est la superficie de mon terrain ?" | Type "terrain" inconnu du système | Stage 4 : "Je n'ai pas trouvé cette information..." | Faible |

---

## Pattern D — Listages (Stage 2b / 3b)

### Succès

| # | Question | Condition | Réponse attendue | Confiance |
|---|----------|-----------|-----------------|-----------|
| D1 | "Quels sont mes enfants ?" | 1 enfant | "Votre enfant : Lucas" | Fort |
| D2 | "Quelles sont mes voitures ?" | 1 voiture | "Votre voiture : Tesla Model 3" | Fort |

### Ambiguïté

| # | Question | Condition | Réponse attendue | Confiance |
|---|----------|-----------|-----------------|-----------|
| D3 | "Quels sont mes enfants ?" | 3 enfants | "J'ai trouvé plusieurs enfants : • Lucas • Emma • Chloé\nPouvez-vous préciser ?" | Moyen |
| D4 | "Quelles sont mes voitures ?" | 2 voitures | "J'ai trouvé plusieurs voitures : • Tesla Model 3 • Renault Clio\nPouvez-vous préciser ?" | Moyen |

### Absence

| # | Question | Condition | Réponse attendue | Confiance |
|---|----------|-----------|-----------------|-----------|
| D5 | "Quels sont mes enfants ?" | Aucun enfant | Stage 4 : "Je n'ai pas trouvé cette information..." | Faible |
| D6 | "Quelles sont mes voitures ?" | Aucune voiture | Stage 4 : "Je n'ai pas trouvé cette information..." | Faible |

---

## Tests multi-champs

| # | Question | Condition | Réponse attendue | Confiance |
|---|----------|-----------|-----------------|-----------|
| T1 | "Quel est mon téléphone et mon email ?" | Question contient 2 champs distincts | Le moteur parse uniquement (n'essaye pas d'être cumulatif) : "téléphone" matché AVANT "email" dans l'ordre du matching. Réponse : "Votre téléphone est : 06 12 34 56 78" (le premier champ matché uniquement). | Fort |
| T2 | "Quel est mon numéro et mon adresse ?" | "numéro" matché (multi) + "adresse" matché | Le matching multi-champs détecte 3+ champs → Ambiguity : "Plusieurs informations correspondent..." | Moyen |

**Note :** En V2.1, le moteur traite la première correspondance trouvée. Les questions composites (X et Y) sont hors périmètre — le moteur ne supporte pas le cumul de réponses.

---

## Tests de régression (non-régression)

| # | Question | Comportement attendu |
|---|----------|---------------------|
| R1 | "Qui est ma mère ?" | Relation "parent" matchée → Pattern D |
| R2 | "Quel âge a mon fils ?" | Stage 1 → Stage 2 → "Champ 'âge' non trouvé" (ou fallback) |
| R3 | "Quel est le téléphone de mon conjoint conducteur principal ?" | Stage 2 (conjoint prime sur "conducteur principal" qui n'est pas un type connu) |
| R4 | Question vide | Stage 4 : "Je n'ai pas trouvé..." |
| R5 | Question absurde ("blargh") | Stage 4 : "Je n'ai pas trouvé..." |

---

## Procédure de test

### Mode manuel (via console)
```dart
final engine = QaEngineV2();
final result = await engine.answer(
  question: "Quel est mon téléphone ?",
  entityProvider: context.read<EntityProvider>(),
  attrProvider: context.read<EntityAttributeProvider>(),
  // ... all providers
);
print(result.answerText);
```

### Critères de succès
- Chaque cas A1-D6 retourne *exactement* la réponse attendue
- Les logs métier sont visibles dans la console
- Les temps de réponse < 2s en mode cache chaud, < 5s en mode cache froid
- Aucune exception non gérée

### Critères d'échec
- Réponse incohérente avec la question (mauvais pattern)
- Choix arbitraire lors d'une ambiguïté (au lieu de la liste)
- Retour à la ligne manquant dans le message d'ambiguïté
- Confiance inappropriée (ex: "Fort" pour une absence)
