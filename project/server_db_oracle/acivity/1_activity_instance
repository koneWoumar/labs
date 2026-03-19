----------------------------------------------------------VERIFICATIONS------------------------------------------------------------------

# Verifier que le moteur oracle est installé
------> difficile de le faire directement mais on peut regarder $ORACLE_HOME/bin si les binaires existent



# Verifier qu'une instance de base de données est encours
ps -ef | grep pmon | grep -v grep
------> un process ora_pmon_ORACE_SID doit exister pour chaque instances demarrées




# Verifier qu'un listener est en place
ps -ef | grep tnslsnr | grep -v grep
--------> permet de voir le processus du listener
lsnrctl status
--------> permet de voir le status du listener



# Utilitaire de gestion des listener
lsnrctl --> status, reload, stop, start ...




# Verifier l'etat de la base
sqlplus / as sysdba

SELECT name, open_mode FROM v$database;
---> NOM et MODE d'ouverture (STARTED,MOUNTED,OPEN)



# Verivier l'etat de l'instance
SELECT status FROM v$instance;
----> le status de la base (MOUNTED,READ ONLY,READ WRITE)



# Verifier les restriction de session
SELECT logins FROM v$instance;
------------> (ALLOWED,RESTRICTED)
ALTER SYSTEM ENABLE RESTRICTED SESSION;
-----------> activation de la restriction
ALTER SYSTEM DISABLE RESTRICTED SESSION;
-----------> desactivation de la restriction




# Vue dynamique des instances de la base
Les vues v$ sont des vues dynamiques elles reflètent ce qui est en mémoire donc ce qui est porté par l’instance
--------> pour voir la liste de toutes les vues
select view_name from v$fixed_view_definition order by view_name;
--------> Voici quelques 5 vues importantes et leurs roles :

V$INSTANCE ----> decrire l etat de l'instance : demarrer, arreter, ouvir, fermer
V$DATABASE ----> decription logique de la base de données : READ, WRITE, MOUNT ...
V$DATAFILE ----> Liste des datafiles, emplacement disque, etat des fichiers : Lien base logique ↔ fichiers physiques
V$PARAMETER ----> configuration de l’instance, Paramètres mémoire, Paramètres de démarrage, Valeurs actives
V$SESSION  -----> activité utilisateur : Sessions connectées, États des sessions Diagnostic des blocages




-----------------------------------------------------------------ARRET/RELANCE/VERIFICATIONS------------------------------------------------------

# Arret / Relance / Verification / du listener 
lsnrctl stop
lsnrctl status -----> plus de listener
sqlplus PDBADMIN/Oracle123@localhost:1521/ORCLPDB1   ----> KO
lsnrctl start
sqlplus PDBADMIN/Oracle123@localhost:1521/ORCLPDB1   ----> OK




# Arret / Relance / Verification / de l'instance
SHUTDOWN IMMEDIATE;        
--------------> Arreter l'instance et par consequent demonte et ferme la base car la base depnds de son instance

STARTUP;                 
--------------> redemarrer l'instance, monter et ouvrir la base

STARTUP NOMOUNT;
----------------> redemarrer l'instance sans monter la base




SELECT status FROM v$instance;
----------> verification

{

----->  Les 3 étapes du démarrage Oracle graduelle

1️⃣ STARTUP NOMOUNT   → Instance seulement
2️⃣ ALTER DATABASE MOUNT  → Lecture control file
3️⃣ ALTER DATABASE OPEN   → Ouverture datafiles

}



# Les 2 niveaux d'arret de la base
ALTER DATABASE CLOSE;
------------------> Fermer la base (status=)

ALTER DATABASE DISMOUNT;
------------------> demonter la base (status = STARTED)

SELECT status,open_mode FROM v$database;
-------------> Verification


# Les 2 niveaux de demarrage de la base
ALTER DATABASE OPEN;
------------------> Ouvrir la base (status=)

ALTER DATABASE MOUNT;
------------------> Monter la base (status = STARTED)

SELECT status,open_mode FROM v$database;
-------------> Verification





-----------------------------------------------------------------TNS NAME & LISTENER------------------------------------------------

# Mise en place d'un listener



# Mise en place d'un tnsname










  
