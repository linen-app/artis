toArg () {
    seth --to-word $1
}

toRawAmount () {
    seth --to-wei $1 $2 | xargs seth --to-uint256
}

PROXY_REGISTRY=0x4678f0a6958e4d2bc4f1baf7bc52e8f3564f3fe4

EXCHANGE=0x238a19577695384222548ba1cd1cf65d48d027a3 # `dapp create exchanges/UniswapExchangeMainnet`
LENDER=0xbbe273a1f65cd0a2b1357a00cf50c1d457ad0f20 # `dapp create lenders/MakerDaoLenderMainnet`
LEVERAGER=0x54966cdbc7a9ef49e8ec54686603c085deefda1b # `dapp create Leverager`

PRINCIPAL=0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359 # DAI
HELD_ASSET=0x0000000000000000000000000000000000000000 #ETH

MAX_ITERATIONS=`seth --to-uint256 99`
MIN_COLLATERAL_AMOUNT=`toRawAmount 0.01 eth`
COLL_RATIO_CLOSE=`toRawAmount 1.51 eth`