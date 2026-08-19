# SE Logging SOC - Centralisation dynamique de logs avec Rsyslog, Fluentd & Docker

Ce projet fournit une infrastructure de centralisation, de collecte et de normalisation de logs système (`syslog`) et de surveillance d'intégrité de fichiers (`fim`) pour une analyse de sécurité SOC / SIEM.

## 🏗️ Architecture du Projet

```text
se-logging-soc/
├── config/
│   ├── client/
│   │   ├── Dockerfile             # Image Alpine avec sshd, rsyslog & glib (gio)
│   │   ├── entrypoint.sh          # Substitution d'IP d'ingestion & boucle FIM
│   │   └── rsyslog-client.conf    # Transfert syslog vers le serveur central
│   ├── fluentd/
│   │   └── fluent.conf            # Normalisation JSON, extraction Regex & ingestion
│   └── rsyslog/
│       └── rsyslog.conf           # Réceptacle central UDP/TCP + templates dynamiques
├── logs/                          # Volume hôte des logs centralisés
└── docker-compose.yml
```

## 🛡️ Fonctionnalités & Captures de Sécurité

* **Journaux d'accès & SSH (`sshd`) :** Collecte et extraction des tentatives de connexion, IP sources, ports et sessions d'authentification.
* **Surveillance d'Intégrité de Fichiers (FIM - `fim_event`) :** Surveillance en temps réel des modifications sur les fichiers critiques (`/etc/passwd`) via `gio monitor` (`glib`).
* **Normalisation & Parsing Fluentd :** Transformation des logs bruts texte en objets JSON enrichis (`log_time`, `hostname`, `program`, `pid`, `src_ip`, `target_file`).
* **Journalisation de démarrage (`client_init`) :** Signaux de boot client confirmant la liaison avec le SOC central.

## 🚀 Déploiement & Modes d'exécution

### Mode 1 : Environnement de test local (1 seul PC)
Tous les services démarrent sur la même machine hôte au sein d'un réseau Docker isolé.

```bash
# 1. Donner les autorisations d'écriture au dossier de logs
chmod -R 777 ./logs

# 2. Lancer la stack complète (Rsyslog Central, Fluentd & Client)
docker compose up -d --build

# 3. Tester la génération de logs SSH
ssh root@localhost -p 2222

# 4. Tester la détection FIM (Modification de fichier critique)
docker exec -it soc-client-alpine touch /etc/passwd

# 5. Consulter la sortie structurée JSON dans Fluentd
docker logs -f soc-fluentd
```

### Mode 2 : Déploiement distribué / Multi-équipements (2 PC en LAN)
Ce mode simule un serveur SOC central collectant et normalisant les événements de sécurité provenant d'un équipement distant sur un réseau local (LAN).

#### Étape 1 : Sur le PC Serveur (SOC Central : Rsyslog + Fluentd)
Récupérer l'adresse IP du PC Serveur (ex: `192.168.1.50`). Lancer le récepteur central et le moteur de parsing :

```bash
chmod -R 777 ./logs
docker compose up -d rsyslog-central fluentd
```

#### Étape 2 : Sur le PC Client (Alpine Source)
Injecter l'adresse IP du PC Serveur au démarrage :

```bash
TARGET_IP=192.168.1.50 docker compose up -d --build client-alpine
```

#### Étape 3 : Test de démonstration & vérification
* **Test SSH :**
  ```bash
  ssh root@<ip_du_pc_client> -p 2222
  ```
* **Test d'intégrité FIM :**
  ```bash
  docker exec -it soc-client-alpine touch /etc/passwd
  ```
* **Vérification des logs bruts sur le serveur Rsyslog :**
  ```bash
  ls -la logs/<ip_du_pc_client>/
  tail -f logs/<ip_du_pc_client>/fim_event.log
  ```
* **Vérification des flux normalisés en JSON dans Fluentd :**
  ```bash
  docker logs -f soc-fluentd
  ```

## 🔒 Détails des Composants

* **Serveur Rsyslog Central :** Écoute sur les ports `514 UDP/TCP`. Utilise un filtre dynamique `omfile` qui catégorise automatiquement les logs bruts par dossier d'adresse IP (`logs/%fromhost-ip%/%programname%.log`).
* **Moteur de Parsing Fluentd :** Ingeste les fichiers de logs générés par Rsyslog (`/var/log/remote/*/*.log`). Applique un parsing Regex pour découper les en-têtes Syslog et utilise un transformateur Ruby dynamique pour enrichir le JSON avec les champs `src_ip` (connexions SSH) et `target_file` (alertes FIM).
* **Client Alpine & Moteur FIM :** Exécute un serveur OpenSSH (`sshd`) et un démon `rsyslogd` local. Il emploie `gio monitor` (`glib`) pour la surveillance événementielle asynchrone des fichiers sensibles sans blocage de tampon. Il transmet instantanément tous les flux (`auth`, `authpriv`, `fim_event`, `client_init`) vers le récepteur central via `UDP/514`.
