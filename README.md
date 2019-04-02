# Artis

The solution to execute decentralized margin trading on DEXes.

It works with [Uniswap](https://uniswap.io/) and [MakerDAO](https://makerdao.com).

More DEXes and lending protocols are coming.

## How to open a long ETH position:

In this guide we will open a long ETH positions with DAI as owed token.

Other token pairs will come once more lending protocols will be integrated.

### Prerequisites
- Ethereum account with initial deposit (in ETH or WETH token)
- [Seth](https://dapp.tools/seth) command line tool, with access to the abovementioned account. Seth docs can be found [here](https://github.com/dapphub/dapptools/tree/master/src/seth)

Example of `~/.sethrc` file with Seth settings
```
export ETHERSCAN_API_KEY=<your_key>
export ETH_GAS=3000000
export ETH_GAS_PRICE=5000000000 # 5 GWei, please adjust it if transactions are slow
export ETH_FROM=<your address>
export SETH_CHAIN=ethlive
export ETH_KEYSTORE=<path to a folder with json keystore file>
export ETH_PASSWORD=<path to a file with password to your keystore file>
```
### Steps

#### 1. If you used [CDP portal](https://cdp.makerdao.com) before, you most probably already have a proxy wallet, and you can use it for Artis.*
```
# check if you have proxy wallet, assossiated with your current address
seth call 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4 "proxies(address)(address)" <your address>
```
If this command return non-zero code, it's a `DS_PROXY` address, that you can use for further actions.

If you don't have proxy wallet, you can create a new one.
```
seth send 0x4678f0a6958e4d2bc4f1baf7bc52e8f3564f3fe4 "build()"
```
In this case to obtain `DS_PROXY`, you can go to https://etherscan.io, open the last transaction by txhash -> go to Event Logs -> search for `Created` event and take the first data field from this event. It will be `DS_PROXY` address.

#### 2. Define some variables in bash that will be used to create a transaction

##### 2.1 Predefined variables and functions can be loaded from `artis.sh` file:
```
source artis.sh
```

##### 2.2 Specify address of `DS_PROXY` from the previous step
```
DS_PROXY=<address of proxy wallet from the previous step>
```

##### 2.3 Specify the amount of the initial deposit (in ETH):
```
AMOUNT=1
```

##### 2.4 Specify collateral ratio that the underlying position will have

Smaller values will give you more leverage, however they give you more risk of liquidation: in case if ETH will go down relatively to DAI and your initial deposit becomes too small to cover minimal collateral ratio and your initial deposit will be seized.

Minimal amount: 1.5 (very risky). Recommended amount: 1.7

Max theoretical leverage table:

| Leverage | Collateral ratio |
| ----------- | ----------- |
| ~3 | 1.5 |
| ~2.66 | 1.6 |
| ~2.43 | 1.7 |
| ~2.25 | 1.8 |
| ~2.11 | 1.9 |
| ~2.00 | 2.0 |

```
COLL_RATIO=1.7
```
#### 3. Send `openPosition` transaction
The transaction will go through proxy wallet, so the calldata needs to be formed manually
```
# Calculate function signature
SIG=$(seth sig "openPosition(address[4],uint256[4])")

# Form calldata for Artis contract
CALLDATA="$SIG$(toArg $LENDER)$(toArg $EXCHANGE)$(toArg $HELD_ASSET)$(toArg $PRINCIPAL)\
$(toRawAmount 0 eth)$(toRawAmount $COLL_RATIO eth)$MAX_ITERATIONS$MIN_COLLATERAL_AMOUNT"

# Send transaction to your proxy wallet
seth send --value $(seth --to-wei $AMOUNT eth) "$DS_PROXY" "execute(address,bytes memory)(bytes32)" "$LEVERAGER" "$CALLDATA"
```
