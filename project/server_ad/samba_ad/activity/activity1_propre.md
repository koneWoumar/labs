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
alice
```

Puis :

```bash
sudo samba-tool group listmembers Linux-Admins
```

Résultat :

```text
bob
```

Puis :

```bash
sudo samba-tool group listmembers Zabbix-Users
```

Résultat :

```text
charlie
```

---

## 4.5 Vérifier les utilisateurs

```bash
sudo samba-tool user show alice
```

```bash
sudo samba-tool user show bob
```

```bash
sudo samba-tool user show charlie
```

---

## 4.6 Tester Kerberos avec un utilisateur

Depuis `smb-ad` :

```bash
kinit alice@LAB.LOCAL
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
kinit bob@LAB.LOCAL
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
LAB\alice
LAB\bob
LAB\charlie
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
wbinfo -r "LAB\alice"
```

Puis :

```bash
wbinfo -r "LAB\bob"
```

Vérifier que `bob` possède le groupe `Linux-Admins`.

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
getent passwd alice
```

Puis :

```bash
getent passwd bob
```

Puis :

```bash
getent passwd charlie
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
id alice
```

```bash
id bob
```

```bash
id charlie
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

Se connecter avec `bob` :

```bash
ssh bob@10.10.93.106
```

Puis :

```bash
sudo whoami
```

Résultat :

```text
root
```

Tester avec `alice` :

```bash
ssh alice@10.10.93.106
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
kinit alice@LAB.LOCAL
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
getent passwd alice
```

```bash
getent group Linux-Users
```

### Identité

```bash
id alice
```

```bash
id bob
```

```bash
id charlie
```

### PAM/SSH

Tester :

```bash
ssh alice@client
```

```bash
ssh bob@client
```

```bash
ssh charlie@client
```

### Sudo

Avec `bob` :

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
           alice          bob         charlie
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
| `alice`     | `Linux-Users`  |           Oui |    Non |
| `bob`       | `Linux-Admins` |           Oui |    Oui |
| `charlie`   | `Zabbix-Users` |           Non |    Non |

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
