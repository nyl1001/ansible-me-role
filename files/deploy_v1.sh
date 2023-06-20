# setup
deployDir=$(cd $(dirname $0);pwd)
cd "$deployDir"

chmod +x "$deployDir"/bin/$chainBinName

. "$deployDir"/func.sh
. "$deployDir"/common.sh

sedI="sed -i ''"
sleepTime=6
echo -e "deployDir : $deployDir"
grpcAddr="0.0.0.0:9090"
case $sysType in
    "Linux")
        sedI="sed -i"
        sleepTime=6
        grpcAddr="0.0.0.0:9090"
        ;;
    "Darwin")
        sedI="sed -i ''"
        sleepTime=6
        grpcAddr="0.0.0.0:9089"
        ;;
    *)
        $OUTPUT "system $sysType not supported!"
        exit 1
        ;;
esac

currentOsUserHomeDir=$(cd ~;pwd)
keyringDir=${currentOsUserHomeDir}/.me-chain
keyringBackend=test
with_key_dir_param="--keyring-dir=${keyringDir}"
withKeyringBackendParam="--keyring-backend=${keyringBackend}"
with_key_home_param=""

initMinimumGasPrices=0stake
initMinimumSendFees=0.0002$coinUnit
distMinimumGasPrices=5u$coinUnit
distMinimumSendFees=200u$coinUnit

