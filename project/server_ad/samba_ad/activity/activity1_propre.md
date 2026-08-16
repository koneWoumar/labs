# TP — Intégration Linux à un Active Directory Samba

## Architecture

| Machine  | IP             | FQDN               | Rôle                                     |
| -------- | -------------- | ------------------ | ---------------------------------------- |
| `smb-ad` | `10.10.93.103` | `smb-ad.lab.local` | Samba Active Directory Domain Controller |
| `client` | `10.10.93.106` | `client.lab.local` | Client Linux membre du domaine           |

### Domaine Active Directory

```text
Realm    : LAB.LOCAL
Domain   : LAB
NetBIOS  : LAB
DNS      : 10.10.93.103
DC       : smb-ad.lab.local
```

### Objectif

À la fin de cette première partie :

* `smb-ad` sera un contrôleur de domaine Active Directory Samba ;
* Samba fournira également le DNS du domaine ;
* trois groupes AD seront créés :

  * `Linux-Users`
  * `Linux-Admins`
  * `Zabbix-Users`
* un utilisateur sera créé dans chacun de ces groupes ;
* `client` sera joint au domaine `LAB.LOCAL` ;
* les utilisateurs AD pourront être reconnus par Linux ;
* les utilisateurs autorisés pourront se connecter en SSH ;
* les membres de `Linux-Admins` pourront recevoir des droits `sudo`.

---

# CHAPITRE 1 — INSTALLATION DU SERVEUR SAMBA AD

Machine concernée :

```text
Hostname : smb-ad
IP       : 10.10.93.103
FQDN     : smb-ad.lab.local
```

---

## 1. Configuration préalable du serveur Samba

Avant d'installer et de provisionner Samba AD, il faut préparer correctement le système.

Cette étape est importante car Active Directory dépend fortement de :

* DNS ;
* hostname ;
* résolution de noms ;
* synchronisation de l'heure ;
* réseau ;
* Kerberos.

---

## 1.1 Vérifier le système

Afficher la distribution :

```bash
cat /etc/os-release
```

Vérifier le noyau :

```bash
uname -a
```

Vérifier l'adresse IP :

```bash
ip addr
```

Vérifier la route :

```bash
ip route
```

Tester la connectivité réseau :

```bash
ping -c 3 10.10.93.1
```

Adapter l'adresse de passerelle si nécessaire.

---

## 1.2 Configurer le hostname

Le serveur doit avoir un nom cohérent avec son futur nom DNS.

Configurer :

```bash
sudo hostnamectl set-hostname smb-ad
```

Vérifier :

```bash
hostname
```

Résultat attendu :

```text
smb-ad
```

Vérifier le nom court :

```bash
hostname -s
```

Résultat :

```text
smb-ad
```

Vérifier le FQDN :

```bash
hostname -f
```

Avant que le DNS Samba soit installé, le FQDN doit déjà pouvoir être résolu localement.

---

## 1.3 Configurer `/etc/hosts`

Éditer :

```bash
sudo nano /etc/hosts
```

Mettre au minimum :

```text
127.0.0.1       localhost
10.10.93.103    smb-ad.lab.local smb-ad
```

Ne pas utiliser l'adresse IP flottante OpenStack pour le nom du DC.

Le nom Active Directory doit correspondre à l'adresse privée du serveur.

Vérifier :

```bash
getent hosts smb-ad
```

Puis :

```bash
getent hosts smb-ad.lab.local
```

Résultat attendu :

```text
10.10.93.103 smb-ad.lab.local smb-ad
```

---

## 1.4 Configurer l'adresse IP

--> Si la configuration reseau est déjà exacte, alors il faut sauter cette partie. 

Vérifier que `10.10.93.103` est bien configurée :

```bash
ip addr show
```

Résultat attendu :

```text
inet 10.10.93.103/24
```

La configuration exacte de l'interface dépend du système utilisé.

Sur Ubuntu avec Netplan, par exemple :

```bash
sudo nano /etc/netplan/01-netcfg.yaml
```

Exemple :

```yaml
network:
  version: 2
  ethernets:
    ens3:
      addresses:
        - 10.10.93.103/24
      routes:
        - to: default
          via: 10.10.93.1
```

Puis :

```bash
sudo netplan apply
```

Vérifier :

```bash
ip addr
ip route
```

Adapter le nom de l'interface et la passerelle à l'environnement OpenStack.

---

## 1.5 Vérifier la résolution DNS avant Samba

Avant l'installation de Samba AD, il ne faut pas encore configurer le serveur pour utiliser son futur DNS Samba sur le port 53.

Vérifier la configuration actuelle :

```bash
cat /etc/resolv.conf
```

Tester un DNS externe :

```bash
host google.com
```

ou :

```bash
getent hosts google.com
```

Le serveur doit avoir temporairement accès à un DNS fonctionnel permettant de résoudre les noms Internet nécessaires à l'installation.

Après le provisionnement Samba, le DNS Samba deviendra le DNS principal du domaine.

---

## 1.6 Vérifier la synchronisation de l'heure

--> Mes serveurs sont dans la même infra et dans la meme zone, donc on saute cette partie. Cette partie reste indispensable si les machines n'ont pas la même heure.


Kerberos est très sensible au décalage horaire.

Vérifier :

```bash
timedatectl
```

Vérifier :

```bash
date
```

Installer NTP/Chrony si nécessaire.

Par exemple :

```bash
sudo apt update
sudo apt install chrony
```

Vérifier :

```bash
systemctl status chrony
```

Puis :

```bash
chronyc tracking
```

L'heure doit être correcte avant de commencer la configuration Kerberos.

---

## 1.7 Désactiver les anciens services Samba

Si Samba a déjà été installé sur la machine, vérifier les services :

```bash
systemctl list-unit-files | grep -E 'samba|smb|nmb|winbind'
```

Arrêter les services éventuellement présents :

```bash
sudo systemctl stop smbd
sudo systemctl stop nmbd
sudo systemctl stop winbind
```

Les désactiver :

```bash
sudo systemctl disable smbd
sudo systemctl disable nmbd
sudo systemctl disable winbind
```

Pour un contrôleur de domaine Samba AD, on utilisera :

```text
samba-ad-dc.service
```

et non une architecture classique `smbd + nmbd`.

---

## 1.8 Vérifier les ports avant installation

Vérifier que les ports nécessaires ne sont pas déjà utilisés :

