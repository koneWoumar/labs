# Petit cours : DNS sous Linux

## 1. Architecture fonctionnelle

Le DNS sous Linux n'est pas géré par un seul fichier. Plusieurs couches interviennent entre l'application qui demande une résolution et le serveur DNS qui fournit la réponse.

### Schéma 1 — Vue générale

```text
APPLICATION
    │
    ▼
getaddrinfo()
    │
    ▼
/etc/nsswitch.conf
    │
    ├── files
    │      │
    │      ▼
    │   /etc/hosts
    │
    └── dns / resolve / ...
             │
             ▼
        Résolveur local
             │
             ├── systemd-resolved
             ├── dnsmasq
             ├── autre
             │
             ▼
        /etc/resolv.conf
             │
             ▼
        Serveur DNS
             │
             ▼
       DNS récursif
             │
             ▼
     DNS autoritatif
```

> **À retenir :** `/etc/hosts`, `/etc/nsswitch.conf` et `/etc/resolv.conf` n'ont pas le même rôle. `nsswitch.conf` détermine notamment **où chercher**, `hosts` fournit des correspondances locales et `resolv.conf` indique généralement **quel résolveur DNS utiliser**.

---

## 2. Les principaux fichiers et services

### Schéma 2 — Vue de l'arborescence de configuration

```text
/etc/
│
├── hosts
│       └── résolution locale
│
├── nsswitch.conf
│       └── ordre des sources de résolution
│
├── resolv.conf
│       └── configuration du résolveur DNS
│
├── hostname
│       └── nom local de la machine
│
├── systemd/
│       └── configuration éventuelle de systemd
│
├── NetworkManager/
│       └── configuration NetworkManager
│
├── netplan/
│       └── configuration réseau sur certaines distributions
│
└── bind/
        │
        ├── named.conf
        ├── named.conf.options
        ├── named.conf.local
        ├── named.conf.default-zones
        │
        └── fichiers de zones
```

Les fichiers réellement présents dépendent de la distribution et des services installés.

### Fichiers/couches à connaître

```text
/etc/hosts
/etc/nsswitch.conf
/etc/resolv.conf
NetworkManager / systemd-networkd / Netplan / DHCP
systemd-resolved (si présent)
/etc/bind/* (si BIND est installé)
```

---

# 3. De la demande de résolution au DNS

Lorsqu'une application veut connaître l'adresse IP d'un nom, par exemple :

```bash
ping example.com
```

elle utilise généralement les mécanismes système de résolution de noms, notamment `getaddrinfo()`.

### Schéma 3 — Chemin complet

```text
              APPLICATION
                   │
                   ▼
             getaddrinfo()
                   │
                   ▼
          /etc/nsswitch.conf
                   │
          ┌────────┴────────┐
          ▼                 ▼
      /etc/hosts           DNS
                              │
                              ▼
                     résolveur local

                   systemd-resolved
                       / dnsmasq

                              │
                              ▼
                       /etc/resolv.conf

                              │
                              ▼
                       DNS récursif
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
                 cache             Internet
                                        │
                                        ▼
                                  DNS autoritatif
                                        │
                                        ▼
                                  fichier de zone
```

---

# 4. `/etc/nsswitch.conf` : où chercher ?

`/etc/nsswitch.conf` définit l'ordre et les sources utilisées par les mécanismes NSS (*Name Service Switch*).

On peut par exemple trouver :

```text
hosts: files dns
```

Cela signifie, de manière simplifiée :

```text
1. consulter les sources "files"
       │
       ▼
   /etc/hosts

2. si nécessaire, consulter DNS
```

Un système utilisant `systemd-resolved` peut avoir une configuration différente, par exemple :

```text
hosts: files dns
```

ou :

```text
hosts: files resolve [!UNAVAIL=return] dns
```

La ligne exacte dépend de la distribution et des composants installés.

### Point important

`nsswitch.conf` **ne contient pas les adresses des serveurs DNS**.

Il indique principalement **quelles sources utiliser et dans quel ordre**.

---

# 5. `/etc/hosts` : la résolution locale

`/etc/hosts` contient des correspondances statiques entre adresses IP et noms.

