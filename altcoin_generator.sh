# change the following variables to match your new coin
COIN_NAME="IAmCoin"
COIN_UNIT="IAM"
# 42 million coins at total (litecoin total supply is 84000000)
TOTAL_SUPPLY=74000000
MAINNET_PORT="9123"
TESTNET_PORT="19123"
PHRASE="17/May/2021 Report on government knowledge of UFOs to be turned over to Senate June 1"
# First letter of the wallet address. Check https://en.bitcoin.it/wiki/Base58Check_encoding
PUBKEY_CHAR="78"
# number of blocks to wait to be able to spend coinbase UTXO's
COINBASE_MATURITY=3
# leave CHAIN empty for main network, -regtest for regression network and -testnet for test network
CHAIN=""
# this is the amount of coins to get as a reward of mining the block of height 1. if not set this will default to 50
PREMINED_AMOUNT=10000

# warning: change this to your own pubkey to get the genesis block mining reward
GENESIS_REWARD_PUBKEY=04eb187d0b5edf565cc14b0bc3e753249e82ad2b9aba4a35baeb593a34bb0e0a8dd28e5824764d17be07167eeb768a74d098b18d4b3c7a13612b1d5770773b916e

# dont change the following variables unless you know what you are doing
LITECOIN_BRANCH=0.16
GENESISHZERO_REPOS=https://github.com/lhartikk/GenesisH0
LITECOIN_REPOS=https://github.com/litecoin-project/litecoin.git
LITECOIN_PUB_KEY=040184710fa689ad5023690c80f3a49c8f13f8d45b8c857fbcbc8bc4a8e4d3eb4b10f4d4604fa08dce601aaf0f470216fe1b51850b4acf21b179c45070ac7b03a9
LITECOIN_MERKLE_HASH=97ddfbbae6be97fd6cdf3e7ca13232a3afff2353e29badfab7f73011edd4ced9
LITECOIN_MAIN_GENESIS_HASH=12a765e31ffd4059bada1e25190f6e98c99d9714d334efa41a195a7e7e04bfe2
LITECOIN_TEST_GENESIS_HASH=4966625a4b2851d9fdee139e56211a0d88575f59ed816ff5e6a63deb4e3e29a0
LITECOIN_REGTEST_GENESIS_HASH=530827f38f93b43ed12af0b3ad25a288dc02ed74d6d7857862df51fc56c416f9
MINIMUM_CHAIN_WORK_MAIN=0x0000000000000000000000000000000000000000000000c1bfe2bbe614f41260
MINIMUM_CHAIN_WORK_TEST=0x000000000000000000000000000000000000000000000000001df7b5aa1700ce
COIN_NAME_LOWER=$(echo $COIN_NAME | tr '[:upper:]' '[:lower:]')
COIN_NAME_UPPER=$(echo $COIN_NAME | tr '[:lower:]' '[:upper:]')
COIN_UNIT_LOWER=$(echo $COIN_UNIT | tr '[:upper:]' '[:lower:]')
DIRNAME=$(dirname $0)
DOCKER_NETWORK="172.18.0"
DOCKER_IMAGE_LABEL="newcoin-env"
OSVERSION="$(uname -s)"

docker_build_image()
{
    IMAGE=$(docker images -q $DOCKER_IMAGE_LABEL)
    if [ -z $IMAGE ]; then
        echo Building docker image
        if [ ! -f $DOCKER_IMAGE_LABEL/Dockerfile ]; then
            mkdir -p $DOCKER_IMAGE_LABEL
            cat <<EOF > $DOCKER_IMAGE_LABEL/Dockerfile
FROM ubuntu:16.04
RUN echo deb http://ppa.launchpad.net/bitcoin/bitcoin/ubuntu xenial main >> /etc/apt/sources.list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv D46F45428842CE5E
RUN apt-get update
RUN apt-get -y install ccache git libboost-system1.58.0 libboost-filesystem1.58.0 libboost-program-options1.58.0 libboost-thread1.58.0 libboost-chrono1.58.0 libssl1.0.0 libevent-pthreads-2.0-5 libevent-2.0-5 build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev libdb4.8-dev libdb4.8++-dev libminiupnpc-dev libzmq3-dev libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler libqrencode-dev python-pip
RUN pip install construct==2.5.2 scrypt
EOF
        fi 
        docker build --label $DOCKER_IMAGE_LABEL --tag $DOCKER_IMAGE_LABEL $DIRNAME/$DOCKER_IMAGE_LABEL/
    else
        echo Docker image already built
    fi
}

