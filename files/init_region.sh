#!/bin/bash

deployDir=$(cd $(dirname $0);pwd)
cd "$deployDir"
. "$deployDir"/func.sh
. "$deployDir"/common.sh

currentOsUserHomeDir=$(cd ~;pwd)
keyringDir=${currentOsUserHomeDir}/.$chainBinName
keyringBackend=test
with_key_dir_param="--keyring-dir=${keyringDir}"
withKeyringBackendParam="--keyring-backend=${keyringBackend}"
with_key_home_param=""

cd "$deployDir"/bin

adminAddr=$(./"$chainBinName" keys show $adminName -a --keyring-backend=test)

fees_amount="1$coinUnit"

optionsHints="
  $GREEN options: $0 [-t|--type|--execute-type 执行类型]
    [-b|--begin-pos|--start-pos 主机上部署结点索引范围的起始位置] [-e|--end-pos 主机上部署结点索引范围的结束位置] $TAILS"

declare -a POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--type|--execute-type)
      executeType="$2"
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
    -*|--*)
      echo "Unknown option $1"
      $OUTPUT "$optionsHints"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [ -z "$beginPos" ] ;then
    beginPos=0
fi

if [ -z "$endPos" ] ;then
    endPos=0
fi

checkBasicInputArgs(){
    if [ "$endPos" -lt "$beginPos" ]; then
        $OUTPUT "$RED begin-pos 参数值不能大于 end-pos 参数值。 $TAILS"
        exit 0
    fi
    echo "begin node index : $beginPos"
    echo "end node index : $endPos"
}

checkBasicInputArgs

startIndex=$beginPos
endIndex=$endPos

declare -a regionInfoMatrix=(
    USA	834000	667200	83400	33360000
    CHN	3512000	2809600	351200	140480000
    IND	3512000	2809600	351200	140480000
    PAK	586000	468800	58600	23440000
    NGA	544000	435200	54400	21760000
    BRA	530000	424000	53000	21200000
    RUS	364000	291200	36400	14560000
    JPN	310000	248000	31000	12400000
    PHL	276000	220800	27600	11040000
    VNM	248000	198400	24800	9920000
    DEU	210000	168000	21000	8400000
    FRA	170000	136000	17000	6800000
    GBR	166000	132800	16600	6640000
    THA	164000	131200	16400	6560000
    ITA	146000	116800	14600	5840000
    KOR	128000	102400	12800	5120000
    ESP	118000	94400	11800	4720000
    UKR	102000	81600	10200	4080000
    CAN	98000	78400	9800	3920000
    MYS	82000	65600	8200	3280000
    MOZ	80000	64000	8000	3200000
    NPL	72000	57600	7200	2880000
    AUS	66000	52800	6600	2640000
    TWN	58000	46400	5800	2320000
    MLI	56000	44800	5600	2240000
    NLD	44000	35200	4400	1760000
    BEL	3000	2400	300	120000
    SWE	2600	2080	260	104000
    ARE	2400	1920	240	96000
    AUT	2200	1760	220	88000
    HKG	1800	1440	180	72000
    KGZ	1600	1280	160	64000
    SGP	1400	1120	140	56000
    BWA	600	480	60	24000
    MAC	160	128	16	6400
)

startIndex=$beginPos
endIndex=$endPos