Exemple :

```text
127.0.0.1       localhost
192.168.1.10    serveur1
192.168.1.20    serveur2
192.168.1.30    nas.example.lan
```

Avec :

```text
hosts: files dns
```

une résolution peut donc être effectuée localement avant de passer par DNS.

Par exemple :

```bash
getent hosts serveur1
```

peut retourner :

```text
192.168.1.10    serveur1
```

sans qu'une requête DNS soit nécessaire.

> `/etc/hosts` est **local à la machine**. Ajouter un nom dans ce fichier ne crée pas un enregistrement DNS sur le réseau.

---

# 6. `/etc/resolv.conf` : vers quel résolveur envoyer les requêtes ?

`/etc/resolv.conf` contient généralement la configuration utilisée par le résolveur DNS du système.

Exemple :

```text
nameserver 192.168.1.1
nameserver 1.1.1.1
search example.local
```

Le paramètre :

```text
nameserver 192.168.1.1
```

indique un serveur DNS à utiliser.

On peut vérifier le contenu avec :

```bash
cat /etc/resolv.conf
```

Mais attention : sur beaucoup de systèmes modernes, `/etc/resolv.conf` est **généré automatiquement ou est un lien symbolique**. Il ne faut donc pas forcément le modifier directement.

---

# 7. `systemd-resolved` et le stub DNS

Sur certaines distributions Linux, `systemd-resolved` fournit un résolveur DNS local.

Il peut utiliser un **stub listener**, c'est-à-dire une petite interface locale qui reçoit les requêtes DNS des applications puis les transmet aux vrais serveurs DNS.

Un cas classique est :

```text
127.0.0.53
```

Le fonctionnement peut alors être représenté ainsi :

```text
Application
    │
    ▼
NSS / getaddrinfo()
    │
    ▼
/etc/resolv.conf
    │
    ▼
127.0.0.53
    │
    ▼
systemd-resolved
    │
    ├── cache local
    │
    ├── configuration DNS par interface
    │
    └── serveurs DNS amont
             │
             ▼
        DNS du réseau
```

### Attention à une confusion fréquente

Le stub n'est pas nécessairement le **serveur DNS final**.

Par exemple :

```text
/etc/resolv.conf
        │
        ▼
127.0.0.53
        │
        ▼
systemd-resolved
        │
        ▼
192.168.1.1
        │
        ▼
Internet / DNS autoritatifs
```

`127.0.0.53` est donc une adresse locale utilisée par `systemd-resolved` pour recevoir les requêtes.

---

# 8. Les fichiers de `systemd-resolved`

Sur un système utilisant `systemd-resolved`, on peut notamment rencontrer :

```text
/run/systemd/resolve/stub-resolv.conf
/run/systemd/resolve/resolv.conf
```

Ces fichiers sont généralement **générés par le service** et se trouvent sous `/run`, qui est un espace runtime.

On peut inspecter les liens avec :

```bash
ls -l /etc/resolv.conf
```

et consulter la configuration active avec :

```bash
resolvectl status
```

### Deux configurations courantes

Le fichier :

```text
/run/systemd/resolve/stub-resolv.conf
```

peut contenir quelque chose comme :

```text
nameserver 127.0.0.53
options edns0 trust-ad
search ...
```

Il sert alors à faire pointer les applications vers le stub local.

Le fichier :

```text
/run/systemd/resolve/resolv.conf
```

peut, lui, contenir les adresses des serveurs DNS réellement utilisés par `systemd-resolved`, par exemple :

```text
nameserver 192.168.1.1
nameserver 1.1.1.1
```

> **Important :** les chemins et le mode exact dépendent de la distribution et de la configuration. Il ne faut pas supposer que tous les Linux utilisent `systemd-resolved`, ni que `/etc/resolv.conf` pointe systématiquement vers le fichier stub.

---

# 9. Mais qui configure tout cela ?

C'est ici qu'intervient la couche réseau.

La configuration DNS peut venir de plusieurs sources :

```text
DHCP
 │
 ▼
NetworkManager / systemd-networkd / Netplan
 │
 ▼
configuration DNS du système
 │
 ▼
systemd-resolved (si utilisé)
 │
 ▼
/etc/resolv.conf
```