cleanChainDataDirAndLogs() {
  if [ ! -d "${deployDir}/nodes" ]; then
    mkdir -p ${deployDir}/nodes
  else
    rm -rf  ${deployDir}/nodes/*
  fi
  if [ ! -d "${deployDir}/logs" ]; then
    mkdir -p ${deployDir}/logs
  else
    rm -rf  ${deployDir}/logs/*
  fi
  if [ ! -d "~/.$chainId/" ]; then
    mkdir -p ~/.$chainId/
  else
    rm -rf  ~/.$chainId/*
  fi
}

chainBinDir=${deployDir}/bin

initMasterNode() {
    if [ -d "${deployDir}/nodes/node1" ]; then
        rm -rf  ${deployDir}/nodes/node1
    fi
    cd ${chainBinDir}
    echo "init ${deployDir}/nodes/node1 begin..."
    execShellCommand "./$chainBinName init ${deployDir}/nodes/node1 --chain-id=$chainId --home=${deployDir}/nodes/node1"
    echo "init ${deployDir}/nodes/node1 finish..."
    sleep 1
}

doGenesisOperate() {
    curAdminAmount=0$coinUnit
    if [ -z "$1" ] ;then
        curAdminAmount=0$coinUnit
    else
        curAdminAmount=$1
    fi
    cd ${chainBinDir}
    # Create superadmin
    echo -e "创建管理员账号和运营账号，即0号账号和1号账号"
    execShellCommand "./$chainBinName keys add $adminName $withKeyringBackendParam $with_key_home_param"
    execShellCommand "./$chainBinName keys add operator $withKeyringBackendParam $with_key_home_param"


    # Allocate genesis accounts (cosmos formatted addresses)
    # execShellCommand "./$chainBinName add-genesis-account $(./$chainBinName keys show superadmin -a $withKeyringBackendParam) 4000000000src,16000000000srg --home node1"
    execShellCommand "./$chainBinName add-genesis-account $adminName $curAdminAmount $withKeyringBackendParam --home=${deployDir}/nodes/node1"
    execShellCommand "./$chainBinName add-genesis-account operator 0$coinUnit $withKeyringBackendParam --home=${deployDir}/nodes/node1"
    execShellCommand "./$chainBinName add-genesis-module-account stake_tokens_pool 10000000000$coinUnit --home ${deployDir}/nodes/node1"

    # Sign genesis transaction
    echo -e "Sign genesis transaction"
    execShellCommand "./$chainBinName gentx $adminName 10000000$coinUnit --chain-id $chainId $withKeyringBackendParam --home=${deployDir}/nodes/node1 $with_key_dir_param --moniker=node1"
    #execShellCommand "./$chainBinName gentx $adminName 1000000$coinUnit --chain-id $chainId $withKeyringBackendParam"

    # collect genesis txs
    echo -e "collect genesis txs"
    execShellCommand "./$chainBinName collect-gentxs --home ${deployDir}/nodes/node1"
    sleep 5
}

setupMasterNodeConfig() {
    app_toml="${deployDir}/nodes/node1/config/app.toml"
    # update gas-prices
    $sedI  's#minimum-gas-prices = "'"$initMinimumGasPrices"'"#minimum-gas-prices = "'"$distMinimumGasPrices"'"#g' $app_toml
    $sedI  's#minimum-send-fees = "'"$initMinimumSendFees"'"#minimum-send-fees = "'"$distMinimumSendFees"'"#g' $app_toml


    # [api] Only change the content under the api
    $sedI  's#enable = false#enable = true#g' $app_toml
    $sedI  's#swagger = false#swagger = true#g' $app_toml
    $sedI  's#enabled-unsafe-cors = false#enabled-unsafe-cors = true#g' $app_toml
    # $sedI  's#address = "tcp://0.0.0.0:1317"#address = "tcp://0.0.0.0:10901"#g' $app_toml
    $sedI  's#address = "tcp://0.0.0.0:1317"#address = "tcp://0.0.0.0:1317"#g' $app_toml
    # [grpc]
    # $sedI  's#address = "0.0.0.0:9090"#address = "0.0.0.0:20901"#g' $app_toml
    $sedI  's#address = "0.0.0.0:9090"#address = "'"$grpcAddr"'"#g' $app_toml
    # [grpc-web]
    # $sedI  's#address = "0.0.0.0:9091"#address = "0.0.0.0:30901"#g' $app_toml
    $sedI  's#address = "0.0.0.0:9091"#address = "0.0.0.0:9091"#g' $app_toml

    # [rosetta]
    $sedI  's#address = ":8080"#address = ":8079"#g' $app_toml

    # update client.toml
    client_toml="${deployDir}/nodes/node1/config/client.toml"
    # [node]
    # $sedI  's#node = "tcp://localhost:26657"#node = "tcp://localhost:50901"#g' $client_toml
    $sedI  's#node = "tcp://localhost:26657"#node = "tcp://localhost:26657"#g' $client_toml


    # update config.toml
    config_toml="${deployDir}/nodes/node1/config/config.toml"

    # $sedI  's#proxy_app = "tcp://127.0.0.1:26658"#proxy_app = "tcp://127.0.0.1:40901"#g' $config_toml
    $sedI  's#proxy_app = "tcp://127.0.0.1:26658"#proxy_app = "tcp://127.0.0.1:26658"#g' $config_toml
    # [rpc]
    # $sedI  's#laddr = "tcp://127.0.0.1:26657"#laddr = "tcp://0.0.0.0:50901"#g' $config_toml
    $sedI  's#laddr = "tcp://127.0.0.1:26657"#laddr = "tcp://0.0.0.0:26657"#g' $config_toml
    $sedI  's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/g' $config_toml

    # [p2p]
    # $sedI  's#laddr = "tcp://0.0.0.0:26656"#laddr = "tcp://0.0.0.0:60901"#g' $config_toml
    $sedI  's#laddr = "tcp://0.0.0.0:26656"#laddr = "tcp://0.0.0.0:26656"#g' $config_toml

    echo "deploy: update master node config finish..."
}

setFixedDepositInterestRate() {
    echo "setFixedDepositInterestRate begin..."
    cd "${chainBinDir}"
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_1_MONTHS 0.05 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) $chainId $withKeyringBackendParam -y -s=1"
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_3_MONTHS 0.10 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) $chainId $withKeyringBackendParam -y -s=2"
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_6_MONTHS 0.15 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) $chainId $withKeyringBackendParam -y -s=3"
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_12_MONTHS 0.20 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) $chainId $withKeyringBackendParam -y -s=4"
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_24_MONTHS 0.30 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) $chainId $withKeyringBackendParam -y -s=5"
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_36_MONTHS 0.40 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) $chainId $withKeyringBackendParam -y -s=6"
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_48_MONTHS 0.50 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) $chainId $withKeyringBackendParam -y -s=7"
    echo "setFixedDepositInterestRate finish..."
    sleep 10
    execShellCommand "./$chainBinName q staking show-fixed-deposit-interest-rate"
}

autoGetMasterNodeId=""
startMasterNodeIfStopped(){
    if [ ! -d ${deployDir}/nodes/node1 ]; then
       return
    fi
    if ps aux | grep $chainBinName | grep -v "grep" | grep "${deployDir}/nodes/node1" > /dev/null ; then
        return
    fi
    cd "${chainBinDir}"
    # start main
    nohup ./$chainBinName start --home ${deployDir}/nodes/node1 --grpc.address $grpcAddr 1>${deployDir}/logs/node1.log 2>&1 &
    echo "start master node node1"
#    sleep 10
    autoGetMasterNodeId=$(./$chainBinName tendermint show-node-id --home ${deployDir}/nodes/node1)
    echo "output master node id - $autoGetMasterNodeId"
    setFixedDepositInterestRate
}

restartMasterNode(){
    if ps aux | grep $chainBinName | grep -v "grep" | grep "${deployDir}/nodes/node1" > /dev/null ; then
        ps aux | grep $chainBinName | grep -v "grep" | grep "${deployDir}/nodes/node1" | awk '{print $2}' | xargs kill -9
        sleep 1
    fi
    cd "${chainBinDir}"
    # start main
    nohup ./$chainBinName start --home ${deployDir}/nodes/node1 --grpc.address $grpcAddr 1>${deployDir}/logs/node1.log 2>&1 &
    echo "start master node node1"
#    sleep 10
    autoGetMasterNodeId=$(./$chainBinName tendermint show-node-id --home ${deployDir}/nodes/node1)
    echo "output master node id - $autoGetMasterNodeId"
    setFixedDepositInterestRate
}

setupMasterNodeAndStart() {
    curAdminAmount=0$coinUnit
    if [ -z "$1" ] ;then
        curAdminAmount=0$coinUnit
    else
        curAdminAmount=$1
    fi
    doGenesisOperate "$curAdminAmount"
    setupMasterNodeConfig
    restartMasterNode
}

initAllSlaveNodes() {
    if [ -z "$1" ] ;then
        curHostIndex=0
    else
        curHostIndex=$1
    fi
    curNodeCount=1
    if [ -z "$2" ] ;then
        curNodeCount=1
    else
        curNodeCount=$2
    fi
    if { [ "$curNodeCount" -gt 1 ] && [ "$curHostIndex" -eq 0 ]; } || [ "$curHostIndex" -gt 0 ]; then
        if [ "$curHostIndex" -eq 0 ]; then
            startIndex=2
            endIndex=$curNodeCount
        else
            startIndex=$(expr "$curNodeCount" \* "$curHostIndex" + 1)
            endIndex=$(expr "$startIndex" + "$curNodeCount" - 1)
        fi
        cd ${chainBinDir}
        for i in $(seq "$startIndex" "$endIndex"); do
            if [ -d "${deployDir}/nodes/node$i" ]; then
                rm -rf ${deployDir}/nodes/node$i
            fi
            execShellCommand "./$chainBinName init ${deployDir}/nodes/node$i --chain-id=$chainId --home=${deployDir}/nodes/node$i"
            echo "init ${deployDir}/nodes/node$i finish..."
            sleep 1
            if [ "$curHostIndex" -eq 0 ]; then
                execShellCommand "cp -f ${deployDir}/nodes/node1/config/genesis.json ${deployDir}/nodes/node$i/config/"
            else
                execShellCommand "cp -f ${deployDir}/genesis.json  ${deployDir}/nodes/node$i/config/"
            fi
        done
    fi
}

startSlaveNodesIfStopped() {
    if [ -z "$1" ] ;then
        curHostIndex=0
    else
        curHostIndex=$1
    fi
    curNodeCount=1
    if [ -z "$2" ] ;then
        curNodeCount=1
    else
        curNodeCount=$2
    fi
    if { [ "$curNodeCount" -gt 1 ] && [ "$curHostIndex" -eq 0 ]; } || [ "$curHostIndex" -gt 0 ]; then
        if [ "$curHostIndex" -eq 0 ]; then
            startIndex=2
            endIndex=$curNodeCount
        else
            startIndex=$(expr "$curNodeCount" \* "$curHostIndex" + 1)
            endIndex=$(expr "$startIndex" + "$curNodeCount" - 1)
        fi
        cd ${chainBinDir}
        for i in $(seq "$startIndex" "$endIndex"); do
            if [ ! -d ${deployDir}/nodes/node1 ]; then
                continue
            fi
            if ps aux | grep $chainBinName | grep -v "grep" | grep "${deployDir}/nodes/node$i" > /dev/null ; then
                continue
            fi
            # Start other node. Traveling through the startup node requires dependencies node-id
            nohup ./$chainBinName start --home ${deployDir}/nodes/node"$i" 1>"${deployDir}"/logs/node"$i".log 2>&1 &
            echo "start node$i"
            sleep 5
            last_slave_node_id=$(./$chainBinName tendermint show-node-id --home "${deployDir}"/nodes/node"$i")
            echo "output slave node node$i id - $last_slave_node_id"
        done
    fi
}

restartAllSlaveNodes() {
    curHostIndex=0
    if [ -z "$1" ] ;then
        curHostIndex=0
    else
        curHostIndex=$1
    fi
    curNodeCount=1
    if [ -z "$2" ] ;then
        curNodeCount=1
    else
        curNodeCount=$2
    fi
    if { [ "$curNodeCount" -gt 1 ] && [ "$curHostIndex" -eq 0 ]; } || [ "$curHostIndex" -gt 0 ]; then
        if [ "$curHostIndex" -eq 0 ]; then
            startIndex=2
            endIndex=$curNodeCount
        else
            startIndex=$(expr "$curNodeCount" \* "$curHostIndex" + 1)
            endIndex=$(expr "$startIndex" + "$curNodeCount" - 1)
        fi
        cd ${chainBinDir}
        for i in $(seq "$startIndex" "$endIndex"); do
            if [ ! -d ${deployDir}/nodes/node$i ]; then
                continue
            fi
            if ps aux | grep $chainBinName | grep -v "grep" | grep "${deployDir}/nodes/node$i" > /dev/null ; then
                ps aux | grep $chainBinName | grep -v "grep" | grep "${deployDir}/nodes/node$i" | awk '{print $2}' | xargs kill -9
                sleep 1
            fi
            # Start other node. Traveling through the startup node requires dependencies node-id
            nohup ./$chainBinName start --home ${deployDir}/nodes/node"$i" 1>"${deployDir}"/logs/node"$i".log 2>&1 &
            echo "start node$i"
            sleep 5
            last_slave_node_id=$(./$chainBinName tendermint show-node-id --home "${deployDir}"/nodes/node"$i")
            echo "output slave node node$i id - $last_slave_node_id"
        done
    fi
}

setupAllSlaveNodesAndStart() {
    curHostIndex=0
    if [ -z "$1" ] ;then
        curHostIndex=0
    else
        curHostIndex=$1
    fi
    curNodeCount=1
    if [ -z "$2" ] ;then
        curNodeCount=1
    else
        curNodeCount=$2
    fi
    masterNodeId=
    if [ -z "$3" ] ;then
        masterNodeId=
    else
        masterNodeId=$3
    fi
    masterHostIp=
    if [ -z "$4" ] ;then
        masterHostIp=
    else
        masterHostIp=$4
    fi
    if { [ "$curNodeCount" -gt 1 ] && [ "$curHostIndex" -eq 0 ]; } || [ "$curHostIndex" -gt 0 ]; then
        echo "accept-master-node-id: $masterNodeId"
        echo "accept-master-host-ip: $masterHostIp"
        if [ "$curHostIndex" -eq 0 ]; then
            startIndex=2
            endIndex=$curNodeCount
        else
            startIndex=$(expr "$curNodeCount" \* "$curHostIndex" + 1)
            endIndex=$(expr "$startIndex" + "$curNodeCount" - 1)
        fi
        cd ${chainBinDir}
        for i in $(seq "$startIndex" "$endIndex"); do
            # copy genesis.json
            if [ "$curHostIndex" -eq 0 ]; then
                execShellCommand "cp -f ${deployDir}/nodes/node1/config/genesis.json ${deployDir}/nodes/node$i/config/"
            else
                execShellCommand "cp -f ${deployDir}/genesis.json  ${deployDir}/nodes/node$i/config/"
            fi
            # update app.toml
            app_toml="${deployDir}/nodes/node$i/config/app.toml"

            # update client.toml
            client_toml="${deployDir}/nodes/node$i/config/client.toml"

            # update config.toml
            config_toml="${deployDir}/nodes/node$i/config/config.toml"

            # update gas-prices
            $sedI 's#minimum-gas-prices = "'"$initMinimumGasPrices"'"#minimum-gas-prices = "'"$distMinimumGasPrices"'"#g' $app_toml
            $sedI 's#minimum-send-fees = "'"$initMinimumSendFees"'"#minimum-send-fees = "'"$distMinimumSendFees"'"#g' $app_toml

            # [api] Only change the content under the api
            apiAddrPort=$(expr 1317 + 1 - "$i")
            $sedI 's#enable = false#enable = true#g' $app_toml
            $sedI 's#swagger = false#swagger = true#g' $app_toml
            $sedI 's#enabled-unsafe-cors = false#enabled-unsafe-cors = true#g' $app_toml
            $sedI "s#address = \"tcp://0.0.0.0:1317\"#address = \"tcp://0.0.0.0:$apiAddrPort\"#g" $app_toml
            # [grpc]
            grpcAddrPort=$(expr 9090 + 1 - "$i")
            $sedI "s#address = \"0.0.0.0:9090\"#address = \"0.0.0.0:$grpcAddrPort\"#g" $app_toml
            # [grpc-web]
            grpcWebAddrPort=$(expr 14901 - "$i")
            $sedI "s#address = \"0.0.0.0:9091\"#address = \"0.0.0.0:$grpcWebAddrPort\"#g" $app_toml

            # [rosetta]
            rosettAddrPort=$(expr 8080 - "$i")
            echo -e "slave node start , addrPort : $rosettAddrPort"
            $sedI "s#address = \":8080\"#address = \":${rosettAddrPort}\"#g" $app_toml

            nodeOrRpcAddrPort=$(expr 20901 - "$i")
            # [node]
            $sedI "s#node = \"tcp://localhost:26657\"#node = \"tcp://localhost:$nodeOrRpcAddrPort\"#g" $client_toml

            proxyAddrPort=$(expr 30901 - "$i")
            $sedI "s#proxy_app = \"tcp://127.0.0.1:26658\"#proxy_app = \"tcp://127.0.0.1:$proxyAddrPort\"#g" $config_toml
            # [rpc]
            $sedI "s#laddr = \"tcp://127.0.0.1:26657\"#laddr = \"tcp://0.0.0.0:$nodeOrRpcAddrPort\"#g" $config_toml
            $sedI 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/g' $config_toml
            # pprof listen address (https://golang.org/pkg/net/http/pprof)
            pprofAddrPort=$(expr 50901 - "$i")
            $sedI "s#pprof_laddr = \"localhost:6060\"#pprof_laddr = \"localhost:$pprofAddrPort\"#g" $config_toml

            # [p2p]
            p2pAddrPort=$(expr 26656 + 1 - "$i")
            echo -e "slave node start , p2pAddrPort : $p2pAddrPort"
            $sedI "s#laddr = \"tcp://0.0.0.0:26656\"#laddr = \"tcp://0.0.0.0:$p2pAddrPort\"#g" $config_toml
            # [- p2p port]
            ip1="127.0.0.1"
            ip2=$masterHostIp
            masterNodeIp=$masterHostIp
            lastP2pAddrPort=$(expr "$p2pAddrPort" + 1 )
            if [ "$curHostIndex" -eq 0 ];then
                if [ "$i" -eq $startIndex ]; then
                    $sedI "s#seeds = \"\"#seeds = \"$masterNodeId\@$ip2:26656\"#g" $config_toml
                elif [ "$i" -gt $startIndex ] && [ $(($i % 2)) -eq 0 ]; then
                    $sedI "s#seeds = \"\"#seeds = \"$last_slave_node_id\@$ip2:$lastP2pAddrPort\"#g" $config_toml
                elif [ "$i" -gt $startIndex ] && [ $(($i % 2)) -ne 0 ]; then
                    $sedI "s#seeds = \"\"#seeds = \"$last_slave_node_id\@$ip1:$lastP2pAddrPort\"#g" $config_toml
                fi
            else
                if [ $i -eq $startIndex ]; then
                    $sedI "s#seeds = \"\"#seeds = \"$masterNodeId\@$masterNodeIp:26656\"#g" $config_toml
                elif [ $i -gt $startIndex ] && [ $((i % 2)) -eq 0 ]; then
                    echo "----- The current value of i is $i, the current node is an even node, ip2: $ip2"
                    $sedI "s#seeds = \"\"#seeds = \"$last_slave_node_id\@$ip2:$lastP2pAddrPort\"#g" $config_toml
                elif [ $i -gt $startIndex ] && [ $((i % 2)) -ne 0 ]; then
                    echo "----- The current value of i is $i, the current node is an odd number, ip1: $ip1"
                    $sedI "s#seeds = \"\"#seeds = \"$last_slave_node_id\@$ip1:$lastP2pAddrPort\"#g" $config_toml
                fi
            fi

            # Start other node. Traveling through the startup node requires dependencies node-id
            nohup ./$chainBinName start --home ${deployDir}/nodes/node"$i" 1>"${deployDir}"/logs/node"$i".log 2>&1 &
            echo "start node$i"
            sleep 5

            last_slave_node_id=$(./$chainBinName tendermint show-node-id --home "${deployDir}"/nodes/node"$i")
            echo "output slave node node$i id - $last_slave_node_id"
        done
    fi
}

redeployChain() {
    pkill "$chainBinName"

    curHostIndex=0
    if [ -z "$1" ] ;then
        curHostIndex=0
    else
        curHostIndex=$1
    fi

    curNodeCount=1
    if [ -z "$2" ] ;then
        curNodeCount=1
    else
        curNodeCount=$2
    fi

    curAdminAmount=0$coinUnit
    if [ -z "$3" ] ;then
        curAdminAmount=0$coinUnit
    else
        curAdminAmount=$3
    fi

    cleanChainDataDirAndLogs

    initMasterNode

    # update master node config and start master node
    setupMasterNodeAndStart "$curAdminAmount"

    initAllSlaveNodes "$curHostIndex" "$nodeCount"

    # update all slave nodes config and start them
    setupAllSlaveNodesAndStart "$curHostIndex" "$curNodeCount" "$autoGetMasterNodeId" "$hostIp"
}


restartChain() {
    pkill $chainBinName
    curHostIndex=0
    if [ -z "$1" ] ;then
        curHostIndex=0
    else
        curHostIndex=$1
    fi
    curNodeCount=1
    if [ -z "$2" ] ;then
        curNodeCount=1
    else
        curNodeCount=$2
    fi
    restartMasterNode
    restartAllSlaveNodes "$curHostIndex" "$curNodeCount"
}

showAllStartStatus(){
#  echo -e "ps -ef | grep $chainBinName | grep -v grep"
    ps -ef | grep "$chainBinName" | grep -v grep
}

redeployAll() {
    curHostIndex=0
    if [ -z "$1" ] ;then
        curHostIndex=0
    else
        curHostIndex=$1
    fi
    curNodeCount=1
    if [ -z "$2" ] ;then
        curNodeCount=1
    else
        curNodeCount=$2
    fi
    curAdminAmount=0$coinUnit
    if [ -z "$3" ] ;then
        curAdminAmount=0$coinUnit
    else
        curAdminAmount=$3
    fi
    redeployChain "$curHostIndex" "$curNodeCount" "$curAdminAmount"
    showAllStartStatus
}

restartAll() {
    curHostIndex=0
    if [ -z "$1" ] ;then
        curHostIndex=0
    else
        curHostIndex=$1
    fi
    curNodeCount=1
    if [ -z "$2" ] ;then
        curNodeCount=1
    else
        curNodeCount=$2
    fi
    restartChain "$curHostIndex" "$curNodeCount"
    showAllStartStatus
}

executeType=$1

hostIndex=0
if [ -z "$2" ] ;then
    hostIndex=0
else
    hostIndex=$2
fi

nodeCount=1
if [ -z "$3" ] ;then
    nodeCount=1
else
    nodeCount=$3
fi

case $executeType in
    "redeploy")
        adminAmount=0$coinUnit
        if [ -z "$4" ] ;then
            adminAmount=0$coinUnit
        else
            adminAmount=$4
        fi
        redeployAll "$hostIndex" "$nodeCount" "$adminAmount"
        ;;
    "redeploy-chain")
        adminAmount=0$coinUnit
        if [ -z "$4" ] ;then
            adminAmount=0$coinUnit
        else
            adminAmount=$4
        fi
        redeployChain "$hostIndex" "$nodeCount" "$adminAmount"
        showAllStartStatus
        ;;
    "redeploy-slaves")
        masterNodeId=
        if [ -z "$4" ] ;then
            masterNodeId=
        else
            masterNodeId=$4
        fi
        masterHostIp=
        if [ -z "$5" ] ;then
            masterHostIp=
        else
            masterHostIp=$5
        fi
#        nodeCount=$(($nodeCount+1))
        pkill "$chainBinName"
        cleanChainDataDirAndLogs
        initAllSlaveNodes "$hostIndex" "$nodeCount"
        setupAllSlaveNodesAndStart "$hostIndex" "$nodeCount" "$masterNodeId" "$masterHostIp"
        ;;
    "start-master")
        startMasterNodeIfStopped
        startSlaveNodesIfStopped "$hostIndex" "$nodeCount"
        showAllStartStatus
        ;;
    "start-slaves")
#        nodeCount=$(($nodeCount+1))
        startSlaveNodesIfStopped "$hostIndex" "$nodeCount"
        showAllStartStatus
        ;;
    "restart")
        restartAll "$hostIndex" "$nodeCount"
        ;;
    "restart-chain")
        restartChain "$hostIndex" "$nodeCount"
        showAllStartStatus
        ;;
    "restart-master")
        restartMasterNode
        showAllStartStatus
        ;;
    "restart-slaves")
#        nodeCount=$(($nodeCount+1))
        restartAllSlaveNodes "$hostIndex" "$nodeCount"
        showAllStartStatus
        ;;
    "remove-logs")
        if [ ! -d "${deployDir}/logs" ]; then
            mkdir -p ${deployDir}/logs
        else
            truncate -s 0  ${deployDir}/logs/*.log
        fi
        ;;
    "status")
        showAllStartStatus
        ;;
    *)
        $OUTPUT "
            $BLUE deploy or restart the blockchain $TAILS
            $BLUE$FLICKER Support star lab develop $TAILS

            $YELLOW Chain And Web Deploy Command: $TAILS
            $GREEN ./deploy_v1.sh  redeploy [host index, begin 0] [node count,default 1] [admin account balances,default 0$coinUnit] $TAILS   redeploy both the block chain and the web service, all the chain data and the web data will be lost.
            $GREEN ./deploy_v1.sh  redeploy-chain [host index, begin 0]  [node count,default 1] [admin account balances,default 0$coinUnit] $TAILS   redeploy the block chain, all the chain data will be lost.
            $GREEN ./deploy_v1.sh  redeploy-slaves [host index, begin 0]  [node count,default 1] $TAILS  redeploy the block chain slave nodes, all old slave node data will be lost.
            $GREEN ./deploy_v1.sh  start-master [host index, begin 0] $TAILS  start the master node if stopped
            $GREEN ./deploy_v1.sh  start-slaves [host index, begin 0] [node count,default 1] $TAILS   start all slave nodes if stopped
            $GREEN ./deploy_v1.sh  restart [host index, begin 0] [node count,default 1] $TAILS   restart both master node and slave nodes of the block chain.
            $GREEN ./deploy_v1.sh  restart-chain [host index, begin 0] [node count,default 1] $TAILS   restart both master node and slave nodes of the block chain.
            $GREEN ./deploy_v1.sh  restart-master [host index, begin 0] $TAILS   restart the master node
            $GREEN ./deploy_v1.sh  restart-slaves [host index, begin 0] [node count,default 1] $TAILS   restart all slave nodes
            $GREEN ./deploy_v1.sh  status $TAILS   show the block chain and the web service running status.
            $GREEN ./deploy_v1.sh  remove-logs $TAILS   remove all logs file, release the dick space.
            $GREEN ./deploy_v1.sh  help $TAILS       command list

            "
          exit 1
        ;;
esac