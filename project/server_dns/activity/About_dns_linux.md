# Chapitre sur le DNS

## Nework config relative to dns

Tentativement de reponse à la question suivante : 

Comment les configurations reseaux sont propagées sous linux ?


1. La hiérarchie générale


```
                         CONFIGURATION ADMIN
                                │
                   ┌────────────┴────────────┐
                   │                         │
                Netplan                Configuration
             (si utilisé)                  directe
                   │                         │
                   │                         │
            génère/applique                  │
             une configuration               │
                   │                         │
             ┌─────┴─────┐                   │
             │           │                   │
             ▼           ▼                   │
   systemd-networkd   NetworkManager ◄───────┘
             │           │
             │           │
             │           ├──────────► Wi-Fi
             │           │              │
             │           │              ▼
             │           │             DHCP
             │           │              │
             │           │              ▼
             │           │        IP / Gateway / DNS
             │           │
             │           │
             ├───────────┼───────────────────┐
             │           │                   │
             │           │                   │
             ▼           ▼                   ▼
       Interface     Interface        systemd-resolved
        réseau        réseau             (si utilisé)
       eth0/ens18     wlan0                   │
             │           │                    │
             │           │                    ▼
             │           │          /run/systemd/resolve/
             │           │                    │
             └───────────┴────────────────────┘
                         │
                         ▼
                  IP / routes / DNS

```


2. Netplan

Netplan est particulièrement courant sur Ubuntu.

Il lit par exemple :

```
/etc/netplan/
    00-installer-config.yaml
    50-cloud-init.yaml
    01-network.yaml
```

exemple :


```yaml
network:
  version: 2
  ethernets:
    ens18:
      dhcp4: true
      nameservers:
        addresses:
          - 192.168.1.1
          - 1.1.1.1
```

Netplan ne gère généralement pas lui-même l'interface réseau.

Il prend cette configuration et la traduit pour un backend :


```
/etc/netplan/*.yaml
        │
        ▼
      netplan
        │
        ├───────────────┐
        ▼               ▼
NetworkManager    systemd-networkd

```
On peut voir le backend comme :

```YML
renderer: NetworkManager
```

ou

```YML
renderer: NetworkManager
```

Donc :

```
Netplan = couche de configuration/génération
NetworkManager/systemd-networkd = gestionnaires réseau
```

3. NetworkManager


NetworkManager est un gestionnaire réseau complet.

Il gère notamment :

- interfaces Ethernet
- Wi-Fi
- DHCP
- adresses IP
- routes
- DNS
- VPN
- profils réseau

Ses configurations persistantes se trouvent notamment sous :


```
/etc/NetworkManager/
```

et les profils de connexion généralement sous :

```
/etc/NetworkManager/system-connections/
```

```bash
nmcli
```

Par exemple :

```bash
nmcli device status
```

4. systemd-networkd

systemd-networkd est l'autre grand gestionnaire réseau.

Sa configuration persistante se trouve principalement ici :


/etc/systemd/network/


Par exemple :

/etc/systemd/network/
    10-ens18.network
    20-eth0.network


Avec :

[Match]
Name=ens18

[Network]
DHCP=yes
DNS=192.168.1.1
DNS=1.1.1.1


Puis :


```
/etc/systemd/network/*.network
             │
             ▼
     systemd-networkd
             │
             ▼
        interface
             │
             ├── IP
             ├── routes
             └── DNS
                     │
                     ▼
              systemd-resolved
```


5. Et systemd-resolved ?


C'est là qu'il faut faire attention : systemd-networkd et systemd-resolved sont deux services différents.

systemd-resolved s'occupe principalement de la résolution DNS.


6. Les quatre couches à retenir


```
                 /etc/netplan/*.yaml
                         │
                         │ si Netplan est utilisé
                         ▼
                    ┌─────────┐
                    │ Netplan │
                    └────┬────┘
                         │
               ┌─────────┴─────────┐
               │                   │
               ▼                   ▼
      NetworkManager       systemd-networkd
               │                   │
               └─────────┬─────────┘
                         │
                         ▼
                    Interface
                  ens18 / eth0
                         │
                  IP / routes / DHCP
                         │
                         ▼
                  systemd-resolved
                         │
                         ▼
                /run/systemd/resolve/
                         │
                         ▼
                   /etc/resolv.conf
```


--> Je doit ajouter wifi + dns dans le schema ci-dessous et comprendre pourquoi avoir mis DHCP au meme niveau que les interface?

La configuration du dhcp à contacter se propagerait depuis netplan et passant par les gestionnaires de reseau (networManager et systemd-networkd) 



## Important notions about dns



## TP on dns thematique


### TP 1 : Prise en main de bind9

- Mise en place de bind9
- Comprension de ses abstractions : zone, delegation , dns recursif et autoritatif
- Mise en place d'une architecture client-serveur :
- le serveur bind9 avec deux domaines (basta.fr et nok.basta.fr)
- le client testera le resoudre des hostnames dejà enregistré sur le serveur.
- mise en oeuvre de la notion de zone, zone delegué, 
- Comprendre comment se materialise les notions de recursif et autoritatif , zone et zone deleguée




### TP 2 : Serveur DNS recursif et autoritatif

- Architecture avec deux serveurs pour 2 domaines
- L'un configurer en recursif et l'autre en autoritatif 



### TP 3 : Domaine de recherche

- architecture: deux servurs et un client
- le client et chaque serveur sont dans deux reseaux distinct.
- ces deux reseaux doivre etre distincts.
(possible avec openstack , il faudrait verifier)
- sur chaque serveur, il y' a un dns publiant une zone.
- parametré le client pour chaque interface avec (root, dns et domaine de recherche)
- Tester 


### TP 3 : Top level domaine

- acheter un domaine
- creer une zone dans gcc
- enregistré ce domaine dans l'annuaire du tlp avec la zone créér
- sous terminal linux, faire une requete pour retrouver mon domaine dans le tlp
- faire une requete pour avoir les serveurs de dns de la zone ou des zones pointé par le domaine
- Repondre à la question suivante :
Si une zone est créér par un sous domaine, qu'est-ce qui est enregistré dans le registre ? 
-> simplement la zone du domaine de base ? c'est cette zone qui indiquera par delegation ou se trouve la zone du sous domaine  ?


### TP 0 : Configuration Reseau

- Architecture : client + serveur(dns+dhcp)
- Les deux seront configuré au niveau reseau avec netplan
- Avec netplan, metre une config static (ip+route+dns) appliqué au client:
- observé ce qui se passe au niveau de network manager et systemd-networkd
- Refaire une config avec netplan pointé sur le serveur dhcp.
- demander les infos au dhcp et voir ce qui se passe à tous les niveaux 




Comment mettre en place un domaine entre plusieurs serveurs. en entreprise comment cela se passe avec openstack, virtualbox ...

Peut on executer des conteneurs linux leger sous vmware ?