### Schéma — Architecture réseau

```text
DHCP

 │

 ▼

NetworkManager / systemd-networkd / netplan

 │

 ▼

résolveur local

 │

 ▼

/etc/resolv.conf
```

Cette partie est essentielle pour comprendre pourquoi une modification manuelle de `/etc/resolv.conf` peut disparaître.

---

# 10. Le rôle du DHCP

Lorsqu'une machine rejoint un réseau, elle peut obtenir automatiquement sa configuration grâce au DHCP.

Le serveur DHCP peut notamment fournir :

```text
Adresse IP
Masque réseau
Passerelle par défaut
Serveurs DNS
Nom de domaine / suffixe de recherche
```

Par exemple :

```text
Client
  │
  │ DHCP
  ▼
Serveur DHCP
  │
  ├── IP : 192.168.1.50
  ├── Gateway : 192.168.1.1
  └── DNS : 192.168.1.1
```

La machine reçoit donc l'information :

```text
"Pour les requêtes DNS, utilise 192.168.1.1"
```

Le composant réseau local, par exemple NetworkManager ou systemd-networkd, récupère cette information et la transmet au résolveur utilisé par le système.

---

# 11. Pourquoi `/etc/resolv.conf` peut changer automatiquement ?

Parce qu'il peut être le résultat de plusieurs couches :

```text
                   Serveur DHCP
                        │
                        ▼
              configuration réseau
                        │
              ┌─────────┴─────────┐
              ▼                   ▼
       NetworkManager       systemd-networkd
              │                   │
              └─────────┬─────────┘
                        ▼
                 systemd-resolved
                        │
                        ▼
              /run/systemd/resolve/
                        │
                        ▼
                 /etc/resolv.conf
```

Selon la distribution, d'autres architectures sont possibles.

Par exemple :

```text
DHCP
 │
 ▼
NetworkManager
 │
 ▼
dnsmasq
 │
 ▼
/etc/resolv.conf
```

ou :

```text
DHCP
 │
 ▼
systemd-networkd
 │
 ▼
systemd-resolved
 │
 ▼
/etc/resolv.conf
```

---

# 12. Comment savoir quelle architecture utilise ma machine ?

## Vérifier `/etc/resolv.conf`

```bash
ls -l /etc/resolv.conf
cat /etc/resolv.conf
```

## Vérifier systemd-resolved

```bash
systemctl status systemd-resolved
```

Puis :

```bash
resolvectl status
```

## Vérifier NetworkManager

```bash
systemctl status NetworkManager
```

Puis :

```bash
nmcli device show
```

Chercher notamment :

```text
IP4.DNS[1]
IP4.DNS[2]
```

## Vérifier systemd-networkd

```bash
systemctl status systemd-networkd
```

## Vérifier Netplan

Sur Ubuntu et certaines distributions :

```bash
ls /etc/netplan/
```

Puis :

```bash
cat /etc/netplan/*.yaml
```

---

# 13. Tester la résolution comme le système

Une commande particulièrement utile est :

```bash
getent hosts example.com
```

Pourquoi utiliser `getent` ?

Parce qu'il passe par les mécanismes NSS.

On peut comparer avec :

```bash
dig example.com
```

`dig` est différent : il permet d'interroger directement DNS et est donc excellent pour diagnostiquer la couche DNS.

Par exemple :

```bash
dig example.com
```

puis :

```bash
dig @8.8.8.8 example.com
```

Le deuxième test demande explicitement à `8.8.8.8`.

---

# 14. Comprendre un DNS récursif

Un DNS récursif est un serveur qui reçoit une demande d'un client et cherche la réponse pour lui.

Supposons qu'un client demande :

```text
www.example.com
```

Le résolveur récursif peut devoir suivre la hiérarchie DNS :

```text
Client
  │
  ▼
DNS récursif
  │
  ▼
Serveurs racine "."
  │
  ▼
Serveurs ".com"
  │
  ▼
Serveurs autoritatifs "example.com"
  │
  ▼
www.example.com
```

Il récupère ensuite la réponse et peut la conserver dans son cache pendant la durée du TTL.

