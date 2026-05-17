#!/bin/bash

FILE="../sql/requetes.deploy"
CONFIG="../config/projet.properties"

while IFS='|' read ID SCHEMA COMMENT SQL
do

echo ""
echo "===================================="
echo "[INFO] Requête : $ID"
echo "[INFO] Schema  : $SCHEMA"
echo "[INFO] Comment : $COMMENT"

USERNAME=$(grep "${SCHEMA}.db.username" "$CONFIG" | cut -d= -f2)

PASSWORD=$(grep "${SCHEMA}.db.password" "$CONFIG" | cut -d= -f2)

HOST=$(grep "${SCHEMA}.db.host" "$CONFIG" | cut -d= -f2)

PORT=$(grep "${SCHEMA}.db.port" "$CONFIG" | cut -d= -f2)

SERVICE=$(grep "${SCHEMA}.db.oracle.service" "$CONFIG" | cut -d= -f2)


#############################################
# Vérification table VERSION_REQUETE
#############################################

echo "[INFO] Vérification VERSION_REQUETE"

sqlplus -S \
${USERNAME}/${PASSWORD}@//${HOST}:${PORT}/${SERVICE} <<EOF

SET DEFINE OFF
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

CREATE TABLE VERSION_REQUETE(

ID_REQUETE NUMBER PRIMARY KEY,

ETAT VARCHAR2(5),

COMMENTAIRE VARCHAR2(500),

DATE_EXECUTION DATE,

DATE_FIN DATE,

MESSAGE_ERREUR CLOB

)

';

COMMIT;

END IF;

END;
/

EXIT

EOF


#############################################
# Vérifie si déjà OK
#############################################

ALREADY_DONE=$(sqlplus -S \
${USERNAME}/${PASSWORD}@//${HOST}:${PORT}/${SERVICE} <<EOF

SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF

SELECT COUNT(*)

FROM VERSION_REQUETE

WHERE ID_REQUETE=$ID
AND ETAT='OK';

EXIT

EOF
)

ALREADY_DONE=$(echo "$ALREADY_DONE"|xargs)


if [ "$ALREADY_DONE" = "1" ]
then

echo "[INFO] Requête déjà exécutée"

continue

fi


#############################################
# Exécution SQL
#############################################

echo "[INFO] Exécution ..."

RESULT=$(sqlplus -S \
${USERNAME}/${PASSWORD}@//${HOST}:${PORT}/${SERVICE} <<EOF

SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

$SQL

EXIT

EOF
)

RET=$?


#############################################
# Succès
#############################################

if [ $RET -eq 0 ]
then

echo "[OK] Requête $ID"

sqlplus -S \
${USERNAME}/${PASSWORD}@//${HOST}:${PORT}/${SERVICE} <<EOF

SET DEFINE OFF

BEGIN

MERGE INTO VERSION_REQUETE v

USING dual

ON (v.ID_REQUETE=$ID)

WHEN MATCHED THEN

UPDATE SET

ETAT='OK',
COMMENTAIRE='$COMMENT',
DATE_FIN=SYSDATE,
MESSAGE_ERREUR=NULL

WHEN NOT MATCHED THEN

INSERT(

ID_REQUETE,
ETAT,
COMMENTAIRE,
DATE_EXECUTION,
DATE_FIN,
MESSAGE_ERREUR

)

VALUES(

$ID,
'OK',
'$COMMENT',
SYSDATE,
SYSDATE,
NULL

);

COMMIT;

END;
/

EXIT

EOF


#############################################
# Echec
#############################################

else

echo "[ERREUR] requête $ID"

echo "$RESULT"

ERROR_MSG=$(echo "$RESULT" \
| grep ORA- \
| head -1 \
| sed "s/'/''/g")


sqlplus -S \
${USERNAME}/${PASSWORD}@//${HOST}:${PORT}/${SERVICE} <<EOF

SET DEFINE OFF

BEGIN

MERGE INTO VERSION_REQUETE v

USING dual

ON (v.ID_REQUETE=$ID)

WHEN MATCHED THEN

UPDATE SET

ETAT='KO',

COMMENTAIRE='$COMMENT',

DATE_FIN=SYSDATE,

MESSAGE_ERREUR=q'[$ERROR_MSG]'

WHEN NOT MATCHED THEN

INSERT(

ID_REQUETE,
ETAT,
COMMENTAIRE,
DATE_EXECUTION,
DATE_FIN,
MESSAGE_ERREUR

)

VALUES(

$ID,
'KO',
'$COMMENT',
SYSDATE,
SYSDATE,
q'[$ERROR_MSG]'

);

COMMIT;

END;
/

EXIT

EOF

exit 1

fi

done < <(./parser.sh "$FILE")


echo ""
echo "===================================="
echo "[FIN] Déploiement terminé"
