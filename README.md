# se logging soc - centralisation dynamique de logs avec rsyslog & docker

Ce projet fournit une infrastructure légère de centralisation et collecte de logs système (syslog) et de surveillance d'intégrité de fichiers (fim) à des fins de surveillance soc et d'analyse de sécurité.

## 🏗️ Architecture du Projet

```text
se-logging-soc/
├── config/
│   ├── client/
│   │   ├── dockerfile             # Image alpine avec sshd, rsyslog & glib (gio)
│   │   ├── entrypoint.sh          # Substitution d'ip d'ingestion & boucle fim (gio)
│   │   └── rsyslog-client.conf    # Transfert syslog vers le serveur central
│   └── rsyslog/
│       └── rsyslog.conf           # Réceptacle central udp/tcp + templates dynamiques
├── logs/                          # Volume hôte des logs centralisés
└── docker-compose.yml
```

## 🛡️ Fonctionnalités & Captures de Sécurité

* **Journaux d'accès & SSH (sshd) :** Collecte des tentatives de connexion, sessions ouvertes/fermées et fermetures de dæmons.
* **Surveillance d'Intégrité de Fichiers (FIM - fim_event) :** Surveillance en temps réel des modifications sur les fichiers critiques (`/etc/passwd`) via `gio monitor` (glib).
* **Journalisation de démarrage (client_init) :** Signaux de boot client confirmant la liaison avec le soc central.

## 🚀 Déploiement & Modes d'exécution

### Mode 1 : Environnement de test local (1 seul PC)

Tous les services démarrent sur la même machine hôte au sein d'un sous-réseau docker isolé.

```bash
# 1. Donner les autorisations d'écriture au dossier de logs
chmod -R 777 ./logs

# 2. Lancer les conteneurs
docker compose up -d --build

# 3. Tester la génération de logs SSH
ssh root@localhost -p 2222

# 4. Tester la détection FIM (Modification de fichier critique)
docker exec -it soc-client-alpine touch /etc/passwd

# 5. Consulter les logs centralisés
cat logs/172.18.0.*/sshd.log
cat logs/172.18.0.*/fim_event.log
```

### Mode 2 : Déploiement distribué / Multi-équipements (2 PC en LAN)

Ce mode simule un serveur soc central collectant les événements de sécurité provenant d'un équipement distant sur un réseau local (LAN).

#### Étape 1 : Sur le PC Serveur (Rsyslog Central)

Récupérer l'adresse IP du PC Serveur (ex: `192.168.1.50`). Lancer le service central :

```bash
chmod -R 777 ./logs
docker compose up -d rsyslog-central
```

#### Étape 2 : Sur le PC Client (Alpine Source)

Injecter l'adresse IP du PC Serveur au démarrage :

```bash
syslog_server_ip=192.168.1.50 docker compose up -d --build client-alpine
```

#### Étape 3 : Test de démonstration

Test SSH :

```bash
ssh root@<ip_du_pc_client> -p 2222
```

Test d'intégrité FIM :

```bash
docker exec -it soc-client-alpine touch /etc/passwd
```

Vérification en temps réel sur le PC Serveur :

```bash
ls -la logs/<ip_du_pc_client>/
tail -f logs/<ip_du_pc_client>/fim_event.log
```

## 🔒 Détails des Composants

* **Serveur Rsyslog Central :** Écoute sur les ports `514 udp/tcp`. Utilise un filtre dynamique `omfile` qui catégorise automatiquement les logs par dossier d'adresse IP (`logs/%fromhost-ip%/%programname%.log`).
* **Client Alpine & Moteur FIM :** Exécute un serveur openssh (`sshd`) et un démon `rsyslogd` local. Il emploie `gio monitor` (glib) pour la surveillance événementielle asynchrone des fichiers sensibles sans blocage de tampon (unbuffered pipeline). Il transmet instantanément tous les flux (`auth`, `authpriv`, `fim_event`, `client_init`) vers le récepteur central via `udp/514`.
