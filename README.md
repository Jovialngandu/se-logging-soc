# SE Logging SOC - Centralisation dynamique, normalisation et stockage de logs (Rsyslog, Fluentd, Loki & Docker)

Ce projet fournit une infrastructure SOC / SIEM de collecte, de normalisation et d'ingestion de logs système (`syslog`) et de surveillance d'intégrité de fichiers (`fim`). Les événements sont ingérés par Rsyslog, structurés en JSON enrichi via Fluentd, puis stockés dans Grafana Loki pour l'analyse et la visualisation.

---

## 🏗️ Architecture du Projet

```text
se-logging-soc/
├── config/
│   ├── client/
│   │   ├── Dockerfile             # Image Alpine avec sshd, rsyslog & glib (gio)
│   │   ├── entrypoint.sh          # Substitution d'IP d'ingestion & boucle FIM
│   │   └── rsyslog-client.conf    # Transfert syslog vers le serveur central
│   ├── fluentd/
│   │   └── fluent.conf            # Normalisation JSON, extraction Regex & export Loki
│   └── rsyslog/
│       └── rsyslog.conf           # Réceptacle central UDP/TCP + templates dynamiques
├── logs/                          # Volume hôte des logs centralisés
└── docker-compose.yml
```

## 🛡️ Fonctionnalités & Captures de Sécurité

* **Journaux d'accès & SSH (`sshd`) :** Collecte et extraction des tentatives de connexion, IP sources, ports et sessions d'authentification.
* **Surveillance d'Intégrité de Fichiers (FIM - `fim_event`) :** Surveillance en temps réel des modifications sur les fichiers critiques (`/etc/passwd`) via `gio monitor` (`glib`).
* **Normalisation & Parsing Fluentd :** Transformation des logs bruts texte en objets JSON structurés avec enrichissement dynamique (`log_time`, `hostname`, `program`, `pid`, `src_ip`, `target_file`).
* **Stockage & Indexation Loki :** Expédition et stockage centralisé des flux dans Grafana Loki (`http://soc-loki:3100`), prêts pour la consommation par le dashboard ou les requêtes LogQL.
* **Journalisation de démarrage (`client_init`) :** Signaux de boot client confirmant la liaison avec le SOC central.

## 🚀 Déploiement & Modes d'exécution

### Mode 1 : Environnement de test local (1 seul PC)
Tous les services démarrent sur la même machine hôte au sein d'un réseau Docker isolé.



```bash


# 0. Configurer les autorisations sur le dossier de logs
chmod -R 777 ./logs


# 1. on restart le client 
docker restart soc-client-alpine


# 2. Lancer la stack complète (Rsyslog, Fluentd, Loki & Client)
docker compose up -d --build

# 3. Tester la génération de logs SSH
ssh root@localhost -p 2222

# 4. Tester la détection FIM (Modification de fichier critique)
docker exec -it soc-client-alpine touch /etc/passwd

# 5. Consulter la sortie structurée JSON dans Fluentd
docker logs -f soc-fluentd
```

### Mode 2 : Déploiement distribué / Multi-équipements (2 PC en LAN)
Ce mode simule un serveur SOC central collectant, normalisant et stockant les événements de sécurité provenant d'un équipement distant sur un réseau local (LAN).

#### Étape 1 : Sur le PC Serveur (SOC Central : Rsyslog + Fluentd + Loki)
Récupérer l'adresse IP du PC Serveur (ex: `192.168.1.50`). Lancer les services centraux :

```bash
chmod -R 777 ./logs
docker compose up -d rsyslog-central fluentd loki
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
* **Vérification des flux normalisés dans Fluentd :**
  ```bash
  docker logs -f soc-fluentd
  ```
* **Vérification du stockage dans Loki via l'API REST LogQL :**
  ```bash
  # Vérifier l'arrivée des logs rsyslog
  curl -G -s 'http://localhost:3100/loki/api/v1/query_range' \
    --data-urlencode 'query={job="rsyslog"}' | jq .data.result

  # Filtrer spécifiquement les événements FIM
  curl -G -s 'http://localhost:3100/loki/api/v1/query_range' \
    --data-urlencode 'query={program="fim_event"}' | jq .data.result
  ```

## 🔒 Détails des Composants

* **Serveur Rsyslog Central :** Écoute sur les ports `514 UDP/TCP`. Utilise un filtre dynamique `omfile` qui catégorise automatiquement les logs bruts par dossier d'adresse IP (`logs/%fromhost-ip%/%programname%.log`).
* **Moteur de Parsing Fluentd (`grafana/fluent-plugin-loki`) :** Ingeste les fichiers de logs générés par Rsyslog (`/var/log/remote/*/*.log`). Applique un parsing Regex pour découper les en-têtes Syslog, enrichit le JSON via un transformateur Ruby (`src_ip`, `target_file`), puis expédie les événements structurés vers Loki.
* **Grafana Loki (`grafana/loki:2.9.2`) :** Moteur de stockage de logs horodatés. Indexe dynamiquement les flux par labels (`job="rsyslog"`, `env="soc"`, `program`, `hostname`) et fournit l'endpoint REST (`:3100`) pour les requêtes LogQL.
* **Client Alpine & Moteur FIM :** Exécute un serveur OpenSSH (`sshd`) et un démon `rsyslogd` local. Il emploie `gio monitor` (`glib`) pour la surveillance événementielle asynchrone des fichiers sensibles sans blocage de tampon. Il transmet instantanément tous les flux (`auth`, `authpriv`, `fim_event`, `client_init`) vers le récepteur central via `UDP/514`.