docker_run_genesis()
{
    mkdir -p $DIRNAME/.ccache
    docker run -v $DIRNAME/GenesisH0:/GenesisH0 $DOCKER_IMAGE_LABEL /bin/bash -c "$1"
}

docker_run()
{
    mkdir -p $DIRNAME/.ccache
    docker run -v $DIRNAME/GenesisH0:/GenesisH0 -v $DIRNAME/.ccache:/root/.ccache -v $DIRNAME/$COIN_NAME_LOWER:/$COIN_NAME_LOWER $DOCKER_IMAGE_LABEL /bin/bash -c "$1"
}

docker_stop_nodes()
{
    echo "Stopping all docker nodes"
    for id in $(docker ps -q -a  -f ancestor=$DOCKER_IMAGE_LABEL); do
        docker stop $id
    done
}

docker_remove_nodes()
{
    echo "Removing all docker nodes"
    for id in $(docker ps -q -a  -f ancestor=$DOCKER_IMAGE_LABEL); do
        docker rm $id
    done
}

docker_create_network()
{
    echo "Creating docker network"
    if ! docker network inspect newcoin &>/dev/null; then
        docker network create --subnet=$DOCKER_NETWORK.0/16 newcoin
    fi
}

docker_remove_network()
{
    echo "Removing docker network"
    docker network rm newcoin
}

docker_run_node()
{
    local NODE_NUMBER=$1
    local NODE_COMMAND=$2
    mkdir -p $DIRNAME/miner${NODE_NUMBER}
    if [ ! -f $DIRNAME/miner${NODE_NUMBER}/$COIN_NAME_LOWER.conf ]; then
        cat <<EOF > $DIRNAME/miner${NODE_NUMBER}/$COIN_NAME_LOWER.conf
rpcuser=${COIN_NAME_LOWER}rpc
rpcpassword=$(cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 32; echo)
EOF
    fi

    docker run --net newcoin --ip $DOCKER_NETWORK.${NODE_NUMBER} -v $DIRNAME/miner${NODE_NUMBER}:/root/.$COIN_NAME_LOWER -v $DIRNAME/$COIN_NAME_LOWER:/$COIN_NAME_LOWER $DOCKER_IMAGE_LABEL /bin/bash -c "$NODE_COMMAND"
}

generate_genesis_block()
{
    if [ ! -d GenesisH0 ]; then
        git clone $GENESISHZERO_REPOS
        pushd GenesisH0
    else
        pushd GenesisH0
        git pull
    fi

    if [ ! -f ${COIN_NAME}-main.txt ]; then
        echo "Mining genesis block... this procedure can take many hours of cpu work.."
        docker_run_genesis "python /GenesisH0/genesis.py -a scrypt -z \"$PHRASE\" -p $GENESIS_REWARD_PUBKEY 2>&1 | tee /GenesisH0/${COIN_NAME}-main.txt"
    else
        echo "Genesis block already mined.."
        cat ${COIN_NAME}-main.txt
    fi

    if [ ! -f ${COIN_NAME}-test.txt ]; then
        echo "Mining genesis block of test network... this procedure can take many hours of cpu work.."
        docker_run_genesis "python /GenesisH0/genesis.py  -t 1486949366 -a scrypt -z \"$PHRASE\" -p $GENESIS_REWARD_PUBKEY 2>&1 | tee /GenesisH0/${COIN_NAME}-test.txt"
    else
        echo "Genesis block already mined.."
        cat ${COIN_NAME}-test.txt
    fi

    if [ ! -f ${COIN_NAME}-regtest.txt ]; then
        echo "Mining genesis block of regtest network... this procedure can take many hours of cpu work.."
        docker_run_genesis "python /GenesisH0/genesis.py -t 1296688602 -b 0x207fffff -n 0 -a scrypt -z \"$PHRASE\" -p $GENESIS_REWARD_PUBKEY 2>&1 | tee /GenesisH0/${COIN_NAME}-regtest.txt"
    else
        echo "Genesis block already mined.."
        cat ${COIN_NAME}-regtest.txt
    fi

    MAIN_PUB_KEY=$(cat ${COIN_NAME}-main.txt | grep "^pubkey:" | $SED 's/^pubkey: //')
    MERKLE_HASH=$(cat ${COIN_NAME}-main.txt | grep "^merkle hash:" | $SED 's/^merkle hash: //')
    TIMESTAMP=$(cat ${COIN_NAME}-main.txt | grep "^time:" | $SED 's/^time: //')
    BITS=$(cat ${COIN_NAME}-main.txt | grep "^bits:" | $SED 's/^bits: //')

    MAIN_NONCE=$(cat ${COIN_NAME}-main.txt | grep "^nonce:" | $SED 's/^nonce: //')
    TEST_NONCE=$(cat ${COIN_NAME}-test.txt | grep "^nonce:" | $SED 's/^nonce: //')
    REGTEST_NONCE=$(cat ${COIN_NAME}-regtest.txt | grep "^nonce:" | $SED 's/^nonce: //')

    MAIN_GENESIS_HASH=$(cat ${COIN_NAME}-main.txt | grep "^genesis hash:" | $SED 's/^genesis hash: //')
    TEST_GENESIS_HASH=$(cat ${COIN_NAME}-test.txt | grep "^genesis hash:" | $SED 's/^genesis hash: //')
    REGTEST_GENESIS_HASH=$(cat ${COIN_NAME}-regtest.txt | grep "^genesis hash:" | $SED 's/^genesis hash: //')

    popd
}