sleepTimeCount=10
createRegions(){
    local localRegionInfoList=($1)
    lengthEachRow=5
    totalLen=${#localRegionInfoList[@]}
    length=$(expr $totalLen / $lengthEachRow)
    echo "admin address : $adminAddr"
    echo "region length : $length"
    cd "$deployDir"/bin
    iLoop=0
    for nodeIndex in $(seq "$startIndex" "$endIndex"); do
        matrixRowOffset=$(expr $nodeIndex - 1 )
        curRegionNameIndex=$(expr $lengthEachRow \* $matrixRowOffset )
        local localRegionName=${localRegionInfoList[$curRegionNameIndex]}
        if [[ -v "localRegionInfoList[$curRegionNameIndex]" ]] ; then
            printf "\n"
            echo "###########区域创建开始 $localRegionName ###########"
            echo "current region is : $localRegionName"
        else
            break
        fi

        local localTotalAsIndex=$(expr $curRegionNameIndex + 1 )
        local localTotalAs=${localRegionInfoList[$localTotalAsIndex]}
        local localTotalStakeAllowLimitIndex=$(expr $curRegionNameIndex + 2 )
        local localTotalStakeAllowLimit=${localRegionInfoList[$localTotalStakeAllowLimitIndex]}
        local localUserMaxDelegateASIndex=$(expr $curRegionNameIndex + 3 )
        local localUserMaxDelegateAS=${localRegionInfoList[$localUserMaxDelegateASIndex]}
        local localUserMaxDelegateACIndex=$(expr $curRegionNameIndex + 4)
        local localUserMaxDelegateAC=${localRegionInfoList[$localUserMaxDelegateACIndex]}

        pubKey=$(cat "$deployDir"/validator-pub-keys/node"$nodeIndex".txt)
#        pubKey=$(echo ${pubKey} | sed 's/"@type":/"type": /g')
#        pubKey=$(echo ${pubKey} | sed 's/"key":/"value": /g')
#
#        pubKey=$(echo ${pubKey/\/cosmos.crypto.ed25519.PubKey/tendermint\/PubKeyEd25519})

        lowercaseRegionName=$(echo ${localRegionName} | tr A-Z a-z)
        newRegionId=${lowercaseRegionName}id
        echo "pubkey is : $pubKey"

        admin_amount=$(./me-chaind query bank balances ${adminAddr}| grep ' amount' | awk -F ': ' '{print $2}' | sed 's/^"\(.*\)"$/\1/')
        if [ -z $admin_amount ] || [ $admin_amount -lt 10000000 ]; then
            printf "\n"
            echo -e "管理员账户金额不足，只有 ${admin_amount} u$coinUnit , 给管理员账号转账"
            execShellCommand "./$chainBinName tx bank sendToAdmin 100mec --from=$adminAddr --keyring-backend=test -y"
            sleep $sleepTimeCount
        fi
        operatorAddr=$(./$chainBinName query staking validators | grep "moniker: node$nodeIndex" -B 13 -A 12 | grep 'operator_address' | awk -F ': ' '{print $2}')
        if [ -z $operatorAddr ]; then
            printf "\n"
            echo -e "未找到验证者，创建验证者"
            sleep 2
            # 创建验证者
            execShellCommand "./$chainBinName tx staking create-validator --amount=${localTotalAs}${coinUnit} --pubkey=$pubKey --moniker=node$nodeIndex --commission-rate="0.10" --commission-max-rate="0.20" --commission-max-change-rate="0.01"  --from=$adminAddr --keyring-backend test --chain-id $chainId --fees $fees_amount -y"
            echo -e "\n"

            sleep $sleepTimeCount

            operatorAddr=$(./$chainBinName query staking validators | grep "moniker: node$nodeIndex" -B 13 -A 12 | grep 'operator_address' | awk -F ': ' '{print $2}')
        fi

        existRegionValAddr=$(./$chainBinName q staking list-region | grep "name: $localRegionName" -A 3 -B 1 | grep 'operator_address' | awk -F ': ' '{print $2}')
        if [ -z $existRegionValAddr ]; then
            echo -e "区不存在，需要创建区，绑定验证者"
            execShellCommand "./$chainBinName tx staking new-region $newRegionId $localRegionName $operatorAddr --from=$adminAddr --chain-id=$chainId --fees=$fees_amount --keyring-backend test -y"
            echo -e "\n"
            sleep $(expr $sleepTimeCount + 2)
        else
            echo -e "区存在，判断是否需要重新绑定"
            if [ ! "$existRegionValAddr" = "$operatorAddr" ]; then
                existRegionId=$(./$chainBinName q staking list-region | grep "name: $localRegionName" -A 3 -B 1 | grep 'regionId' | awk -F ': ' '{print $2}')
                echo -e "该区域所绑定的验证者发生变化，需要重新绑定"
                echo -e "删除区域 id : $existRegionId"
                execShellCommand "./$chainBinName tx staking remove-region $existRegionId --from=$adminAddr --chain-id=$chainId --fees=$fees_amount --keyring-backend test -y"
                echo -e "\n"
                sleep $sleepTimeCount

                echo -e "创建新区，并绑定验证者"
                execShellCommand "./$chainBinName tx staking new-region ${lowercaseRegionName}id $localRegionName $operatorAddr --from=$adminAddr --chain-id=$chainId --fees=$fees_amount --keyring-backend test -y"
                echo -e "\n"
                sleep $(expr $sleepTimeCount + 2)
            fi
            echo "region exist"
        fi
        echo "###########区域创建结束 ${localRegionName} ###########"
    done
}

bindRegions(){
    cd "$deployDir"/bin
    for nodeIndex in $(seq "$startIndex" "$endIndex"); do
        operatorAddr=$(./$chainBinName q srstaking list-validator | grep node"$nodeIndex" -A 4 -B 5 | grep 'operator_address' | awk -F ': ' '{print $2}')
    done
}

case $executeType in
    "create")
        createRegions "${regionInfoMatrix[*]}"
        ;;
    "bind")
        bindRegions
        ;;
    "remove")

        ;;
    *)
        $OUTPUT "
            $optionsHints

            $BLUE deploy or restart the blockchain $TAILS
            $BLUE$FLICKER Support star lab develop $TAILS

            $YELLOW Chain And Web Deploy Command: $TAILS
            $GREEN ./init_region.sh -t create [other options...] $TAILS   create the validators and regions.
            $GREEN ./init_region.sh -t remove $TAILS   remove the validators and regions.
            $GREEN ./init_region.sh -t help $TAILS       command list

            "
          exit 1
        ;;
esac