```bash
sudo ss -lntup
```

En particulier :

```bash
sudo ss -lntup | grep -E ':(53|88|135|139|389|445|464|636|3268|3269)\b'
```

Si un autre serveur DNS utilise déjà le port 53, il faudra le résoudre avant de lancer le provisionnement.

---

Il y'a systemd-resolve qui utilise un serveur dns par defaut et qui ecoute sur le port 53. Voici le schema de fonctionnnement par defaut du systemd-resolve qui est le deamon dns par defaut sur linux :


[Votre Application] 
       │
       ▼ (Consulte /etc/resolv.conf qui pointe vers 'stub-resolv.conf')
[IP 127.0.0.53] ──► Intercepté par le démon [systemd-resolved]
                                                   │
                   (Si pas en cache, regarde) ─────┘
                               │
                               ▼ (Consulte le fichier 'resolv.conf')
                     [Les Vrais DNS Externes] ──► Internet


Dans ce schema, il y'a deux fichiers importants:

📁 resolv.conf (Le fichier des "Vrais" DNS)Ce qu'il contient : Les adresses IP des serveurs DNS externes (ex: 192.168.1.1 fourni par votre box, ou 8.8.8.8).Comment systemd-resolved l'utilise : C'est sa propre liste de serveurs cibles. Quand systemd-resolved doit résoudre un nom (comme google.com), il lit ce fichier pour savoir à qui poser la question sur Internet.Pour qui est-il là ? Il est mis à disposition des applications locales qui refusent d'utiliser le cache système (le mini dns stub listener) et qui veulent parler directement aux vrais DNS, sans intermédiaire.

📁 stub-resolv.conf (Le fichier "Intermédiaire")Ce qu'il contient : Uniquement la ligne nameserver 127.0.0.53.Comment systemd-resolved l'utilise : Il ouvre un mini-serveur DNS (un stub listener) sur votre propre machine à l'adresse 127.0.0.53:53.Pour qui est-il là ? C'est la configuration par défaut d'Ubuntu. En faisant pointer le système vers ce fichier, toutes les applications envoient leurs requêtes à 127.0.0.53 (au stub listener). systemd-resolved intercepte la demande, regarde dans son cache si l'adresse est connue, et si elle ne l'est pas, il va consulter les "vrais" DNS listés dans l'autre fichier.

---

Ce qu'il faudrait faire, si ce port est occuper par le stub listener :

- Desactiver le mini dns de systemd-resolve pour qu'il liber le port 53

```bash
sudo nano /etc/systemd/resolved.conf
#DNSStubListener=no  <-- decommenter cette ligne

sudo systemctl restart systemd-resolved
```

- Renommer le fichier par defaut (/etc/resolv) qui point sur la config du stub dns.

```bash
cd /etc/
mv resolved.conf resolved.conf.saved_stub_dns_conf
```

- Recréer le fichier à nouveau dans lequel on dira de consulter directement le vrai dns, plus tard, on lui dira de designer le dns de samba

```bash
sudo cp /run/systemd/resolve/resolv.conf /etc/resolv.conf
# le contenu à modifier plutard.
```

## 1.9 Vérifier le firewall

Si un firewall est actif :

```bash
sudo ufw status
```

Pour un environnement de TP, on peut temporairement désactiver UFW :

```bash
sudo ufw disable
```

Ou, de manière préférable, autoriser uniquement les ports nécessaires.

---

# 2. Installation de Samba AD

## 2.1 Mettre à jour le système

```bash
sudo apt update
sudo apt upgrade
```

---

## 2.2 Installer Samba

Installer les paquets nécessaires :

```bash
sudo apt install -y samba smbclient krb5-user krb5-config winbind libpam-winbind libnss-winbind acl attr dnsutils



## Answer to question :

#Default realm:
#    LAB.LOCAL

#Kerberos server:
#    smb-ad.lab.local

#Administrative server:
#    smb-ad.lab.local

```



Vérifier la version :

```bash
samba --version
```

Vérifier les outils :

```bash
samba-tool --version
```

---

## 2.3 Sauvegarder la configuration Samba existante

Avant le provisionnement :

```bash
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.backup
```

---

## 2.4 Provisionner le domaine Active Directory

Lancer :

```bash
sudo samba-tool domain provision --use-rfc2307 --interactive
```

Répondre par exemple :

```text
Realm: LAB.LOCAL
Domain: LAB
Server Role: dc
DNS backend: SAMBA_INTERNAL
DNS forwarder: 1.1.1.1
```

Le mot de passe de l'administrateur doit respecter les exigences de complexité de Samba.

---

## 2.5 Vérifier le fichier `smb.conf`

Afficher :

```bash
sudo cat /etc/samba/smb.conf
```

Le fichier doit contenir au minimum des paramètres correspondant à :

```ini
[global]
    workgroup = LAB
    realm = LAB.LOCAL
    netbios name = SMB-AD
    server role = active directory domain controller
    dns forwarder = 1.1.1.1
    idmap_ldb:use rfc2307 = yes

[sysvol]
    path = /var/lib/samba/sysvol
    read only = No

[netlogon]
    path = /var/lib/samba/sysvol/lab.local/scripts
    read only = No
```

Ne pas ajouter inutilement de configuration Winbind destinée à un serveur membre.

Le contrôleur de domaine Samba possède déjà les composants nécessaires à son fonctionnement AD.

---

## 2.6 Vérifier la configuration Samba

```bash
sudo testparm
```

Résultat attendu :

```text
Loaded services file OK.
Server role: ROLE_ACTIVE_DIRECTORY_DC
```

---


## 2.8 Démarrer Samba AD

```bash

sudo systemctl stop smbd nmbd winbind

sudo systemctl unmask samba-ad-dc
sudo systemctl enable samba-ad-dc
sudo systemctl start samba-ad-dc
```

Vérifier :

```bash
systemctl status samba-ad-dc --no-pager
```

Le service doit être :

```text
Active: active (running)
```

---

## 2.7 Configurer Kerberos

Le provisionnement Samba génère normalement une configuration Kerberos adaptée.

Vérifier :

```bash
ls -l /etc/krb5.conf
```

Afficher :

```bash
cat /etc/krb5.conf
```

Tester Kerberos :

```bash
kinit Administrator@LAB.LOCAL
```

Afficher le ticket :

