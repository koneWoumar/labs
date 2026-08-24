# Exploitation de dnsmasq


TODO anderstand:

- Exploration de nsswich config

- Comprendre la config reseau / dns de mon system actuelle avec le wifi

- Apres la mise en place d'un dns sous une vm openstack, indiqueer à mon systeme d'utiliser ce dns, et faire des tests.

- systemd qui  se trouve dans la config de nsswith fait quoi ?

- hierarchiver les utilitaire network manager, netplan et systemd-network, dhcp

- dans le cas ou le fichier /etc/resolv et ... sont generer automatiquement, ou les modifier pour ..

- A faire : associer un domaine à une interface reseau.



Todo  : (ce qui doit apparaitre dans mon tp)


t1 :
- faire utiliser un dns de mon reseau openstack par mon systme (sur le domaine associé)

t2:
- deux reseau privé pour une machine
- associer des domaines à chaque interface pour chaque reseau ?
- associé des domaine à chaque reseau ?


t3:
- deployer un config manuelle netplan/network manager voir manuelle depuis openstack (ip+dns+getway)
- puis une config automatique (un serveur dhcp qui donne automatiquement au machine ces meme info)

t4 :



## Mise en place en tant que dns du domaine


Comment mettre en place un domaine entre plusieurs serveurs. en entreprise comment cela se passe avec openstack, virtualbox ...

Peut on executer des conteneurs linux leger sous vmware ?



