toArg () {
    seth --to-word $1
}

toRawAmount () {
    seth --to-wei $1 $2 | xargs seth --to-uint256
}

PROXY_REGISTRY=0x8f2af6150cd568740c19848b795406c41d12d173

EXCHANGE=0x76ed7c7f28d0b51295ec44eb10eb3bac7f615645 # `dapp create exchanges/UniswapExchangeRinkeby`
LENDER=0x1e22ccfd7e213f8a533bcbfc193378ccff76ed81 # `dapp create lenders/CompoundV2LenderRinkeby`
LEVERAGER=0x8b7f7e5d3735ea694ce16890b4a81fd3417fcf6e # `dapp create Leverager`

PRINCIPAL=0x5592ec0cfb4dbc12d3ab100b257153436a1f0fea # DAI @ Compound
HELD_ASSET=0x0000000000000000000000000000000000000000 #ETH

MAX_ITERATIONS=`seth --to-uint256 99`
MIN_COLLATERAL_AMOUNT=`toRawAmount 0.0001 eth`
COLL_RATIO_CLOSE=`toRawAmount 2.01 eth`