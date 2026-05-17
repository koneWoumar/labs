#!/bin/bash

#source ../config/projet.properties

FILE="../sql/requetes.deploy"

while IFS='|' read ID SCHEMA COMMENT SQL
do

## Rentre dans une boucle parcourant le fichier requete.deploy

# On recupere les donnees de l'entete du fichier


SQL=$(echo "$SQL" | tr '§' '\n')

echo "================================"
echo "ID : $ID"
echo "Schema : $SCHEMA"


# On recupere les donnees db connexion pour le schema


USERNAME=$(grep "${SCHEMA}.db.username" \
../config/projet.properties \
| cut -d= -f2)

PASSWORD=$(grep "${SCHEMA}.db.password" \
../config/projet.properties \
| cut -d= -f2)


# Pour ces donnees ci-dessous, on recupere la valeur specifique si non existante, la valeur par defaut


DB_HOST=$(grep "${SCHEMA}.db.host" \
../config/projet.properties \
| cut -d= -f2)



DB_PORT=$(grep "${SCHEMA}.db.port" \
../config/projet.properties \
| cut -d= -f2)

ORACLE_SID=$(grep "${SCHEMA}.db.oracle.service" \
../config/projet.properties \
| cut -d= -f2)


# On verifie que la table version_requete existe, sinon on la cree.

echo "[INFO] Vérification table"

sqlplus -S \
${USERNAME}/${PASSWORD}@//localhost:1521/ORCLPDB1 <<EOF

WHENEVER SQLERROR CONTINUE

DECLARE
c NUMBER;
BEGIN

SELECT COUNT(*)
INTO c
FROM user_tables
WHERE table_name='VERSION_REQUETE';

IF c=0 THEN

EXECUTE IMMEDIATE '

CREATE TABLE version_requete(

id_requete NUMBER PRIMARY KEY,
etat VARCHAR2(5),
commentaire VARCHAR2(500),
date_execution DATE,
date_fin DATE,
message_erreur CLOB

)';

END IF;

END;
/

EXIT

EOF


# On verifie si ID de la requete existe dans la table version_requete.


ALREADY_DONE=$(sqlplus -S \
${USERNAME}/${PASSWORD}@//localhost:1521/ORCLPDB1 <<EOF

SET PAGESIZE 0
SET FEEDBACK OFF

SELECT COUNT(*)

FROM version_requete

WHERE id_requete=$ID
AND etat='OK';

EXIT

EOF
)

# si ID de la requete existe, on va sur la requete suivante

ALREADY_DONE=$(echo "$ALREADY_DONE"|xargs)

if [ "$ALREADY_DONE" = "1" ]
then

echo "[INFO] Requête $ID déjà exécutée"

continue

fi

# si ID de la requete est non existante, on execute la requete en cours de traitement.
# si le resultat est sans erreur, insert la requete dans version_schema avec ok .

echo "[INFO] Exécution"

sqlplus -S \
${USERNAME}/${PASSWORD}@//localhost:1521/ORCLPDB1 <<EOF

WHENEVER SQLERROR EXIT SQL.SQLCODE

$SQL

MERGE INTO version_requete v
USING dual
ON (v.id_requete=$ID)

WHEN MATCHED THEN

UPDATE SET

etat='OK',
commentaire='$COMMENT',
date_fin=SYSDATE

WHEN NOT MATCHED THEN

INSERT VALUES(

$ID,
'OK',
'$COMMENT',
SYSDATE,
SYSDATE,
NULL

);

COMMIT;

EXIT

EOF


# si la requete retourne une erreur, enregistrer la requete avec ko dans version_requete


RET=$?

if [ $RET -ne 0 ]
then

echo "[ERREUR] requête $ID"

sqlplus -S \
${USERNAME}/${PASSWORD}@//localhost:1521/ORCLPDB1 <<EOF

MERGE INTO version_requete v
USING dual
ON (v.id_requete=$ID)

WHEN MATCHED THEN
UPDATE SET

etat='KO',
message_erreur='Erreur SQL',
date_fin=SYSDATE

WHEN NOT MATCHED THEN

INSERT VALUES(

$ID,
'KO',
'$COMMENT',
SYSDATE,
SYSDATE,
'Erreur SQL'

);

COMMIT;

EXIT

EOF

exit 1

fi

done < <(./parser.sh "$FILE")
