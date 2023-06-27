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
keyringDir=${currentOsUserHomeDir}/.${commonKeyringDir}
keyringBackend=$commonKeyringBackend
with_key_dir_param="--keyring-dir=${keyringDir}"
withKeyringBackendParam="--keyring-backend=${keyringBackend}"
with_key_home_param=""

initMinimumGasPrices=$initMinimumGasPrices
initMinimumSendFees=${initMinimumSendFees}$coinUnit
distMinimumGasPrices=${finalMinimumGasPrices}u$coinUnit
distMinimumSendFees=${finalMinimumSendFees}u$coinUnit

cleanChainDataDirAndLogs() {
  if [ ! -d "${deployDir}/nodes" ]; then
    mkdir -p ${deployDir}/nodes
  else
    rm -rf ${deployDir}/nodes/*
  fi
  if [ ! -d "${deployDir}/logs" ]; then
    mkdir -p ${deployDir}/logs
  else
    rm -rf ${deployDir}/logs/*
  fi
  if [ ! -d "$keyringDir" ]; then
    mkdir -p $keyringDir
  else
    rm -rf $keyringDir/*
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
    execShellCommand "./$chainBinName add-genesis-account $(./"$chainBinName" keys show $adminName -a $withKeyringBackendParam $with_key_home_param) $curAdminAmount $withKeyringBackendParam --home=${deployDir}/nodes/node1"
    execShellCommand "./$chainBinName add-genesis-account $(./"$chainBinName" keys show operator -a $withKeyringBackendParam $with_key_home_param) 0$coinUnit $withKeyringBackendParam --home=${deployDir}/nodes/node1"
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
#    $sedI  's#minimum-gas-prices = "'"$initMinimumGasPrices"'"#minimum-gas-prices = "'"$distMinimumGasPrices"'"#g' $app_toml
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
    local curSleepTime=10
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_1_MONTHS 0.05 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) --chain-id=$chainId $withKeyringBackendParam -y"
    sleep $curSleepTime
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_3_MONTHS 0.10 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) --chain-id=$chainId $withKeyringBackendParam -y"
    sleep $curSleepTime
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_6_MONTHS 0.15 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) --chain-id=$chainId $withKeyringBackendParam -y"
    sleep $curSleepTime
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_12_MONTHS 0.20 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) --chain-id=$chainId $withKeyringBackendParam -y"
    sleep $curSleepTime
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_24_MONTHS 0.30 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) --chain-id=$chainId $withKeyringBackendParam -y"
    sleep $curSleepTime
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_36_MONTHS 0.40 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) --chain-id=$chainId $withKeyringBackendParam -y"
    sleep $curSleepTime
    execShellCommand "./$chainBinName tx staking set-fixed-deposit-interest-rate TERM_48_MONTHS 0.50 --from=$(./$chainBinName keys show $adminName -a $withKeyringBackendParam) --chain-id=$chainId $withKeyringBackendParam -y"
    sleep $curSleepTime
    echo "setFixedDepositInterestRate finish..."
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
}

setupMasterNodeAndStart() {
    local curAdminAmount=0$coinUnit
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
    local curBeginIndex=$1
    local curEndIndex=$2
    realBeginIndex=$curBeginIndex
    if [ "$curBeginIndex" -eq 1 ]; then
        curBeginIndex=2
    fi
    cd ${chainBinDir}
    for i in $(seq "$curBeginIndex" "$curEndIndex"); do
        if [ -d "${deployDir}/nodes/node$i" ]; then
            rm -rf ${deployDir}/nodes/node$i
            rm -rf ${deployDir}/logs/node$i.log
        fi
        execShellCommand "./$chainBinName init ${deployDir}/nodes/node$i --chain-id=$chainId --home=${deployDir}/nodes/node$i"
        echo "init ${deployDir}/nodes/node$i finish..."
        sleep 1
        if [ "$realBeginIndex" -eq 1 ]; then
            execShellCommand "cp -f ${deployDir}/nodes/node1/config/genesis.json ${deployDir}/nodes/node$i/config/"
        else
            execShellCommand "cp -f ${deployDir}/genesis.json  ${deployDir}/nodes/node$i/config/"
        fi
    done
}

startSlaveNodesIfStopped() {
    local curBeginIndex=$1
    local curEndIndex=$2
    if [ "$curBeginIndex" -eq 1 ]; then
        curBeginIndex=2
    fi
    cd ${chainBinDir}
    for i in $(seq "$curBeginIndex" "$curEndIndex"); do
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
}

restartAllSlaveNodes() {
    local curBeginIndex=$1
    local curEndIndex=$2
    if [ "$curBeginIndex" -eq 1 ]; then
        curBeginIndex=2
    fi
    cd ${chainBinDir}
    for i in $(seq "$curBeginIndex" "$curEndIndex"); do
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
}

setupAllSlaveNodesAndStart() {
    local curBeginIndex=1
    if [ -z "$1" ] ;then
        curBeginIndex=1
    else
        curBeginIndex=$1
    fi
    local curEndIndex=1
    if [ -z "$2" ] ;then
        curEndIndex=1
    else
        curEndIndex=$2
    fi
    local masterNodeId=
    if [ -z "$3" ] ;then
        masterNodeId=
    else
        masterNodeId=$3
    fi
    local masterHostIp=
    if [ -z "$4" ] ;then
        masterHostIp=
    else
        masterHostIp=$4
    fi

    local lPreNodeIndex=$5

    echo "accept-master-node-id: $masterNodeId"
    echo "accept-master-host-ip: $masterHostIp"
    local realBeginIndex=$curBeginIndex
    if [ "$curBeginIndex" -eq 1 ]; then
        curBeginIndex=2
    fi
    cd ${chainBinDir}
    for i in $(seq "$curBeginIndex" "$curEndIndex"); do
        # copy genesis.json
        if [ "$realBeginIndex" -eq 1 ]; then
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
#        $sedI 's#minimum-gas-prices = "'"$initMinimumGasPrices"'"#minimum-gas-prices = "'"$distMinimumGasPrices"'"#g' $app_toml
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
        if [ "$realBeginIndex" -eq 1 ];then
            if [ "$i" -eq $curBeginIndex ]; then
                $sedI "s#seeds = \"\"#seeds = \"$masterNodeId\@$ip2:26656\"#g" $config_toml
            elif [ "$i" -gt $curBeginIndex ] && [ $(($i % 2)) -eq 0 ]; then
                $sedI "s#seeds = \"\"#seeds = \"$last_slave_node_id\@$ip2:$lastP2pAddrPort\"#g" $config_toml
            elif [ "$i" -gt $curBeginIndex ] && [ $(($i % 2)) -ne 0 ]; then
                $sedI "s#seeds = \"\"#seeds = \"$last_slave_node_id\@$ip1:$lastP2pAddrPort\"#g" $config_toml
            fi
        else
            if [ $i -eq $curBeginIndex ]; then
                if [ "$lPreNodeIndex" -eq 0 ]; then
                    lastIndex=$(expr "$i" - 1)
                else
                    lastIndex=$lPreNodeIndex
                fi
                if ps aux | grep $chainBinName | grep -v "grep" | grep "${deployDir}/nodes/node$lastIndex" > /dev/null ; then
                    echo "本机器已经部署有前序结点，前序结点索引为  $lastIndex"
                    last_slave_node_id=$(./$chainBinName tendermint show-node-id --home "${deployDir}"/nodes/node"$lastIndex")
                    if [ $((i % 2)) -eq 0 ]; then
                        echo "----- The current value of i is $i, the current node is an even node, ip2: $ip2"
                        $sedI "s#seeds = \"\"#seeds = \"$last_slave_node_id\@$ip2:$lastP2pAddrPort\"#g" $config_toml
                    else
                        echo "----- The current value of i is $i, the current node is an odd number, ip1: $ip1"
                        $sedI "s#seeds = \"\"#seeds = \"$last_slave_node_id\@$ip1:$lastP2pAddrPort\"#g" $config_toml
                    fi
                else
                    echo "本机器尚未部署前序结点，前序结点索引为  $lastIndex"
                    $sedI "s#seeds = \"\"#seeds = \"$masterNodeId\@$masterNodeIp:26656\"#g" $config_toml
                fi
            elif [ $i -gt $curBeginIndex ] && [ $((i % 2)) -eq 0 ]; then
                echo "----- The current value of i is $i, the current node is an even node, ip2: $ip2"
                $sedI "s#seeds = \"\"#seeds = \"$last_slave_node_id\@$ip2:$lastP2pAddrPort\"#g" $config_toml
            elif [ $i -gt $curBeginIndex ] && [ $((i % 2)) -ne 0 ]; then
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
}

restoreAllNodesMinimumGasPrice(){
    local curBeginIndex=1
    if [ -z "$1" ] ;then
        curBeginIndex=1
    else
        curBeginIndex=$1
    fi
    local curEndIndex=1
    if [ -z "$2" ] ;then
        curEndIndex=1
    else
        curEndIndex=$2
    fi
    cd ${chainBinDir}
    for i in $(seq "$curBeginIndex" "$curEndIndex"); do
        # update app.toml
        app_toml="${deployDir}/nodes/node$i/config/app.toml"
        # update gas-prices
        $sedI 's#minimum-gas-prices = "'"$distMinimumGasPrices"'"#minimum-gas-prices = "'"$initMinimumGasPrices"'"#g' $app_toml
    done
}

setAllNodesMinimumGasPrice(){
    local curBeginIndex=1
    if [ -z "$1" ] ;then
        curBeginIndex=1
    else
        curBeginIndex=$1
    fi
    local curEndIndex=1
    if [ -z "$2" ] ;then
        curEndIndex=1
    else
        curEndIndex=$2
    fi
    cd ${chainBinDir}
    for i in $(seq "$curBeginIndex" "$curEndIndex"); do
        # update app.toml
        app_toml="${deployDir}/nodes/node$i/config/app.toml"
        # update gas-prices
        $sedI 's#minimum-gas-prices = "'"$initMinimumGasPrices"'"#minimum-gas-prices = "'"$distMinimumGasPrices"'"#g' $app_toml
    done
}

redeployChain() {
    pkill "$chainBinName"

    local curBeginIndex=1
    if [ -z "$1" ] ;then
        curBeginIndex=1
    else
        curBeginIndex=$1
    fi

    local curEndIndex=1
    if [ -z "$2" ] ;then
        curEndIndex=1
    else
        curEndIndex=$2
    fi

    local curAdminAmount=0$coinUnit
    if [ -z "$3" ] ;then
        curAdminAmount=0$coinUnit
    else
        curAdminAmount=$3
    fi

    cleanChainDataDirAndLogs

    initMasterNode

    # update master node config and start master node
    setupMasterNodeAndStart "$curAdminAmount"

    initAllSlaveNodes "$curBeginIndex" "$curEndIndex"

    # update all slave nodes config and start them
    setupAllSlaveNodesAndStart "$curBeginIndex" "$curEndIndex" "$autoGetMasterNodeId" "$hostIp" 0
}

restartChain() {
    pkill $chainBinName
    local curBeginIndex=1
    if [ -z "$1" ] ;then
        curBeginIndex=1
    else
        curBeginIndex=$1
    fi
    local curEndIndex=1
    if [ -z "$2" ] ;then
        curEndIndex=1
    else
        curEndIndex=$2
    fi
    restartMasterNode
    restartAllSlaveNodes "$curBeginIndex" "$curEndIndex"
}

showAllStartStatus(){
#  echo -e "ps -ef | grep $chainBinName | grep -v grep"
    ps -ef | grep "$chainBinName" | grep -v grep
}

redeployAll() {
    local curBeginIndex=1
    if [ -z "$1" ] ;then
        curBeginIndex=1
    else
        curBeginIndex=$1
    fi
    local curEndIndex=1
    if [ -z "$2" ] ;then
        curEndIndex=1
    else
        curEndIndex=$2
    fi
    local curAdminAmount=0$coinUnit
    if [ -z "$3" ] ;then
        curAdminAmount=0$coinUnit
    else
        curAdminAmount=$3
    fi
    redeployChain "$curBeginIndex" "$curEndIndex" "$curAdminAmount"
    showAllStartStatus
}

restartAll() {
    local curBeginIndex=$1
    local curEndIndex=$2
    restartChain "$curBeginIndex" "$curEndIndex"
    showAllStartStatus
}

optionsHints="
  $GREEN options: $0 [-t|--type|--execute-type 执行类型] [-i|--index|--host-index 主机索引] [-c|--node-count 每台主机部署的结点数]
    [-b|--begin-pos|--start-pos 主机上部署结点索引范围的起始位置] [-e|--end-pos 主机上部署结点索引范围的结束位置]
    [-I|-ip|--master-node-ip 主节点所在主机的ip，推荐使用内网ip，部署从节点时需要] [-d|-id|--master-node-id 主节点id，部署从节点时需要]
    [-h|-help|--help help information] $TAILS"

commandHelpHints="
     $BLUE deploy or restart the blockchain $TAILS
     $BLUE$FLICKER Support star lab develop $TAILS

         $optionsHints

     $YELLOW Chain And Web Deploy Command: $TAILS
     $GREEN ./deploy.sh -t redeploy [options...] $TAILS   redeploy both the block chain and the web service, all the chain data and the web data will be lost.
     $GREEN ./deploy.sh -t redeploy-chain [options...] $TAILS   redeploy the block chain, all the chain data will be lost.
     $GREEN ./deploy.sh -t redeploy-slaves [options...] $TAILS  redeploy the block chain slave nodes, all old slave node data will be lost.
     $GREEN ./deploy.sh -t start-master [host index, begin 0] $TAILS  start the master node if stopped
     $GREEN ./deploy.sh -t start-slaves [options...] $TAILS   start all slave nodes if stopped
     $GREEN ./deploy.sh -t restart [options...] $TAILS   restart both the master node and all the slave nodes in the master host.
     $GREEN ./deploy.sh -t restart-chain [options...] $TAILS   restart both master node and slave nodes of the block chain.
     $GREEN ./deploy.sh -t restart-master [options...] $TAILS   restart both the master node and all the slave nodes in the master host.
     $GREEN ./deploy.sh -t restart-slaves [options...] $TAILS   restart all slave nodes
     $GREEN ./deploy.sh -t restore-master-gas-prices [options...] $TAILS   restore the minimum gas prices in both the master node and all the slave nodes for the master host.
     $GREEN ./deploy.sh -t set-master-gas-prices [options...] $TAILS   set the minimum gas prices in both the master node and all the slave nodes for the master host.
     $GREEN ./deploy.sh -t restore-slaves-gas-prices [options...] $TAILS   restore the minimum gas prices in all the slave nodes for the slave host.
     $GREEN ./deploy.sh -t set-slaves-gas-prices [options...] $TAILS   set the minimum gas prices in all the slave nodes for the slave host.
     $GREEN ./deploy.sh -t remove-logs $TAILS   remove all logs file, release the dick space.
     $GREEN ./deploy.sh -t set-fixed-deposit-rates $TAILS set fixed deposit rates.
     $GREEN ./deploy.sh -t status $TAILS   show the block chain and the web service running status.
     $GREEN ./deploy.sh -t help $TAILS       command list

     "

declare -a POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--type|--execute-type)
      executeType="$2"
      shift # past argument
      shift # past value
      ;;
    -i|--index|--host-index)
      hostIndex="$2"
      shift # past argument
      shift # past value
      ;;
    -c|--node-count)
      nodeCount="$2"
      shift # past argument
      shift # past value
      ;;
    -b|--begin-pos|--start-pos)
      beginPos="$2"
      shift # past argument
      shift # past value
      ;;
    -e|--end-pos)
      endPos="$2"
      shift # past argument
      shift # past value
      ;;
    -a|--amount|--admin-amount)
      adminAmount="$2"
      shift # past argument
      shift # past value
      ;;
    -I|-ip|--master-node-ip)
      masterHostIp="$2"
      shift # past argument
      shift # past value
      ;;
    -d|--id|--master-node-id)
      masterNodeId="$2"
      shift # past argument
      shift # past value
      ;;
    -p|--pre-node-index)
      preNodeIndex="$2"
      shift # past argument
      shift # past value
      ;;
    -h|-help|--help)
      $OUTPUT "$commandHelpHints"
      exit 1
      ;;
    --default)
      echo "Unknown option $1"
      $OUTPUT "$commandHelpHints"
      exit 1
      ;;
    -*|--*)
      echo "Unknown option $1"
      $OUTPUT "$commandHelpHints"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [ -z "$hostIndex" ] ;then
    hostIndex=-1
fi

if [ -z "$nodeCount" ] ;then
    nodeCount=0
fi

if [ -z "$beginPos" ] ;then
    beginPos=0
fi

if [ -z "$endPos" ] ;then
    endPos=0
fi

if [ -z "$adminAmount" ] ;then
    adminAmount=0$coinUnit
fi

if [ -z "$masterHostIp" ] ;then
    masterHostIp=$hostIp
fi

if [ -z "$masterNodeId" ] ;then
    masterNodeId=
fi

if [ -z "$preNodeIndex" ] ;then
    preNodeIndex=0
fi

globalStartIndex=0
globalEndIndex=0
if [ "$hostIndex" -gt -1 ] && [ "$nodeCount" -gt 0 ]; then
    if [ "$hostIndex" -eq 0 ]; then
        globalStartIndex=1
        globalEndIndex=$nodeCount
    else
        globalStartIndex=$(expr "$nodeCount" \* "$hostIndex" + 1)
        globalEndIndex=$(expr "$globalStartIndex" + "$nodeCount" - 1)
    fi
fi

if [ "$beginPos" -gt 0 ]; then
    globalStartIndex=$beginPos
    globalEndIndex=$endPos
fi

checkBasicInputArgs(){
    if [ "$endPos" -lt "$beginPos" ]; then
        $OUTPUT "$RED begin-pos 参数值不能大于 end-pos 参数值。 $TAILS"
        exit 0
    fi
    if [ "$globalStartIndex" -eq 0 ] && [ "$globalEndIndex" -eq 0 ]; then
        $OUTPUT "$RED 你应该指定有效的--host-index、 --node-count值，或者指定有效的 --begin-pos、--end-pos值。 $TAILS"
        exit 0
    fi
    echo "begin node index : $globalStartIndex"
    echo "end node index : $globalEndIndex"
}

case $executeType in
    "redeploy")
        checkBasicInputArgs
        redeployAll "$globalStartIndex" "$globalEndIndex" "$adminAmount"
        ;;
    "redeploy-chain")
        checkBasicInputArgs
        redeployChain "$globalStartIndex" "$globalEndIndex" "$adminAmount"
        showAllStartStatus
        ;;
    "redeploy-slaves")
        checkBasicInputArgs
        if [ -z "$masterNodeId" ] ;then
            $OUTPUT "$RED 部署从主机上的从节点时，需要指定master node id。 $TAILS"
            exit 0
        fi
        if [ -z "$masterHostIp" ] ;then
            $OUTPUT "$RED 部署从主机上的从节点时，需要指定master host ip。 $TAILS"
            exit 0
        fi
#        nodeCount=$(($nodeCount+1))
        initAllSlaveNodes "$globalStartIndex" "$globalEndIndex"
        setupAllSlaveNodesAndStart "$globalStartIndex" "$globalEndIndex" "$masterNodeId" "$masterHostIp" "$preNodeIndex"
        ;;
    "start-master")
        checkBasicInputArgs
        startMasterNodeIfStopped
        startSlaveNodesIfStopped "$globalStartIndex" "$globalEndIndex"
        showAllStartStatus
        ;;
    "start-slaves")
#        nodeCount=$(($nodeCount+1))
        checkBasicInputArgs
        startSlaveNodesIfStopped "$globalStartIndex" "$globalEndIndex"
        showAllStartStatus
        ;;
    "restart")
        checkBasicInputArgs
        restartAll "$globalStartIndex" "$globalEndIndex"
        ;;
    "restart-chain")
        checkBasicInputArgs
        restartChain "$globalStartIndex" "$globalEndIndex"
        showAllStartStatus
        ;;
    "restart-master")
        checkBasicInputArgs
        restartAll "$globalStartIndex" "$globalEndIndex"
        ;;
    "restart-slaves")
#        nodeCount=$(($nodeCount+1))
        checkBasicInputArgs
        restartAllSlaveNodes "$globalStartIndex" "$globalEndIndex"
        showAllStartStatus
        ;;
    "restore-master-gas-prices")
        checkBasicInputArgs
        restoreAllNodesMinimumGasPrice "$globalStartIndex" "$globalEndIndex"
        restartChain "$globalStartIndex" "$globalEndIndex"
        showAllStartStatus
        ;;
    "set-master-gas-prices")
        checkBasicInputArgs
        setAllNodesMinimumGasPrice "$globalStartIndex" "$globalEndIndex"
        restartChain "$globalStartIndex" "$globalEndIndex"
        showAllStartStatus
        ;;
    "restore-slaves-gas-prices")
        checkBasicInputArgs
        restoreAllNodesMinimumGasPrice "$globalStartIndex" "$globalEndIndex"
        restartAllSlaveNodes "$globalStartIndex" "$globalEndIndex"
        showAllStartStatus
        ;;
    "set-slaves-gas-prices")
        checkBasicInputArgs
        setAllNodesMinimumGasPrice "$globalStartIndex" "$globalEndIndex"
        restartAllSlaveNodes "$globalStartIndex" "$globalEndIndex"
        showAllStartStatus
        ;;
    "remove-logs")
        if [ ! -d "${deployDir}/logs" ]; then
            mkdir -p ${deployDir}/logs
        else
            truncate -s 0  ${deployDir}/logs/*.log
        fi
        ;;
    "set-fixed-deposit-rates")
        setFixedDepositInterestRate
        ;;
    "status")
        showAllStartStatus
        ;;
    *)
        $OUTPUT "$commandHelpHints"
        exit 1
        ;;
esac