newcoin_replace_vars()
{
    if [ -d $COIN_NAME_LOWER ]; then
        echo "Warning: $COIN_NAME_LOWER already existing. Not replacing any values"
        return 0
    fi
    if [ ! -d "litecoin-master" ]; then
        # clone litecoin and keep local cache
        git clone -b $LITECOIN_BRANCH $LITECOIN_REPOS litecoin-master
    else
        echo "Updating master branch"
        pushd litecoin-master
        git pull
        popd
    fi

    git clone -b $LITECOIN_BRANCH litecoin-master $COIN_NAME_LOWER

    pushd $COIN_NAME_LOWER

    # first rename all directories
    for i in $(find . -type d | grep -v "^./.git" | grep litecoin); do 
        git mv $i $(echo $i| $SED "s/litecoin/$COIN_NAME_LOWER/")
    done

    # then rename all files
    for i in $(find . -type f | grep -v "^./.git" | grep litecoin); do
        git mv $i $(echo $i| $SED "s/litecoin/$COIN_NAME_LOWER/")
    done

    # now replace all litecoin references to the new coin name
    for i in $(find . -type f | grep -v "^./.git"); do
        $SED -i "s/Litecoin/$COIN_NAME/g" $i
        $SED -i "s/litecoin/$COIN_NAME_LOWER/g" $i
        $SED -i "s/LITECOIN/$COIN_NAME_UPPER/g" $i
        $SED -i "s/LTC/$COIN_UNIT/g" $i
    done

    $SED -i "s/ltc/$COIN_UNIT_LOWER/g" src/chainparams.cpp

    $SED -i "s/84000000/$TOTAL_SUPPLY/" src/amount.h
    $SED -i "s/1,48/1,$PUBKEY_CHAR/" src/chainparams.cpp

    $SED -i "s/1317972665/$TIMESTAMP/" src/chainparams.cpp

    $SED -i "s;NY Times 05/Oct/2011 Steve Jobs, Apple’s Visionary, Dies at 56;$PHRASE;" src/chainparams.cpp

    $SED -i "s/= 9333;/= $MAINNET_PORT;/" src/chainparams.cpp
    $SED -i "s/= 19335;/= $TESTNET_PORT;/" src/chainparams.cpp

    $SED -i "s/$LITECOIN_PUB_KEY/$MAIN_PUB_KEY/" src/chainparams.cpp
    $SED -i "s/$LITECOIN_MERKLE_HASH/$MERKLE_HASH/" src/chainparams.cpp
    $SED -i "s/$LITECOIN_MERKLE_HASH/$MERKLE_HASH/" src/qt/test/rpcnestedtests.cpp

    $SED -i "0,/$LITECOIN_MAIN_GENESIS_HASH/s//$MAIN_GENESIS_HASH/" src/chainparams.cpp
    $SED -i "0,/$LITECOIN_TEST_GENESIS_HASH/s//$TEST_GENESIS_HASH/" src/chainparams.cpp
    $SED -i "0,/$LITECOIN_REGTEST_GENESIS_HASH/s//$REGTEST_GENESIS_HASH/" src/chainparams.cpp

    $SED -i "0,/2084524493/s//$MAIN_NONCE/" src/chainparams.cpp
    $SED -i "0,/293345/s//$TEST_NONCE/" src/chainparams.cpp
    $SED -i "0,/1296688602, 0/s//1296688602, $REGTEST_NONCE/" src/chainparams.cpp
    $SED -i "0,/0x1e0ffff0/s//$BITS/" src/chainparams.cpp

    $SED -i "s,vSeeds.emplace_back,//vSeeds.emplace_back,g" src/chainparams.cpp

    if [ -n "$PREMINED_AMOUNT" ]; then
        $SED -i "s/CAmount nSubsidy = 50 \* COIN;/if \(nHeight == 1\) return COIN \* $PREMINED_AMOUNT;\n    CAmount nSubsidy = 50 \* COIN;/" src/validation.cpp
    fi

    $SED -i "s/COINBASE_MATURITY = 100/COINBASE_MATURITY = $COINBASE_MATURITY/" src/consensus/consensus.h

    # reset minimum chain work to 0
    $SED -i "s/$MINIMUM_CHAIN_WORK_MAIN/0x00/" src/chainparams.cpp
    $SED -i "s/$MINIMUM_CHAIN_WORK_TEST/0x00/" src/chainparams.cpp

    # change bip activation heights
    # bip 16
    $SED -i "s/218579/0/" src/chainparams.cpp
    # bip 34
    $SED -i "s/710000/0/" src/chainparams.cpp
    $SED -i "s/fa09d204a83a768ed5a7c8d441fa62f2043abf420cff1226c7b4329aeb9d51cf/$MAIN_GENESIS_HASH/" src/chainparams.cpp
    # bip 65
    $SED -i "s/918684/0/" src/chainparams.cpp
    # bip 66
    $SED -i "s/811879/0/" src/chainparams.cpp

    # testdummy
    $SED -i "s/1199145601/Consensus::BIP9Deployment::ALWAYS_ACTIVE/g" src/chainparams.cpp
    $SED -i "s/1230767999/Consensus::BIP9Deployment::NO_TIMEOUT/g" src/chainparams.cpp

    $SED -i "s/1199145601/Consensus::BIP9Deployment::ALWAYS_ACTIVE/g" src/chainparams.cpp
    $SED -i "s/1230767999/Consensus::BIP9Deployment::NO_TIMEOUT/g" src/chainparams.cpp

    # csv
    $SED -i "s/1485561600/Consensus::BIP9Deployment::ALWAYS_ACTIVE/g" src/chainparams.cpp
    $SED -i "s/1517356801/Consensus::BIP9Deployment::NO_TIMEOUT/g" src/chainparams.cpp

    $SED -i "s/1483228800/Consensus::BIP9Deployment::ALWAYS_ACTIVE/g" src/chainparams.cpp
    $SED -i "s/1517356801/Consensus::BIP9Deployment::NO_TIMEOUT/g" src/chainparams.cpp

    # segwit
    $SED -i "s/1485561600/Consensus::BIP9Deployment::ALWAYS_ACTIVE/g" src/chainparams.cpp
    # timeout of segwit is the same as csv

    # defaultAssumeValid
    $SED -i "s/0x66f49ad85624c33e4fd61aa45c54012509ed4a53308908dd07f56346c7939273/0x$MAIN_GENESIS_HASH/" src/chainparams.cpp
    $SED -i "s/0x1efb29c8187d5a496a33377941d1df415169c3ce5d8c05d055f25b683ec3f9a3/0x$TEST_GENESIS_HASH/" src/chainparams.cpp









  FILE=src/chainparams.cpp

  $SED -i "s/0xfd;/0x69;/" $FILE #works
    $SED -i "s/0xd2;/0x6e;/" $FILE #works
    $SED -i "s/0xc8;/0x61;/" $FILE #works
    $SED -i "s/0xf1;/0x72;/" $FILE #works
    $SED -i "s/1,111);/1,77);/" $FILE #w
    $SED -i "s/1,239)/1,77);/" $FILE #w
    $SED -i "s/{0x04, 0x35, 0x87, 0xCF}/{0x04, 0x74, 0x73, 0x4E}/" $FILE   #w
    $SED -i "s/{0x04, 0x35, 0x83, 0x94}/{0x04, 0x47, 0x4D, 0x4F}/" $FILE #w

    0x04, 0x49, 0x41, 0x4D


  FILE="bitcoinunits.cpp"
  LC_ALL=C find . -type f -name "*$FILE" -exec sed -i '' s/lites/psuxai/ {} + && \
    LC_ALL=C find . -type f -name "*$FILE" -exec sed -i '' s/photons/elohim/ {} + && \
    LC_ALL=C find . -type f -name "*$FILE" -exec sed -i '' s/litoshi/daemonai/ {} + && \
    LC_ALL=C find . -type f -name "*$FILE" -exec sed -i '' s/Lites/Psuxai/ {} + && \
    LC_ALL=C find . -type f -name "*$FILE" -exec sed -i '' s/Photons/Elohim/ {} + && \
    LC_ALL=C find . -type f -name "*$FILE" -exec sed -i '' s/Litoshi/Daemonai/ {} +

    
  FILE="src/chainparamsseeds.h"
  FIND='{{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00'
  REPLACE='//{{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00'
  $SED -i "s|$FIND|$REPLACE|" $FILE


# never modified?
    FILE="src/chainparams.cpp"
    $SED -i "s/0xfb;/0x67;/g" $FILE #never modified
    $SED -i "s/1,176);/1,78);/g" $FILE #never modified
    $SED -i "s/0xc0;/0x6f;/g" $FILE #
    $SED -i "s/0xb6;/0x64;/g" $FILE #
    $SED -i "s/0xdb;/0x73;/g" $FILE #



    $SED -i "s/1,48);/1,78);/" $FILE
    #$SED -i "s/{0x04, 0x88, 0xB2, 0x1E}/{0x04, 0x49, 0x41, 0x4D}/" $FILE
    #$SED -i "s/{0x04, 0x88, 0xAD, 0xE4}/{0x04, 0x47, 0x4F, 0x44}/" $FILE
    FIND='nPowTargetSpacing = 2.5'
    REPLACE='nPowTargetSpacing = 7.4'
    $SED -i "s/$FIND/$REPLACE/" $FILE
    FIND='nPowTargetTimespan = 3.5'
    REPLACE='nPowTargetTimespan = 10'
    $SED -i "s/$FIND/$REPLACE/" $FILE





    #EXCLUDED
    #TEST_GENESIS_HASH=fb28d1f904e757e296cd334f4f551c94d7dc5770615cc40566c7fdc1eb801b66 ##THIS LINE FOR TESTING ONLY 

    #WORKS
   $SED -i "s/0x000000000000000000000000000000000000000000000000df7b5aa1700ce/0x00/" $FILE
   $SED -i "s/8075c771ed8b495ffd943980a95f702ab34fce3c8c54e379548bda33cc8c0573/$TEST_GENESIS_HASH/" $FILE
   $SED -i "s/17748a31ba97afdc9a4f86837a39d287e3e7c7290a08a1d816c5969c78a83289/$TEST_GENESIS_HASH/" $FILE
   $SED -i "s/2056, /0, /" $FILE 

   #WORKS
   $SED -i "s/1516406749/1486949366/" $FILE
   $SED -i "s/794057/0/" $FILE #works
   $SED -i "s/0.01/0/" $FILE #works
   $SED -i "s/76;/0;/" $FILE #works
   


  $SED -i "s/1516406833/$TIMESTAMP/" $FILE
  $SED -i "s/19831879/0/" $FILE
  $SED -i "s/0.06/0/" $FILE

  # echo "You must manually replace checkpointData = {...}; in src/chainparams.cpp"
  #   echo "with..."
    echo "checkpointData = {
             {
                { 0, uint256S(\"0x$MAIN_GENESIS_HASH\")},
             }
        };"
        read


    echo "checkpointData = {
            {
                { 0, uint256S(\"$TEST_GENESIS_HASH\")},
            }
        };"





  #   echo "checkpointData = {
  #           {
  #               { 0, uint256S(\"$REGTEST_GENESIS_HASH\")},
  #           }
  #       };"
  #   echo "Press enter when you have finished adding it."

    # TODO: fix checkpoints
    popd
}

build_new_coin()
{
    # only run autogen.sh/configure if not done previously
    if [ ! -e $COIN_NAME_LOWER/Makefile ]; then
        docker_run "cd /$COIN_NAME_LOWER ; bash  /$COIN_NAME_LOWER/autogen.sh"
        docker_run "cd /$COIN_NAME_LOWER ; bash  /$COIN_NAME_LOWER/configure --disable-tests --disable-bench"
    fi
    # always build as the user could have manually changed some files
    docker_run "cd /$COIN_NAME_LOWER ; make -j2"
}


if [ $DIRNAME =  "." ]; then
    DIRNAME=$PWD
fi

cd $DIRNAME

# sanity check

case $OSVERSION in
    Linux*)
        SED=sed
    ;;
    Darwin*)
        SED=$(which gsed 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "please install gnu-sed with 'brew install gnu-sed'"
            exit 1
        fi
        SED=gsed
    ;;
    *)
        echo "This script only works on Linux and MacOS"
        exit 1
    ;;