```bash
klist
```

On doit obtenir un ticket de type :

```text
krbtgt/LAB.LOCAL@LAB.LOCAL
```

Détruire le ticket :

```bash
kdestroy
```

---

# 3. Vérification de Samba AD


## 3.1 Vérifier les ports Samba

```bash
sudo ss -lntup
```

Vérifier notamment le DNS :

```bash
sudo ss -lntup | grep ':53'
```

Le processus Samba doit écouter sur le port 53.

---

## 3.3 Vérifier le DNS Samba

Lister les zones :

```bash
sudo samba-tool dns zonelist 127.0.0.1 -U Administrator
```

On doit retrouver notamment :

```text
lab.local
_msdcs.lab.local
```

---

## 3.4 Tester la résolution du serveur

```bash
host smb-ad.lab.local 127.0.0.1
```

Résultat attendu :

```text
smb-ad.lab.local has address 10.10.93.103
```

Tester également :

```bash
host -t A smb-ad.lab.local 127.0.0.1
```

---

## 3.5 Tester les enregistrements SRV

Tester LDAP :

```bash
host -t SRV _ldap._tcp.lab.local 127.0.0.1
```

Tester Kerberos :

```bash
host -t SRV _kerberos._udp.lab.local 127.0.0.1
```

Tester Kerberos TCP :

```bash
host -t SRV _kerberos._tcp.lab.local 127.0.0.1
```

Les résultats doivent pointer vers :

```text
smb-ad.lab.local
```

---

## 3.6 Tester la résolution DNS depuis le client

Depuis `client` :

```bash
host smb-ad.lab.local 10.10.93.103
```

Puis :

```bash
host -t SRV _ldap._tcp.lab.local 10.10.93.103
```

Puis :

```bash
host -t SRV _kerberos._udp.lab.local 10.10.93.103
```

Ces tests doivent fonctionner avant de continuer avec la jonction au domaine.

---

## 3.7 Vérifier l'état du domaine

Depuis `smb-ad` :

```bash
sudo samba-tool domain level show
```

Vérifier les contrôleurs :

```bash
sudo samba-tool drs showrepl
```

Dans un environnement avec un seul DC, l'absence de partenaire de réplication est normale.

---

## 3.8 Vérifier les utilisateurs

Lister les utilisateurs :

```bash
sudo samba-tool user list
```

On doit notamment retrouver :

```text
Administrator
Guest
krbtgt
```

---

# 4. Création des groupes et utilisateurs

Nous allons créer trois groupes :

```text
Linux-Users
Linux-Admins
Zabbix-Users
```

---

## 4.1 Créer les groupes

```bash
sudo samba-tool group add Linux-Users
```

```bash
sudo samba-tool group add Linux-Admins
```

```bash
sudo samba-tool group add Zabbix-Users
```

Vérifier :

```bash
sudo samba-tool group list
```

---

## 4.2 Créer les utilisateurs

Créer un utilisateur pour `Linux-Users` :

```bash
sudo samba-tool user create userkone
```

Créer un utilisateur pour `Linux-Admins` :

```bash
sudo samba-tool user create admkone
```

Créer un utilisateur pour `Zabbix-Users` :

```bash
sudo samba-tool user create zabkone
```

---

## 4.3 Ajouter les utilisateurs aux groupes

```bash
sudo samba-tool group addmembers Linux-Users userkone
```

```bash
sudo samba-tool group addmembers Linux-Admins admkone
```

```bash
sudo samba-tool group addmembers Zabbix-Users zabkone
```

---

## 4.4 Vérifier les membres des groupes

```bash
sudo samba-tool group listmembers Linux-Users
```

Résultat :

```text
userkone
```

Puis :

```bash
sudo samba-tool group listmembers Linux-Admins
```

Résultat :

```text
admkone
```

Puis :

```bash
sudo samba-tool group listmembers Zabbix-Users
```

Résultat :

```text
zabkone
```

---

## 4.5 Vérifier les utilisateurs

```bash
sudo samba-tool user show userkone
```

```bash
sudo samba-tool user show admkone
```

```bash
sudo samba-tool user show zabkone
```

---

## 4.6 Tester Kerberos avec un utilisateur

Depuis `smb-ad` :

```bash
kinit userkone@LAB.LOCAL
```

Puis :

```bash
klist
```

Détruire le ticket :

```bash
kdestroy
```

Faire également le test avec :

```bash
kinit admkone@LAB.LOCAL
```

---


## 4.7 Configuration optionnelle

On peut indiquer le dns de samba comme serveur dns à utiliser par les application du systeme du serveur linux en l'indiquant dans le fichier /etc/resolv. Cela n'est pas absoluement necessaire mais l'es pour le serveur client qui sera join au domaine du servuer ad.


Pour le faire, il faut modifier le fichier /etc/resolv

```bash
vim /etc/resolv.conf
#nameserver 10.10.93.103
#search lab.local
```



# CHAPITRE 2 — CONFIGURATION DU CLIENT LINUX

Machine concernée :

```text
Hostname : client
IP       : 10.10.93.106
FQDN     : client.lab.local
```

Objectif :

```text
client
   │
   ├── DNS → smb-ad
   │
   ├── Kerberos → smb-ad
   │
   ├── Winbind → Samba AD
   │
   ├── NSS → utilisateurs/groupes AD
   │
   ├── PAM → authentification
   │
   └── SSH → accès utilisateurs AD
```

---

# 5. Configuration préalable du client

## 5.1 Vérifier le réseau

```bash
ip addr
```

Vérifier la route :

```bash
ip route
```

Tester le serveur AD :

```bash
ping -c 3 10.10.93.103
```

---

## 5.2 Configurer le hostname

```bash
sudo hostnamectl set-hostname client
```

Vérifier :

```bash
hostname
```

Résultat :

```text
client
```

---

## 5.3 Configurer `/etc/hosts`

Éditer :

```bash
sudo nano /etc/hosts
```

Mettre :

```text
127.0.0.1       localhost
10.10.93.106    client.lab.local client
10.10.93.103    smb-ad.lab.local smb-ad
```

Tester :

```bash
getent hosts smb-ad.lab.local
```

Résultat attendu :

```text
10.10.93.103 smb-ad.lab.local smb-ad
```

Tester :

```bash
getent hosts client.lab.local
```

---

# 6. Configuration DNS du client

Cette étape est essentielle.

