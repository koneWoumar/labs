#!/bin/bash

FILE=$1

awk '

BEGIN{

id=""
schema=""
commentaire=""
sql=""

}

/^<.*id=/{

if(id!=""){

gsub(/\n/,"§",sql)

print id "|" schema "|" commentaire "|" sql

}

match($0,/id="([^"]+)"/,a)
id=a[1]

match($0,/schema="([^"]+)"/,a)
schema=a[1]

match($0,/commentaire="([^"]+)"/,a)
commentaire=a[1]

sql=""

next

}

{

sql=sql "\n" $0

}

END{

gsub(/\n/,"§",sql)

print id "|" schema "|" commentaire "|" sql

}

' "$FILE"