---

# 15. DNS récursif ≠ DNS autoritatif

Il faut absolument distinguer les deux.

### DNS récursif

Il cherche les réponses pour ses clients.

```text
Client
   │
   ▼
DNS récursif
   │
   ├── cache
   │
   └── recherche DNS
```

### DNS autoritatif

Il possède les données officielles d'une zone.

Par exemple :

```text
example.com
```

avec :

```text
www.example.com → 203.0.113.10
mail.example.com → 203.0.113.20
```

Le serveur autoritatif lit ces informations depuis ses données de zone.

---

# 16. BIND : le serveur DNS classique sous Linux

BIND (*Berkeley Internet Name Domain*) est l'un des serveurs DNS les plus connus.

Sur Debian/Ubuntu :

```bash
sudo apt install bind9
```

Les fichiers sont généralement sous :

```text
/etc/bind/
```

On peut notamment trouver :

```text
/etc/bind/named.conf
/etc/bind/named.conf.options
/etc/bind/named.conf.local
/etc/bind/named.conf.default-zones
```

et des fichiers de zone comme :

```text
/etc/bind/db.example.com
```

---

# 17. Hiérarchie de configuration BIND

Une architecture typique est :

```text
/etc/bind/
│
├── named.conf
│
├── named.conf.options
│
├── named.conf.local
│
├── named.conf.default-zones
│
└── fichiers de zones
        │
        ├── db.example.com
        └── db.192.168.1
```

Le fichier principal peut inclure les autres :

```conf
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
include "/etc/bind/named.conf.default-zones";
```

---

# 18. Déclarer une zone DNS

Dans :

```text
/etc/bind/named.conf.local
```

on peut déclarer :

```conf
zone "example.com" {
    type master;
    file "/etc/bind/db.example.com";
};
```

Le fichier :

```text
/etc/bind/db.example.com
```

contient alors les enregistrements de la zone.

Exemple :

```dns
$TTL 86400

@   IN SOA ns1.example.com. admin.example.com. (
        2026082301
        3600
        1800
        604800
        86400
)

@       IN NS ns1.example.com.
ns1     IN A 192.168.1.10

www     IN A 192.168.1.100
mail    IN A 192.168.1.200
```

---

# 19. Les principaux types d'enregistrements DNS

### A

```dns
www IN A 192.168.1.100
```

Nom → IPv4.

### AAAA

```dns
www IN AAAA 2001:db8::100
```

Nom → IPv6.

### CNAME

```dns
web IN CNAME www.example.com.
```

Alias → autre nom.

### MX

```dns
@ IN MX 10 mail.example.com.
```

Serveur de messagerie.

### NS

```dns
@ IN NS ns1.example.com.
```

Serveur DNS autoritatif.

### PTR

Utilisé pour la résolution inverse :

```text
IP → nom
```

### SOA

Décrit l'autorité et les paramètres principaux de la zone.

### TXT

Contient des données textuelles utilisées notamment par SPF, DKIM, vérifications de domaine, etc.

---

# 20. Comment faire reconnaître son DNS depuis Internet ?

Il faut distinguer deux choses :

> **Faire connaître un serveur DNS sur Internet ne consiste pas simplement à installer BIND.**

Pour qu'un domaine comme :

```text
example.com
```

soit résolu publiquement, il faut notamment :

```text
                   Internet
                       │
                       ▼
                DNS racine "."
                       │
                       ▼
                    ".com"
                       │
                       ▼
                example.com
                       │
                       ▼
              serveurs NS déclarés
                       │
                       ▼
                ton DNS autoritatif
                       │
                       ▼
                  zone DNS
```

Il faut donc que la délégation du domaine pointe vers tes serveurs DNS autoritatifs.

---

# 21. Délégation DNS

Supposons que tu possèdes :

```text
example.com
```

Tu veux utiliser :

```text
ns1.example.com
ns2.example.com
```

Le registre du TLD `.com` doit connaître les serveurs autoritatifs du domaine.

Conceptuellement :

```text
.com
 │
 └── example.com
       │
       ├── NS ns1.example.com
       └── NS ns2.example.com
```