Le DNS principal du client doit être le DNS Samba :

```text
10.10.93.103
```

Vérifier :

```bash
cat /etc/resolv.conf
```

Le résultat doit permettre d'utiliser :

```text
nameserver 10.10.93.103
```

Si `systemd-resolved` est utilisé, vérifier :

```bash
resolvectl status
```

Configurer le DNS via le gestionnaire réseau utilisé par la distribution.

---

Il faut configuer le dns du client pour qu'il utilise le dns de samba comme suite :


- Desactiver le mini dns de systemd-resolve pour qu'il liber le port 53

```bash
sudo nano /etc/systemd/resolved.conf
#DNSStubListener=no  <-- decommenter cette ligne

sudo systemctl restart systemd-resolved
```

- Renommer le fichier par defaut (/etc/resolv) qui point sur la config du stub dns.

```bash
cd /etc/
mv resolved.conf resolved.conf.saved_stub_dns_conf
```

- Recréer le fichier à nouveau dans lequel on dira de consulter le dns de samba

```bash
sudo cp /run/systemd/resolve/resolv.conf /etc/resolv.conf
# mettre à jour le contenu comme suite :

#nameserver 10.10.93.103
#search lab.local
```

- Ouvrir les ports necessaire pour la communication avec le serveur

```bash
sudo ufw allow 53/tcp && sudo ufw allow 53/udp
sudo ufw allow 88/tcp && sudo ufw allow 88/udp
sudo ufw allow 389/tcp && sudo ufw allow 389/udp
sudo ufw allow 445/tcp
sudo ufw allow 464/tcp && sudo ufw allow 464/udp
sudo ufw allow 636/tcp
sudo ufw allow 1024:5000/tcp
sudo ufw reload
```


## 6.1 Tester le DNS

```bash
host smb-ad.lab.local
```

Puis :

```bash
host lab.local
```

Puis :

```bash
host -t SRV _ldap._tcp.lab.local
```

Puis :

```bash
host -t SRV _kerberos._udp.lab.local
```

Tous ces tests doivent fonctionner.

---

# 7. Synchronisation de l'heure du client

Vérifier :

```bash
timedatectl
```

Installer Chrony si nécessaire :

```bash
sudo apt install chrony
```

Vérifier :

```bash
chronyc tracking
```

Le client et le DC doivent avoir une heure suffisamment synchronisée pour Kerberos.

---

# 8. Installer les composants d'intégration AD

Installer :

```bash
sudo apt update
```

Puis :

```bash
sudo apt install \
    samba \
    winbind \
    libnss-winbind \
    libpam-winbind \
    krb5-user \
    smbclient
```

Vérifier Winbind :

```bash
winbindd --version
```

Vérifier Kerberos :

```bash
klist --version
```

---

# 9. Configurer Kerberos sur le client

Éditer :

```bash
sudo nano /etc/krb5.conf
```

Configuration minimale :

```ini
[libdefaults]
    default_realm = LAB.LOCAL
    dns_lookup_realm = false
    dns_lookup_kdc = true


## config que j'ai pris :

[libdefaults]
    default_realm = LAB.LOCAL
    dns_lookup_realm = false
    dns_lookup_kdc = true
    rdns = false

[realms]
    LAB.LOCAL = {
        kdc = smb-ad.lab.local
        admin_server = smb-ad.lab.local
    }

[domain_realm]
    .lab.local = LAB.LOCAL
    lab.local = LAB.LOCAL

```

Tester :

```bash
kinit Administrator@LAB.LOCAL
```

Puis :

```bash
klist
```

Si le ticket est obtenu, Kerberos fonctionne.

Détruire le ticket :

```bash
kdestroy
```

---

# 10. Configurer Samba/Winbind sur le client

Sauvegarder l'ancien fichier :

```bash
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
```

Éditer :

```bash
sudo nano /etc/samba/smb.conf
```

Configuration :

```ini
[global]
    workgroup = LAB
    realm = LAB.LOCAL
    security = ADS

    winbind use default domain = yes
    winbind enum users = yes
    winbind enum groups = yes

    idmap config * : backend = tdb
    idmap config * : range = 3000-7999

    idmap config LAB : backend = rid
    idmap config LAB : range = 10000-999999

    template shell = /bin/bash
    template homedir = /home/%U
```

Vérifier :

```bash
sudo testparm
```

---

# 11. Joindre le client au domaine

Avant la jonction, vérifier :

```bash
host -t SRV _ldap._tcp.lab.local
```

Puis :

```bash
host -t SRV _kerberos._udp.lab.local
```

Tester Kerberos :

```bash
kinit Administrator@LAB.LOCAL
```

Puis :

```bash
klist
```

Ensuite joindre le domaine :

```bash
sudo net ads join -U Administrator
```

Entrer le mot de passe Administrator.

Résultat attendu :

```text
Joined 'CLIENT' to dns domain 'lab.local'
```

Détruire ensuite le ticket Kerberos :

```bash
kdestroy
```

---

# 12. Vérifier la jonction au domaine

```bash
sudo net ads testjoin
```

Résultat attendu :

```text
Join is OK
```

Vérifier les informations du domaine :

```bash
net ads info
```

On doit retrouver notamment :

```text
Realm: LAB.LOCAL
LDAP server: smb-ad.lab.local
LDAP server name: smb-ad.lab.local
```

---

# 13. Démarrer Winbind

Activer le service :

```bash
sudo systemctl enable winbind
```

Démarrer :

```bash
sudo systemctl start winbind
```

Vérifier :

```bash
systemctl status winbind --no-pager
```

---

# 14. Tester la relation de confiance

```bash
sudo wbinfo -t
```

Résultat attendu :

```text
checking the trust secret for domain LAB via RPC calls succeeded
```

C'est un test essentiel.

---

# 15. Tester les utilisateurs AD avec Winbind

Lister les utilisateurs :

```bash
wbinfo -u
```

On doit retrouver :

```text
LAB\userkone
LAB\admkone
LAB\zabkone
```

Lister les groupes :

```bash
wbinfo -g
```

On doit retrouver :

```text
LAB\Linux-Users
LAB\Linux-Admins
LAB\Zabbix-Users
```

---

# 16. Tester les groupes d'un utilisateur

```bash
wbinfo -r "LAB\userkone"
```

Puis :

```bash
wbinfo -r "LAB\admkone"
```

