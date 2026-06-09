# Lab 3 — DAST avec OWASP ZAP

**Durée estimée : 1h30** &nbsp;|&nbsp; **Stack : Python / Flask** &nbsp;|&nbsp; **Outil : OWASP ZAP**

---

## Contexte

L'API `freemobile-netops-api` (gestion des abonnés réseau NOC) va partir en production.
Votre mission : mettre en place un pipeline DAST qui détecte automatiquement les vulnérabilités à chaque push.

Contrairement au SAST qui lit le code, le DAST teste l'application **en cours d'exécution** — comme un attaquant le ferait.

---

## Prérequis

| Outil | Vérification |
|-------|-------------|
| Docker | `docker --version` |
| Docker Compose | `docker compose version` |
| Compte GitHub | accès à l'onglet Actions |

---

## Structure du projet

```
Lab3/
├── app.py                        ← API Flask (intentionnellement vulnérable)
├── requirements.txt
├── docker-compose.yml
├── attack-simulation.sh          ← Simulation d'attaque
└── .github/
    └── workflows/
        └── security.yml          ← Pipeline CI à compléter
```

---

## Étape 0 — Lancer l'application

```bash
docker compose up -d
curl http://localhost:5000/health
```

---

## Étape 1 — Simulation d'attaque

```bash
bash attack-simulation.sh
```

Analysez les résultats — vous venez de voir ce qu'un attaquant peut faire contre cette API.

---

## Étape 2 — Construire la pipeline CI

Complétez `.github/workflows/security.yml` pour que la pipeline :
1. Démarre l'application
2. Lance un scan ZAP baseline
3. Échoue si des vulnérabilités sont détectées

> **Référence :** [github.com/zaproxy/action-baseline](https://github.com/zaproxy/action-baseline)

```bash
git add .github/workflows/security.yml
git commit -m "ci: pipeline ZAP"
git push
```

Observez le résultat sur l'onglet **Actions**. La pipeline doit échouer — ZAP a détecté des vulnérabilités.

> **Note :** Dans ce lab, vous démarrez l'application dans la pipeline faute d'environnement dédié. En entreprise, l'application tourne en permanence sur un environnement de staging et la pipeline pointe ZAP directement dessus — sans avoir à la démarrer. Le pattern réel est : `build → deploy staging → ZAP scan → deploy prod`.

---

## Étape 3 — Analyser le rapport ZAP

Téléchargez le rapport généré par ZAP depuis les artefacts du job GitHub Actions.

**Questions :**
- Combien de vulnérabilités ZAP a-t-il détectées ?
- Lesquelles le script d'attaque avait-il déjà démontrées ?
- Y a-t-il des findings que ZAP a trouvés mais que le script n'avait pas couverts ?
- Quelle est la différence entre un scan DAST et un scan SAST ?

---

## Livrables attendus

- La sortie de `bash attack-simulation.sh`.
- La pipeline CI en échec sur le code vulnérable (screenshot GitHub Actions).
- Le rapport ZAP (artefact téléchargé depuis Actions).
- Réponses aux questions de l'étape 3.
