deployDir=$(cd $(dirname $0);pwd)
cd "$deployDir"
. "$deployDir"/func.sh
. "$deployDir"/common.sh

hostIndex=0
if [ -z "$1" ] ;then
    hostIndex=0
else
    hostIndex=$1
fi

nodeCount=1
if [ -z "$2" ] ;then
    nodeCount=1
else
    nodeCount=$2
fi

if [ "$hostIndex" -eq 0 ]; then
    startIndex=1
    endIndex=$nodeCount
else
    startIndex=$(expr "$nodeCount" \* "$hostIndex" + 1)
    endIndex=$(expr "$startIndex" + "$nodeCount" - 1)
fi

cd "$deployDir"/bin
mkdir -p /tmp/validator-pub-keys
rm -rf /tmp/validator-pub-keys/*
for i in $(seq "$startIndex" "$endIndex"); do
    ./$chainBinName tendermint show-validator --home $deployDir/nodes/node$i > /tmp/validator-pub-keys/node$i.txt
done