Vérifier que `admkone` possède le groupe `Linux-Admins`.

---

# 17. Configurer NSS

Modifier :

```bash
sudo nano /etc/nsswitch.conf
```

Configurer :

```text
passwd:         compat winbind
group:          compat winbind
```

Si `systemd` ou d'autres modules sont déjà présents, ne pas supprimer aveuglément les mécanismes nécessaires au système ; l'objectif est que `winbind` apparaisse dans les bases `passwd` et `group`.

---

# 18. Tester NSS

Tester :

```bash
getent passwd userkone
```

Puis :

```bash
getent passwd admkone
```

Puis :

```bash
getent passwd zabkone
```

Tester les groupes :

```bash
getent group Linux-Users
```

```bash
getent group Linux-Admins
```

```bash
getent group Zabbix-Users
```

Enfin :

```bash
id userkone
```

```bash
id admkone
```

```bash
id zabkone
```

Le système Linux doit maintenant être capable de résoudre les identités provenant de l'Active Directory.

---

# 19. Configurer PAM

Vérifier que le module Winbind PAM est installé :

```bash
dpkg -l | grep libpam-winbind
```

Sur Debian/Ubuntu, lancer :

```bash
sudo pam-auth-update
```

Activer l'intégration Winbind si elle est proposée.

Vérifier ensuite :

```bash
grep -R winbind /etc/pam.d/
```

---

# 20. Créer automatiquement les home directories

Pour permettre aux utilisateurs AD de disposer d'un répertoire personnel lors de leur première connexion :

```bash
sudo pam-auth-update
```

Activer :

```text
Create home directory on login
```

Selon la distribution, le module concerné peut être :

```text
pam_mkhomedir.so
```

Vérifier :

```bash
grep -R mkhomedir /etc/pam.d/
```

---

# 21. Configurer SSH

Éditer :

```bash
sudo nano /etc/ssh/sshd_config
```

Activer :

```text
UsePAM yes
PasswordAuthentication yes
```

---

# 22. Tester les connexions SSH

Depuis une autre machine :

```bash
ssh LAB\\admkone@client.lab.local
ssh LAB\\userkone@client.lab.local
```

Les deux connexions doivent être autorisées.


---

# 23. Configuration de la securité et restriction 

## 1. Restriction SSH

On permettre uniquement à un ensemble de groupe d'utilisateur de pouvoir se connecter .

Pour le moment, autoriser les deux groupes Linux et l'utilisateur local ubuntu (via son group perosonel):

```text
AllowGroups linux-users linux-admins ubuntu
```

Ainsi :

```text
admkone → Linux-Users → SSH autorisé
userkone   → Linux-Admins → SSH autorisé
zabkone → Zabbix-Users → SSH refusé
```

Vérifier la configuration SSH :

```bash
sudo sshd -t
```

Si aucune erreur n'est affichée :

```bash
sudo systemctl restart ssh
```

Tester l'accès avec les users authorisés :

```bash
ssh LAB\\admkone@client.lab.local
ssh LAB\\userkone@client.lab.local
```
Les deux connexions doivent être autorisées. La precisiond du domaine n'est pas obligatoire.


Tester l'accès avec les users non authorisés :

```bash
ssh LAB\\zabkone@client.lab.local
```

La connexion doit être refusée.




## 2. Donner sudo au groupe Linux-Admins

Créer :

```bash
sudo nano /etc/sudoers.d/linux-admins
```

Ajouter :

```text
%Linux-Admins ALL=(ALL:ALL) ALL
```

Vérifier :

```bash
sudo visudo -c
```

Résultat attendu :

```text
/etc/sudoers: parsed OK
/etc/sudoers.d/linux-admins: parsed OK
```

---

## 3. Tester les droits sudo

Se connecter avec `admkone` :

```bash
ssh admkone@10.10.93.106
```

Puis :

```bash
sudo whoami
```

Résultat :

```text
root
```

Tester avec `userkone` :

```bash
ssh userkone@10.10.93.106
```

Puis :

```bash
sudo whoami
```

L'utilisateur ne doit pas disposer des droits administrateur.

---

# 25. Validation finale

## 25.1 Tests côté Samba AD

Sur `smb-ad` :

```bash
systemctl is-active samba-ad-dc
```

```bash
sudo testparm -s
```

```bash
sudo samba-tool dns zonelist 127.0.0.1 -U Administrator
```

```bash
host -t SRV _ldap._tcp.lab.local
```

```bash
host -t SRV _kerberos._udp.lab.local
```

```bash
sudo samba-tool group listmembers Linux-Users
```

```bash
sudo samba-tool group listmembers Linux-Admins
```

```bash
sudo samba-tool group listmembers Zabbix-Users
```

---

## 25.2 Tests côté client

Sur `client` :

### DNS

```bash
host smb-ad.lab.local
```

### Kerberos

```bash
kinit userkone@LAB.LOCAL
klist
kdestroy
```

### Jonction

```bash
net ads testjoin
```

### Winbind

```bash
wbinfo -t
```

```bash
wbinfo -u
```

```bash
wbinfo -g
```

### NSS

```bash
getent passwd userkone
```

```bash
getent group Linux-Users
```

### Identité

```bash
id userkone
```

```bash
id admkone
```

```bash
id zabkone
```

### PAM/SSH

Tester :

```bash
ssh userkone@client
```

```bash
ssh admkone@client
```

```bash
ssh zabkone@client
```

### Sudo

Avec `admkone` :

```bash
sudo whoami
```

Résultat :

```text
root
```

---

# 26. Schéma fonctionnel final

À ce stade, le fonctionnement est :

```text
                         SAMBA AD
                     10.10.93.103
                           │
            ┌──────────────┼──────────────┐
            │              │              │
           DNS         Kerberos         LDAP
            │              │              │
            └──────────────┼──────────────┘
                           │
                           │
                    réseau 10.10.93.0/24
                           │
                           ▼
                    CLIENT
                10.10.93.106
                           │
                           ▼
                        SSHD
                           │
                           ▼
                         PAM
                           │
                           ▼
                       Winbind
                           │
                           ├──── NSS
                           │
                           ▼
                       Samba AD
                           │
              ┌────────────┼─────────────┐
              │            │             │
           userkone          admkone         zabkone
              │            │             │
        Linux-Users   Linux-Admins   Zabbix-Users
              │            │
           SSH OK       SSH OK
                           │
                        sudo OK
```

