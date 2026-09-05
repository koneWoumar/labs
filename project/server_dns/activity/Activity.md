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
           Netplan                 Configuration
        (si utilisé)              directe
              │
       génère une config
              │
       ┌──────┴───────┐
       │              │
       ▼              ▼
NetworkManager   systemd-networkd
       │              │
       └──────┬───────┘
              │
              ▼
        Interfaces réseau
       eth0 / ens18 / enp...
              │
              ▼
        DNS / routes / IP
              │
              ▼
     systemd-resolved
       (si utilisé)
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








Comment mettre en place un domaine entre plusieurs serveurs. en entreprise comment cela se passe avec openstack, virtualbox ...

Peut on executer des conteneurs linux leger sous vmware ?



