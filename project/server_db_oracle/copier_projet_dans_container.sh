docker exec -u root -it oracle-ee /bin/bash -c "

if [ -d /workdir/ ]; then
    
   rm -r /workdir/

fi

"

docker cp integrerBase/ oracle-ee:/workdir/