---

# 27. Résultat attendu

| Utilisateur | Groupe AD      | Connexion SSH | `sudo` |
| ----------- | -------------- | ------------: | -----: |
| `userkone`     | `Linux-Users`  |           Oui |    Non |
| `admkone`       | `Linux-Admins` |           Oui |    Oui |
| `zabkone`   | `Zabbix-Users` |           Non |    Non |

Cette configuration constituera la base pour la suite du TP, où `Zabbix-Users` pourra être utilisé sur une troisième machine hébergeant une application.

---

# 28. Architecture des prochaines étapes

Une fois les deux premières machines fonctionnelles, la suite pourra être ajoutée sans modifier cette architecture :

```text
                     ┌───────────────────┐
                     │      smb-ad       │
                     │                   │
                     │ Samba AD          │
                     │ DNS               │
                     │ Kerberos          │
                     │ LDAP              │
                     └─────────┬─────────┘
                               │
                ┌──────────────┴──────────────┐
                │                             │
        ┌───────▼────────┐            ┌───────▼────────┐
        │     client     │            │    server02    │
        │                │            │                │
        │ Linux          │            │ Application    │
        │ Winbind        │            │ Zabbix         │
        │ PAM            │            │                │
        │ SSH            │            │ AD users       │
        └────────────────┘            └────────────────┘
```







# CHAPITRE 3 — CONNEXION DU LDAP AVEC UNE APPLI : ZABBIX

Machine concernée :

```text
Hostname : server
IP       : 10.10.93.106
FQDN     : server.lab.local
```

Objectif :

```text
server
   │
   ├── DNS → smb-ad
   │
   ├── Certificat → reconait celui du smb-ad
   │
   └── ldaps → accès utilisateurs AD
```

---

# 1. Preparation de l'ad pour la liaison avec l'AD

## 1.1 Création d'un utilisateur de service


Création de l'utilisateur :

```bash
sudo samba-tool user create zabserve
```

Verification :

```bash
sudo samba-tool user list
```


## 1.2 Creation d'une Oranisation Unit (OU)

Creation du OU=App :

```bash
#sudo samba-tool ou create "OU=App,DC=lab,DC=local"  --> command no valide avec la version actuel de samba
# Ce qu'il faut faire :

# Installé les binaires necessaires :
sudo apt update
sudo apt install ldb-tools

# Creer le OU 
sudo ldbadd -H /var/lib/samba/private/sam.ldb <<'EOF'
dn: OU=App,DC=lab,DC=local
objectClass: top
objectClass: organizationalUnit
ou: App
EOF
```

Verification, affichage de l'ensemble des OU : 

```bash
sudo ldbsearch -H /var/lib/samba/private/sam.ldb \
  -b "OU=App,DC=lab,DC=local" \
  -s base \
  "(objectClass=*)" OU
```


## 1.3 Deplacement du user zabknoe dans cette OU


On recupere deja le DN de l'utilisateur:

```bash
sudo ldbsearch -H /var/lib/samba/private/sam.ldb \
  -b "DC=lab,DC=local" \
  "(sAMAccountName=zabkone)" \
  dn
```

Deplacement du user zabkone dans cette OU :

```bash
 sudo ldbrename \
  -H /var/lib/samba/private/sam.ldb \
  "CN=zabkone,CN=Users,DC=lab,DC=local" \
  "CN=zabkone,OU=App,DC=lab,DC=local"
```

Verification par affichange du dn du user zabkone :

```bash
sudo ldbsearch -H /var/lib/samba/private/sam.ldb \
  -b "OU=App,DC=lab,DC=local" \
  "(sAMAccountName=zabkone)" \
  dn
```


Verification par affichange des Objet du OU=App:

```bash
ldapsearch -x -LLL \
  -H ldap://smb-ad.lab.local \
  -D "Administrator@LAB.LOCAL" -W \
  -b "OU=App,DC=lab,DC=local" \
  "(objectClass=*)" dn
```


Afficher uniquement les utilisateurs du OU :

```bash
ldapsearch -x -LLL \
  -H ldap://smb-ad.lab.local \
  -D "Administrator@LAB.LOCAL" -W \
  -b "OU=App,DC=lab,DC=local" \
  "(objectClass=user)" dn sAMAccountName
```




# 2. Configuration préalable du client


## 2.1 Vérifier le hostname

```bash
hostname -s #--> server
```

```bash
hostname #--> server
```

```bash
hostname -f #--> server.lab.local
```

Il faudrait fait en sorte que ces resultats soit OK.


## 2.3 Indiquer le dns de comme dns à utiliser

Nous allons indiquer le dns du serveur smb comme dns externe à utiliser par systemd-resolve. Ainsi si le stub listener envera les requete au dns de smb s'il ne trouve rien dans son cache ou dans son. Notre configuration restera fragile car toute redemarrage de systemd-resolve pourrait ecraser notre config


Savegarder la config par defaut du fichier de la liste des dns de systemd-resolved:

```bash
cd /run/systemd/resolve
cp resolv.conf resolv.conf_saved_default_conf
vim resolv.conf
```
Contenu :

```conf
nameserver 10.10.93.103
search lab.local
```

Tester cette nouvelle config :

```bash
host smb-ad
```

Ce qu'il faudrait faire en cas de redemarrage du serveur, ce qui ecrasera la config :

Savegarder la config par defaut du fichier principal indiquant le dns:

```bash
cd /etc/
cp resolv.conf resolv.conf_saved_default_conf
vim resolv.conf
```
Contenu :

```conf
nameserver 10.10.93.103
search lab.local
```


Tester cette nouvelle config :

```bash
host smb-ad
```


## 3 Ajouter le CA de l'ad samba dans le trustore du systeme


### 3.1 Recuperer le CA du serveur samba :

```bash
su - root
cd 
scp -rp smb-ad:/var/lib/samba/private/tls/ca.pem

```

### 3.2 Verification optionnelles

Verifions la contrainte CA:TRUE qui confirme que c'est une CA et non un certificat standard : 

```bash
openssl x509 -in ca.pem -noout -text | grep -A 1 "Basic Constraints"

```

Verifier que le certificat est autosigné :

```bash
openssl x509 -in ca.pem -noout -subject -issuer
```

Resultats attendus :

