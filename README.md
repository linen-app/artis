# How to open a long ETH position:

## Prerequisites
- Ethereum account with initial deposit (in ETH or WETH token)
- [Seth](https://github.com/dapphub/dapptools/tree/master/src/seth) command line tool, with access to the abovementioned account.

Example of `~/.sethrc` file with Seth settings
```
export ETHERSCAN_API_KEY=<your_key>
export ETH_GAS=3000000
export ETH_GAS_PRICE=5000000000 # 5 GWei
export ETH_FROM=<your address>
export SETH_CHAIN=ethlive
export ETH_KEYSTORE=<path to a folder with json keystore file>
export ETH_PASSWORD=<path to a file with password to your keystore file>
```

1. If you used CDP portal before, you most probably already have a proxy wallet, and you can use it for Artis.
```
# check if you have proxy wallet, assossiated with your current address
seth call 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4 "proxies(address)(address)" <your address>
```
If this command return non-zero code, it's a `DS_PROXY` address, that you can use for further actions.

If you don't have proxy wallet, you can create a new one.
```
seth send 0x4678f0a6958e4d2bc4f1baf7bc52e8f3564f3fe4 "build()"
```
In this case to obtain `DS_PROXY`, you can go to https://etherscan.io, open the last transaction by txhash -> go to Event Logs -> search for `Created` event and take the first data field from this event.

2. Define some variables in bash that will be used to create transaction

Predefined variables and functions can be loaded from artis.sh file:
```
source artis.sh
```

Specify address of `DS_PROXY` from the previous step
```
DS_PROXY=<address of proxy wallet from the previous step>
```

Currently Artis integrated with MakerDAO only, so for principal we will use DAI token
```
PRINCIPAL=0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359 # DAI
```

If you want to put WETH as an initial deposit, specify WETH address as `HELD_ASSET`:
```
HELD_ASSET=0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
```
Or you can use plain ETH as a held asset. In this case you need to specify zero address as `HELD_ASSET`:
```
HELD_ASSET=0x0000000000000000000000000000000000000000
```

Specify the amount of the initial deposit (in ETH/WETH):
```
AMOUNT=1
```

Specify collateral ratio that the underlying position will have

Smaller values will give you more leverage, however they give you more risk of liquidation: in case if ETH will go down relatively to DAI and your initial deposit becomes too small to cover minimal collateral ratio and your initial deposit will be seized.

```
COLL_RATIO=1.7
```

initialDepositAmount - specify 0 if held asset is Ether, instead you need to provide deposit amount in msg.value
