toArg () {
    printf "%064s" ${1#*x}
}

toDecimal () {
    echo "0x$1" | xargs printf "%d" | xargs seth --from-wei | xargs printf "0%s\n"
}

toRawAmount () {
    seth --to-wei $1 $2 | xargs seth --to-uint256
}

EXCHANGE=0x5771e98875875feb235bd3386b25dbe9dad21704 # `dapp create exchanges/UniswapExchange`
LENDER=0x943531eb32549d48e3b0321d934fa2ea585d2f61 # `dapp create lenders/MakerDaoLender`
LEVERAGER=0x9c41904c985b2eab4909a30db82fb041c4af0d22 # `dapp create Leverager`

PRINCIPAL=0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359 # DAI
HELD_ASSET=0x0000000000000000000000000000000000000000 #ETH
# HELD_ASSET=0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2 # WETH

MAX_ITERATIONS=`seth --to-uint256 99`
MIN_COLLATERAL_AMOUNT=`toRawAmount 0.01 eth`
COLL_RATIO_CLOSE=`toRawAmount 1.51 eth`