Les serveurs `ns1` et `ns2` doivent ensuite être accessibles depuis Internet et répondre correctement aux requêtes DNS.

---

# 22. Pourquoi deux DNS ?

En production, on utilise généralement plusieurs serveurs autoritatifs.

Par exemple :

```text
example.com
    │
    ├── NS ns1.example.net
    │
    └── NS ns2.example.net
```

Pourquoi ?

Pour la disponibilité.

Si :

```text
ns1
```

est indisponible, le résolveur peut interroger :

```text
ns2
```

Il est également fréquent que les serveurs soient répartis sur des réseaux ou des infrastructures différentes.

---

# 23. Les glue records

Un cas particulier apparaît lorsque les serveurs DNS sont eux-mêmes sous le domaine qu'ils servent.

Par exemple :

```text
example.com
    NS ns1.example.com
```

Pour trouver `ns1.example.com`, il faut déjà savoir où trouver `example.com`.

C'est une dépendance circulaire.

Les **glue records** permettent au registre du parent de fournir l'adresse IP du serveur de noms dans la délégation.

Conceptuellement :

```text
.com
 │
 ├── example.com → NS ns1.example.com
 │
 └── glue : ns1.example.com → IP
```

C'est une notion importante lorsqu'on configure ses propres serveurs DNS autoritatifs.

---

# 24. Ce qu'il faut pour exposer un DNS autoritatif sur Internet

À haut niveau :

```text
1. Posséder un domaine
        │
        ▼
2. Déclarer des serveurs NS
        │
        ▼
3. Configurer les zones DNS
        │
        ▼
4. Rendre les serveurs accessibles depuis Internet
        │
        ├── UDP/53
        └── TCP/53
        │
        ▼
5. Configurer correctement les enregistrements
        │
        ▼
6. Vérifier la délégation
```

Il faut également prévoir :

- une adresse IP publique stable ;
- un firewall correctement configuré ;
- au moins deux serveurs autoritatifs en production ;
- des zones correctement configurées ;
- une délégation correcte chez le registrar/registre ;
- éventuellement des glue records ;
- une configuration sécurisée ;
- une surveillance et des logs.

---

# 25. Tester son serveur DNS depuis l'extérieur

Une fois le serveur accessible, on peut tester directement :

```bash
dig @203.0.113.10 example.com SOA
```

Puis :

```bash
dig @203.0.113.10 example.com NS
```

Puis :

```bash
dig @203.0.113.10 www.example.com A
```

On peut également examiner la chaîne de résolution avec :

```bash
dig +trace example.com
```

`+trace` est particulièrement intéressant pour comprendre la délégation :

```text
racine
  ↓
TLD
  ↓
serveurs autoritatifs
  ↓
zone
```

---

# 26. Résumé de la hiérarchie complète

La résolution DNS sous Linux peut être comprise comme une succession de couches :

```text
APPLICATION
    │
    ▼
getaddrinfo()
    │
    ▼
NSS
/etc/nsswitch.conf
    │
    ├── files
    │     │
    │     ▼
    │  /etc/hosts
    │
    └── DNS / resolve
          │
          ▼
    Résolveur local
          │
          ├── cache
          ├── systemd-resolved
          ├── dnsmasq
          └── autre
          │
          ▼
    /etc/resolv.conf
          │
          ▼
    DNS récursif
          │
          ├── cache
          │
          └── recherche DNS
                 │
                 ▼
              racine
                 │
                 ▼
                TLD
                 │
                 ▼
        DNS autoritatif
                 │
                 ▼
             zone DNS
```

---

# 27. La chaîne de configuration à retenir

Pour comprendre **comment la configuration arrive jusqu'à l'application**, pense à cette chaîne :

```text
                 DHCP / configuration statique
                           │
                           ▼
              NetworkManager / systemd-networkd
                           │
                           ▼
                  systemd-resolved
                       (si utilisé)
                           │
                           ▼
                  /run/systemd/resolve/
                           │
                           ▼
                   /etc/resolv.conf
                           │
                           ▼
                    getaddrinfo()
                           │
                           ▼
                  /etc/nsswitch.conf
                           │
                    ┌──────┴──────┐
                    ▼             ▼
               /etc/hosts       DNS
```

