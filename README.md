# 💰 Budget Livreur

Application mobile (Flutter) de gestion de budget pour livreurs Uber Eats / Deliveroo.

## Fonctionnalités

- **Multi-profils** : jusqu'à 4 profils séparés
- **Calcul URSSAF** : 22% par défaut, configurable
- **Revenus séparés** : 🚚 Livraison (compte dans l'objectif) / 💵 Autre (APL, RSA, etc.)
- **Virements** : hebdomadaire (gratuit) ou instantané (0.99€/jour avec revenu)
- **Factures** : à cocher une par une ou via le total des charges
  - Récurrentes (chaque mois) → reportées automatiquement
  - Suppression par swipe
- **Économies** : visualisation des dépenses non essentielles
- **Conseils** : alertes contextuelles (objectif atteint, manque à gagner, etc.)
- **Export** : rapport texte dans le presse-papiers
- **Mode sombre / clair** : thème adaptatif

## Stack technique

- **Framework** : Flutter 3.x
- **Stockage** : SharedPreferences (local, par profil)
- **Langue** : Français (FR)
- **Devise** : Euros (€)

## Lancer en local

```bash
flutter pub get
flutter run
```

## Build APK

```bash
flutter build apk --debug    # debug
flutter build apk --release  # release
```

## Structure

- `lib/main.dart` : toute l'application (point d'entrée unique)
- `android/` : configuration Android
- Stockage par profil via `SharedPreferences` (clé `budget-data-{profileId}`)

## Licence

Projet personnel.
