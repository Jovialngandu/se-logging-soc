# SE Logging SOC - Centralisation dynamique de logs avec Rsyslog & Docker

Ce projet fournit une infrastructure légère de centralisation et collecte de logs système (Syslog) à des fins de surveillance SOC et d'analyse de sécurité.

## 🏗️ Architecture du Projet

```text
se-logging-soc/
├── config/
│   ├── client/
│   │   ├── Dockerfile             # Image Alpine avec SSHD & Rsyslog
│   │   ├── entrypoint.sh          # Substitution d'IP d'ingestion au boot
│   │   └── rsyslog-client.conf    # Transfert Syslog vers le serveur central
│   └── rsyslog/
│       └── rsyslog.conf           # Receptacle central UDP/TCP + Templates
├── logs/                          # Volume hôte des logs centralisés
└── docker-compose.yml
```

## 🚀 Déploiement & Modes d'exécution

### Mode 1 : Environnement de test local (1 seul PC)

Tous les services démarrent sur la même machine hôte au sein d'un sous-réseau Docker isolé.

```bash
# 1. Donner les autorisations d'écriture au dossier de logs
chmod -R 777 ./logs

# 2. Lancer les conteneurs
docker compose up -d --build

# 3. Tester la génération de logs SSH
ssh root@localhost -p 2222

# 4. Consulter les logs centralisés
cat logs/172.18.0.*/sshd-session.log
```

### Mode 2 : Déploiement distribué / Multi-équipements (2 PC en LAN)

Ce mode simule un serveur SOC central collectant les événements de sécurité provenant d'un équipement distant sur un réseau local (LAN).

#### Step 1 : Sur le PC Serveur (Rsyslog Central)

Récupérer l'adresse IP du PC Serveur (ex: 192.168.1.50).

Lancer le service central :

```bash
chmod -R 777 ./logs
docker compose up -d rsyslog-central
```

#### Step 2 : Sur le PC Client (Alpine Source)

Injecter l'adresse IP du PC Serveur au démarrage :

```bash
SYSLOG_SERVER_IP=192.168.1.50 docker compose up -d --build client-alpine
```

#### Step 3 : Test de démonstration

Tenter une connexion SSH vers le client Alpine :

```bash
ssh root@<IP_DU_PC_CLIENT> -p 2222
```

Vérifier la réception en temps réel sur le PC Serveur :

```bash
ls -la logs/
tail -f logs/<IP_DU_PC_CLIENT>/sshd-session.log
```

## 🔒 Détails des Composants

**Serveur Rsyslog Central :** Écoute sur les ports 514 UDP/TCP. Utilise un filtre dynamique `omfile` qui catégorise automatiquement les logs par dossier d'adresse IP (`/var/log/remote/%FROMHOST-IP%/%PROGRAMNAME%.log`).

**Client Alpine :** Exécute un serveur OpenSSH et transmet immédiatement tous les flux d'authentification (`auth`, `authpriv`) vers le récepteur central via le protocole UDP Syslog.