Le détail exact dépend toutefois de la distribution et de l'architecture réseau choisie.

---

# 28. Commandes essentielles

### Voir la configuration locale

```bash
cat /etc/hosts
cat /etc/nsswitch.conf
cat /etc/resolv.conf
```

### Vérifier les liens

```bash
ls -l /etc/resolv.conf
```

### Vérifier systemd-resolved

```bash
systemctl status systemd-resolved
resolvectl status
resolvectl query example.com
```

### Vérifier NetworkManager

```bash
systemctl status NetworkManager
nmcli device show
```

### Tester la résolution via NSS

```bash
getent hosts example.com
```

### Tester DNS

```bash
dig example.com
```

### Interroger un DNS précis

```bash
dig @1.1.1.1 example.com
```

### Résolution inverse

```bash
dig -x 192.168.1.10
```

### Suivre la délégation DNS

```bash
dig +trace example.com
```

---

# 29. Diagnostic : par où commencer ?

Si `example.com` ne se résout pas, ne modifie pas directement les fichiers au hasard.

Remonte la chaîne :

```text
1. /etc/hosts
       ↓
2. /etc/nsswitch.conf
       ↓
3. /etc/resolv.conf
       ↓
4. systemd-resolved / dnsmasq / autre
       ↓
5. serveur DNS configuré
       ↓
6. DNS récursif
       ↓
7. DNS autoritatif
       ↓
8. zone DNS
```

Quelques tests :

```bash
getent hosts example.com
```

puis :

```bash
dig example.com
```

puis :

```bash
dig @8.8.8.8 example.com
```

Si le troisième fonctionne mais pas le deuxième, le problème se situe probablement entre la machine et le résolveur configuré localement.

Si le serveur DNS interne ne répond pas :

```bash
dig @192.168.1.10 example.com
```

il faut alors diagnostiquer ce serveur.

---

# 30. Les grandes idées à retenir

## 1. `/etc/hosts`

Résolution locale statique :

```text
nom → IP
```

## 2. `/etc/nsswitch.conf`

Détermine les sources et leur ordre :

```text
files → dns → ...
```

## 3. `/etc/resolv.conf`

Indique généralement au résolveur quels serveurs DNS utiliser.

## 4. NetworkManager / systemd-networkd / Netplan / DHCP

Construisent ou fournissent la configuration réseau et DNS.

## 5. `systemd-resolved`

Peut fournir un résolveur/cache local et un stub DNS, souvent accessible via :

```text
127.0.0.53
```

## 6. DNS récursif

Cherche les réponses pour les clients et peut les mettre en cache.

## 7. DNS autoritatif

Possède les données officielles d'une zone.

## 8. BIND

Permet de créer un véritable serveur DNS, notamment autoritatif et/ou récursif selon sa configuration.

## 9. DNS public

Pour rendre un domaine accessible depuis Internet, il faut une délégation correcte depuis le domaine parent/TLD vers les serveurs DNS autoritatifs.

---

# 31. Carte mentale finale

```text
                         INTERNET
                            │
                            ▼
                    DNS racine "."
                            │
                            ▼
                         TLD .com
                            │
                            ▼
                  DNS autoritatif
                  pour example.com
                            │
                            ▼
                      zone DNS
                            │
                            │
                       DNS récursif
                            ▲
                            │
                    cache / résolution
                            ▲
                            │
                    résolveur local
                            ▲
                            │
                  systemd-resolved
                       / dnsmasq
                            ▲
                            │
                    /etc/resolv.conf
                            ▲
                            │
                   /etc/nsswitch.conf
                     ▲             ▲
                     │             │
               /etc/hosts        DNS
                     ▲
                     │
                Application
```

La question fondamentale à se poser lorsqu'on travaille avec DNS sous Linux est donc toujours :

> **À quel niveau de la chaîne suis-je en train de configurer ou de diagnostiquer le DNS ?**

C'est cette distinction entre **résolution locale, NSS, résolveur local, configuration réseau, DNS récursif et DNS autoritatif** qui permet de comprendre la majorité des problèmes DNS sous Linux.