```text
subject=CN = Mon_Entreprise_CA, O = Ma_Societe, C = FR
issuer=CN = Mon_Entreprise_CA, O = Ma_Societe, C = FR
```

Extraction des informations importante du CA :

```bash
openssl x509 -in ca.pem -noout -subject -issuer -dates -dates -purpose -fingerprint
```

Afficher l'integrité des informations du CA :

```bash
openssl x509 -in ca.pem -noout -text
```

### 3.3 Ajout du certificat au trustore du system

Commande correspondant au system ubuntu :

```bash
# Ajouter les bon droit si necessaire
sudo chown root:root ca.pem
sudo chmod 644 ca.pem
#
sudo cp ca.pem /usr/local/share/ca-certificates/ca_smb.crt
sudo update-ca-certificates
```

### 3.4 Verification

```bash
sudo apt install p11-kit   # ce paquet n'est pas toujours installé par defaut
trust list > tmp_file
vim tmp_file
#recherche avec le nom du CA
```

## 4. Test d'ouverture de connexion SSL/TLS avec le serveur

Test avec precision du CA file :

```bash
openssl s_client -connect smb-ad.lab.local:636 -CAfile /etc/ssl/certs/ca-certificates.crt
```

Test sans precision du CA file :

```bash
openssl s_client -connect ldap.monclient.fr:636
```



## 5. Test ldap search pour valider l'authentification avec le serveur ldap


### 5.1 Recherche des informatons de l'utilisateur de service avec l'admin


```bash
ldapsearch -x -LLL \
  -H ldaps://smb-ad.lab.local \
  -D "Administrator@LAB.LOCAL" -W \
  -b "DC=lab,DC=local" \
  "(sAMAccountName=admkone)" dn
```

Resultats :

```text
dn: CN=admkone,CN=Users,DC=lab,DC=local
...
objectClass: user
...
cn: admkone
...
sAMAccountName: admkone
...
memberOf: CN=Linux-Admins,CN=Users,DC=lab,DC=local
```


### 5.2 Recherche d'un user applicative avec le compte de service


Test 1 : Le test d'identification anonyme (Le "Ping" LDAP) :

```bash
LDAPTLS_CACERT=ca.pem ldapsearch -H ldaps://smb-ad.lab.local:636 -x -b "" -s base
```


Test 2 : Le test d'authentification et de recherche (Le test réel):


```bash
ldapsearch -H ldaps://smb-ad.lab.local:636 \
  -x \
  -D "CN=Svc-App-Binding,OU=Service Accounts,DC=lab,DC=local" \
  -W \
  -b "DC=lab,DC=local" "(sAMAccountName=zabkone)"
```


- D : Le Bind DN (le compte de service qui a le droit de chercher).
- W : Demande le mot de passe du compte de service de manière sécurisée dans le terminal.
- b : La Base DN, l'endroit de l'annuaire où commence la recherche.
- "(sAMAccountName=...)" : Le filtre de recherche.



## 6. Installation et configuration de Grafana

 Installer grafana :

```bash
## Installer les binaires necessaires
sudo apt update
sudo apt install -y apt-transport-https wget
## Ajouter la clé et le dépôt Grafana :
sudo mkdir -p /etc/apt/keyrings
wget -q -O - https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
## Puis :
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
## Installer grafana
sudo apt update
sudo apt install -y grafana
## Active et démarre le service :
sudo systemctl enable --now grafana-server
sudo systemctl status grafana-server
```
Tester interface :

http://IP_DU_SERVEUR:3000

login par defaut : 

admin/admin

##  7. Connecter grafana au ldap

### 7.1  Recuperation des informations necessaires à la configurations:

- DN de l'utilisateur de service

```bash
sudo ldbsearch -H /var/lib/samba/private/sam.ldb -b "DC=lab,DC=local" "(sAMAccountName=zabserve)" dn
```

- DN du OU dans lequel chercher les utilisateurs

```bash
sudo ldbsearch -H /var/lib/samba/private/sam.ldb -b "DC=lab,DC=local" "(sAMAccountName=zabkone)" dn
```

- Resumer dess infos :

````
DN_of_service_user: CN=zabserve,CN=Users,DC=lab,DC=local
son mot de pass : ****
DN_of_users_group: OU=App,DC=lab,DC=local
hostname du serveur ldap : smb-ad.lab.local
````

### 7.2 Configuration de grafana


Editer le fichier de configuration de grafana:

```bash
sudo nano /etc/grafana/ldap.toml
```

contenu du fichier :

```TOM
# Samba AD / LDAPS
# Lab configuration

[[servers]]

# Samba AD Domain Controller
host = "smb-ad.lab.local"
port = 636

# LDAPS
use_ssl = true
start_tls = false

# Lab uniquement : ne vérifie pas le certificat TLS
ssl_skip_verify = true

# Compte de service utilisé pour rechercher les utilisateurs
bind_dn = "CN=zabserve,CN=Users,DC=lab,DC=local"
bind_password = 'TON_MOT_DE_PASSE'

# Recherche l'utilisateur avec son login AD
search_filter = "(sAMAccountName=%s)"

# Les utilisateurs à authentifier se trouvent dans cette OU
search_base_dns = ["OU=App,DC=lab,DC=local"]

# Attributs Active Directory
[servers.attributes]
name = "givenName"
surname = "sn"
username = "sAMAccountName"
member_of = "memberOf"
email = "mail"

# Pour le premier test, tous les utilisateurs trouvés
# dans LDAP auront le rôle Viewer dans Grafana.
[[servers.group_mappings]]
group_dn = "*"
org_role = "Viewer"
```

Activer le LDAP dans grafana :

```bash
sudo nano /etc/grafana/grafana.ini
```

Verifier :

```INI
[auth.ldap]
enabled = true
config_file = /etc/grafana/ldap.toml
```

Redemarrer le service de grafana :

```bash
sudo systemctl restart grafana-server
```

##  7. Test de connexion avec l'utilisateur de l'AD

TEST EST OK avec Grafana.


# Conclusion : lessons à tirer du tp



## 1. Comprendre les utilisateurs dans les configurations LDAP

Dans l'univers LDAP / Samba AD, vous entendrez souvent parler de deux rôles d'utilisateurs distincts. Il est crucial de ne pas les confondre.

### 1.1 Le "Bind DN" (L'utilisateur de liaison / Compte de Service)