esac


if ! which docker &>/dev/null; then
    echo Please install docker first
    exit 1
fi

if ! which git &>/dev/null; then
    echo Please install git first
    exit 1
fi

case $1 in
    stop)
        docker_stop_nodes
    ;;
    remove_nodes)
        docker_stop_nodes
        docker_remove_nodes
    ;;
    clean_up)
        docker_stop_nodes
        for i in $(seq 2 5); do
           docker_run_node $i "rm -rf /$COIN_NAME_LOWER /root/.$COIN_NAME_LOWER" &>/dev/null
        done
        docker_remove_nodes
        docker_remove_network
        rm -rf $COIN_NAME_LOWER
        if [ "$2" != "keep_genesis_block" ]; then
            rm -f GenesisH0/${COIN_NAME}-*.txt
        fi
        for i in $(seq 2 5); do
           rm -rf miner$i
        done
    ;;
    start)
        if [ -n "$(docker ps -q -f ancestor=$DOCKER_IMAGE_LABEL)" ]; then
            echo "There are nodes running. Please stop them first with: $0 stop"
            exit 1
        fi
        #docker_build_image
        #generate_genesis_block
        #newcoin_replace_vars
        build_new_coin
        docker_create_network

        docker_run_node 2 "cd /$COIN_NAME_LOWER ; ./src/${COIN_NAME_LOWER}d $CHAIN -listen -noconnect -bind=$DOCKER_NETWORK.2 -addnode=$DOCKER_NETWORK.1 -addnode=$DOCKER_NETWORK.3 -addnode=$DOCKER_NETWORK.4 -addnode=$DOCKER_NETWORK.5" &
        docker_run_node 3 "cd /$COIN_NAME_LOWER ; ./src/${COIN_NAME_LOWER}d $CHAIN -listen -noconnect -bind=$DOCKER_NETWORK.3 -addnode=$DOCKER_NETWORK.1 -addnode=$DOCKER_NETWORK.2 -addnode=$DOCKER_NETWORK.4 -addnode=$DOCKER_NETWORK.5" &
        docker_run_node 4 "cd /$COIN_NAME_LOWER ; ./src/${COIN_NAME_LOWER}d $CHAIN -listen -noconnect -bind=$DOCKER_NETWORK.4 -addnode=$DOCKER_NETWORK.1 -addnode=$DOCKER_NETWORK.2 -addnode=$DOCKER_NETWORK.3 -addnode=$DOCKER_NETWORK.5" &
        docker_run_node 5 "cd /$COIN_NAME_LOWER ; ./src/${COIN_NAME_LOWER}d $CHAIN -listen -noconnect -bind=$DOCKER_NETWORK.5 -addnode=$DOCKER_NETWORK.1 -addnode=$DOCKER_NETWORK.2 -addnode=$DOCKER_NETWORK.3 -addnode=$DOCKER_NETWORK.4" &

        echo "Docker containers should be up and running now. You may run the following command to check the network status:
for i in \$(docker ps -q); do docker exec \$i /$COIN_NAME_LOWER/src/${COIN_NAME_LOWER}-cli $CHAIN getblockchaininfo; done"
        echo "To ask the nodes to mine some blocks simply run:
for i in \$(docker ps -q); do docker exec \$i /$COIN_NAME_LOWER/src/${COIN_NAME_LOWER}-cli $CHAIN generate 2  & done"
        exit 1
    ;;
    *)
        cat <<EOF
Usage: $0 (start|stop|remove_nodes|clean_up)
 - start: bootstrap environment, build and run your new coin
 - stop: simply stop the containers without removing them
 - remove_nodes: remove the old docker container images. This will stop them first if necessary.
 - clean_up: WARNING: this will stop and remove docker containers and network, source code, genesis block information and nodes data directory. (to start from scratch)
EOF
    ;;
esac
