## TP 0 : route, getway, route par defaut

### 1 - Architecture generale

Dans ce tp, on met en exergue les notions de route, route par defaut.

Soit cette architecture suivantes. Notre objectif est de permettre au client d'envoyer des paquets sur internet.


Architecture mis en exergue pour la comm avec deux reseau different
```text
                         INTERNET
                            │
                         ┌─────┐
                         │ BOX │
                         └──┬──┘
                            │
                    192.168.1.0/24
                            │
              ┌─────────────┴─────────────┐
              │                           │
          Ton PC                     servera
                                      ens192
                                  192.168.1.132
                                      │
                                      │
                               ens32 / Host-only
                                  192.168.2.10
                                      │
                                      │
                                  192.168.2.0/24
                                      │
                                      │
                                   client
                                  192.168.2.20
```

### 2 - Configuration des reseaux

Pour la configuration reseau, nous utilisons netplan pour generer la configuration des interfaces reseaux.

- Le pc et sera sont dans le reseau brigde avec VMware, donc ils reçoivent directement leur adressage de l'interface lié à la boxe via les services du dhcp

- Le servera est configuré comme suite pour son adressage avec l'interface lié au reseau host-only :

```YAML
network:
  version: 2

  ethernets:
    ens32:
      dhcp4: false
      addresses:
        - 192.168.2.10/24
          #match:
          #macaddress: 00:0c:29:95:c2:cb
          #set-name: ens32

      nameservers:
        addresses:
          - 192.168.1.132
            #search:
          #- arrow.local
            #routes:
            #- to: 192.168.1.0/24
            #via: 192.168.2.11
```
Application de la configuragtion :

```bash
sudo netplan generate
sudo netplan apply
```

Verification de la configuration :

```bash
# la commande 'ip a' donne :

3: ens32: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:95:c2:cb brd ff:ff:ff:ff:ff:ff
    altname enp2s0
    inet 192.168.2.20/24 brd 192.168.2.255 scope global ens32
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:fe95:c2cb/64 scope link 
       valid_lft forever preferred_lft forever

# la commande "ip route" donne
lab@client:~$ ip route
default via 192.168.2.10 dev ens32 proto static 
192.168.2.0/24 dev ens32 proto kernel scope link src 192.168.2.20 
```
On voit bien qu'il y'a la route par defaut qui est defini automatiquement par l'adressage.



- Le client est configuré comme suite pour son adressage avec l'interface lié au reseau host-only :

```YAML
network:
  version: 2
  ethernets:
    ens32:
      dhcp4: false
      addresses:
        - 192.168.2.20/24
      nameservers:
        addresses:
          - 192.168.1.132
        search:
          - arrow.local
      routes:
        - to: default
          via: 192.168.2.10
```

Pour appliquer ces configuration, on fait :

```bash
sudo netplan generate
sudo netplan apply
```

On verifie la configuration :

```bash
3: ens32: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:95:c2:cb brd ff:ff:ff:ff:ff:ff
    altname enp2s0
    inet 192.168.2.20/24 brd 192.168.2.255 scope global ens32
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:fe95:c2cb/64 scope link 
       valid_lft forever preferred_lft forever
lab@client:~$ ip route
default via 192.168.2.10 dev ens32 proto static 
192.168.2.0/24 dev ens32 proto kernel scope link src 192.168.2.20 
lab@client:~$ 
```
ON voit que la route par defaut est bien defini automatiquement.


### 3 - Comment permettre au client d'aller sur la boxe ?

L'architecture simplifie de notre tp se presente comme suite :


```text
                    servera
             ┌──────────────────┐
             │                  │
client ─────►│ ens32            │
192.168.2.20 │ 192.168.2.10     │
             │                  │
             │ IP forwarding    │
             │ NAT              │
             │                  │
             │ ens192           │
             │ 192.168.1.132    │
             └────────┬─────────┘
                      │
                      ▼
                     BOX
                      │
                      ▼
                  INTERNET
```

