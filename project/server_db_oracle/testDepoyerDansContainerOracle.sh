docker exec -u root -it oracle-ee /bin/bash -c "
cd /workdir/scripts &&
chmod +x deployerBase.sh parser.sh &&
./deployerBase.sh
"