- Qui est-ce ? C'est un compte utilisateur créé dans votre Samba AD (souvent nommé svc-app-auth ou ldap-bind).

- Son rôle : C'est l'identifiant que l'application utilise pour ouvrir la porte du serveur LDAP. Par défaut, l'AD n'autorise pas les recherches anonymes. L'application doit donc d'abord prouver qui elle est avec ce compte pour avoir le droit de lire l'annuaire.

- Son rôle : C'est l'identifiant que l'application utilise pour ouvrir la porte du serveur LDAP. Par défaut, l'AD n'autorise pas les recherches anonymes. L'application doit donc d'abord prouver qui elle est avec ce compte pour avoir le droit de lire l'annuaire.

- Sécurité : Ce compte n'a besoin d'aucun privilège d'administrateur. Un simple utilisateur standard du domaine possède le droit de lire l'annuaire.

### 1.2 L'utilisateur recherché (L'utilisateur final)

- Qui est-ce ? C'est l'utilisateur humain (par exemple, vous ou un collègue) qui essaie de se connecter à l'interface de l'application (ex: Nextcloud, Gitlab, Sonarqube).

- Son rôle : L'utilisateur tape son identifiant (jean.dupont) et son mot de passe sur la page de connexion de l'application.

- Le mécanisme :

1. L'application se connecte à Samba AD avec le Bind DN.
2. L'application cherche le DN complet de jean.dupont grâce au filtre (sAMAccountName=jean.dupont).
3. Une fois trouvé, l'application tente une "deuxième liaison" LDAP, mais cette fois-ci en utilisant le DN de Jean et le mot de passe que Jean a tapé. Si Samba AD dit "Oui", l'utilisateur est connecté.


### 1.3 Synthèse des champs à remplir dans votre Application

Lorsque vous configurerez votre application, voici la correspondance des champs :

- LDAP URL / Host : ldaps://smb-ad.lab.local:636
- Base DN : DC=lab,DC=local (L'application cherchera dans tout le domaine).
- Bind DN (User DN) : CN=Svc-App-Binding,CN=Users,DC=lab,DC=local (Le compte de l'application).
- Password : Le mot de passe de ce compte de service.
- User Login Filter : (sAMAccountName=%s) (Le %s sera remplacé automatiquement par l'identifiant saisi par l'utilisateur humain).


### 4. Comprendre le DN (Distingush Name)

Dans un Active Directory, on trouve différents types d'objets, notamment :

- des utilisateurs ;
- des groupes ;
- des ordinateurs ;
- des comptes de service ;
- des unités d'organisation (OU) ;
etc.

Chaque objet possède un DN (Distinguished Name), qui permet de l'identifier de manière unique dans l'annuaire LDAP.

Le DN peut être vu comme le chemin complet d'un objet dans l'arborescence LDAP.

Par exemple, un utilisateur peut avoir le DN suivant :


```text
CN=admkone,CN=Users,DC=lab,DC=local
```

On peut le décomposer ainsi :

```text
CN=admkone
│
├── CN = Common Name
│   └── nom de l'objet : admkone
│
CN=Users
│
├── conteneur dans lequel se trouve l'utilisateur
│
DC=lab,DC=local
│
└── domaine Active Directory
```



Le DN permet donc de déterminer où se trouve l'objet dans l'arborescence de l'annuaire et de l'identifier de manière unique.

### 4.1. CN, OU et DC

Un DN est constitué de plusieurs composants.

Les plus courants sont :


| Élément | Signification       | Exemple           |
| ------- | ------------------- | ----------------- |
| `CN`    | Common Name         | `CN=admkone`      |
| `OU`    | Organizational Unit | `OU=Linux`        |
| `DC`    | Domain Component    | `DC=lab,DC=local` |


```text
CN=admkone,OU=Linux,OU=Users,DC=lab,DC=local
```

```text
LAB.LOCAL
│
└── OU=Users
    │
    └── OU=Linux
        │
        └── CN=admkone
```


### 4.2. Le conteneur Users

Lorsqu'un utilisateur est créé avec les paramètres par défaut d'Active Directory, il peut être placé dans :


```text
CN=Users,DC=lab,DC=local
```

Il faut cependant faire attention : CN=Users est un conteneur et non une OU.

Une OU est identifiée par OU= :

```text
OU=Users,DC=lab,DC=local
```

alors que le conteneur par défaut est :

```text
CN=Users,DC=lab,DC=local
```
Cette distinction est importante notamment lorsqu'on travaille avec LDAP et les stratégies de gestion des objets.


### 4.3. Organisation des objets dans une entreprise

Dans un environnement de production, on ne laisse généralement pas tous les objets dans les conteneurs par défaut.

Les objets peuvent être organisés dans différentes OU (Organizational Units) afin de structurer l'annuaire et de pouvoir appliquer des politiques différentes à différentes populations.

Par exemple :

```text
DC=entreprise,DC=local
│
├── OU=Users
│   ├── OU=IT
│   ├── OU=Finance
│   ├── OU=RH
│   └── OU=Production
│
├── OU=Groups
│
├── OU=Computers
│   ├── OU=Servers
│   ├── OU=Workstations
│   └── OU=Linux
│
└── OU=Admins
```


On pourrait ainsi avoir :

```text
CN=alice,OU=Finance,OU=Users,DC=entreprise,DC=local
```

et : 

```text
CN=bob,OU=IT,OU=Users,DC=entreprise,DC=local
```

Les utilisateurs sont alors organisés en fonction de leur rôle ou de leur service.


### 4.4. OU et groupes : deux notions différentes


Il est important de ne pas confondre OU et groupe.

Une OU sert principalement à organiser les objets et à définir le périmètre d'application de certaines politiques.

Un groupe sert principalement à regrouper des utilisateurs ou des ordinateurs afin de leur attribuer des droits ou des accès.

Par exemple :

```text
OU=Users
│
├── Alice
├── Bob
└── Charlie

Groupes
│
├── Linux-Users
├── Linux-Admins
└── Zabbix-Users
```

Alice peut par exemple appartenir à :

```text
Linux-Users
Zabbix-Users
```

tandis que Bob peut appartenir à :

```text
Linux-Admins
```

L'OU répond donc plutôt à la question :

Où l'objet est-il organisé dans l'annuaire ?

Alors que le groupe répond plutôt à :

À quelle population ou quels droits cet objet est-il associé ?