Le client doit envoyer des paquets à un équipement qui n'ai pas dans son reseau, pour cela il transmet ces paquet à l'interface indiqué par sa route par defaut et les paquets arrivent à sa getway. Les paquet arrivent sur le servera.
Le servera joue exactement le role de router ici, il doit permetra à deux reseaux differents de communiquer. Ce servera etant un server linux, il faut alors : 

Activer le routage qui par defaut est desactivé et qui permet d'acheminer des paquets.
Activer le NAT qui permet la transmission de paquet entre deux interface du router( servera ici)

- Verification de l'etat du routage

```bash
sysctl net.ipv4.ip_forward
```

- Activer le routage

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```


- Activer le routage

```bash
sudo sysctl -w net.ipv4.ip_forward=1

#rendre le routage perment
sudo nano /etc/sysctl.d/99-router.conf
net.ipv4.ip_forward=1

#appliquer le changement:
sudo sysctl --system
```


- Activer le NAT

```bash

# Test de l'etat du NATl
sudo iptables -t nat -A POSTROUTING -s 192.168.2.0/24 -o ens192 -j MASQUERADE

#Puis autorise le forwarding :
sudo iptables -A FORWARD -i ens32 -o ens192 -s 192.168.2.0/24 -j ACCEPT

# Et le trafic retour :
sudo iptables -A FORWARD -i ens192 -o ens32 -d 192.168.2.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT



```

### Pour resumer


On voulais arriver ici :

```text
                         INTERNET
                            ▲
                            │
                       ┌────┴────┐
                       │   BOX   │
                       │192.168.1.1
                       └────┬────┘
                            │
                 192.168.1.0/24
                            │
                       192.168.1.132
                       ┌────┴─────┐
                       │ SERVERA  │
                       │          │
                       │ ROUTAGE  │
                       │   + NAT  │
                       │          │
                       └────┬─────┘
                       192.168.2.10
                            │
                 192.168.2.0/24
                            │
                       192.168.2.20
                       ┌────┴─────┐
                       │  CLIENT  │
                       └──────────┘
```

il fallait faire :

```text
SERVERA
   │
   ├── IP forwarding = 1
   │
   ├── FORWARD ens32 → ens192
   │
   └── MASQUERADE 192.168.2.0/24 → ens192
```



### Definition des notion

#### Route static

Définir une route IP statique est pertinent dès que votre machine doit communiquer avec un autre réseau que le sien, mais qu'elle ne peut pas (ou ne doit pas) passer par sa passerelle Internet par défaut

Voici les 3 situations principales où l'ajout d'une route IP est indispensable :

1. Interconnecter des réseaux privés isolés (Votre cas actuel)

C'est exactement la configuration de votre laboratoire VMware.Votre VM 192.168.2.20 est dans un réseau Host-Only isolé. Elle n'a pas d'accès direct au réseau 192.168.1.0/24.Pour qu'elle puisse lui parler, vous devez lui donner un "chemin" : la route IP lui dit explicitement : "Si tu veux envoyer un paquet vers le réseau 1, donne-le d'abord à la VM 192.168.2.10, c'est elle qui sait comment y aller".

2. Segmenter le trafic (Sécurité et Performance)

Dans les entreprises, on sépare souvent les types de trafic. Imaginez un ordinateur qui possède deux cartes réseaux :Carte A : Connectée à Internet via la passerelle par défaut.Carte B : Connectée à un réseau interne de serveurs de sauvegarde ou de base de données (ex: 10.50.0.0/16).Sans route spécifique, si l'ordinateur essaie de contacter le serveur de base de données, il va envoyer la demande sur Internet (Carte A) et cela va échouer. En définissant une route statique, vous forcez l'ordinateur à utiliser la Carte B uniquement lorsqu'il veut joindre le réseau 10.50.0.0/16.

3. Accéder à un réseau distant via un VPN ou un Routeur spécifique

Si votre entreprise possède un site à Paris (192.168.2.0/24) et un site à Lyon (192.168.3.0/24), reliés par un routeur VPN dédié :Les ordinateurs de Paris ont besoin d'une route IP locale leur indiquant que pour joindre Lyon (192.168.3.0), ils doivent envoyer leurs paquets à l'adresse IP locale du routeur VPN, et non à leur box Internet classique.


#### Proxy


