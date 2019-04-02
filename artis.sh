toArg () {
    printf "%064s" ${1#*x}
}

toDecimal () {
    echo "0x$1" | xargs printf "%d" | xargs seth --from-wei | xargs printf "0%s\n"
}

toRawAmount () {
    seth --to-wei $1 $2 | xargs seth --to-uint256
}

EXCHANGE=0xca3c70f65f8e9dac0ac3527af980b1d914f9c7c2 # `dapp create exchanges/UniswapExchange`
LENDER=0xbfc681d82bb50c08edfbe4bd24615a9c5ecde267 # `dapp create lenders/MakerDaoLender`
LEVERAGER=0x5b679d2a592a7a0df1916e0635f978a497d50c33 # `dapp create Leverager`

PRINCIPAL=0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359 # DAI
HELD_ASSET=0x0000000000000000000000000000000000000000
# HELD_ASSET=0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2 # WETH

MAX_ITERATIONS=`seth --to-uint256 99`
MIN_COLLATERAL_AMOUNT=`toRawAmount 0.01 eth`