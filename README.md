TODO:
[x] Uniswap integration
[x] Looping
[x] Why Failure(8,72)? -> (invalid collateral ratio & depositAmount bug)
[x] Position closing
[x] MakerDAO repay and return
[x] Uniswap price feed
[x] MakerDAO fee handling
[x] Swap ETH instead of WETH on uniswap
[x] Total fee calc
[] Docs
[] Gas fee, exchange fee 
[] Leverage as param
[] Collateral top-up
[] Liquidation price calc
[] Storage Alignment check
[] Events and names
[] Auto tests
[] Token balances and ownership description
[] Add agreementId param

Questions:
- Should we use our MakerDAO gateway?: NO

# How to open a long ETH position:

## Prerequisites
- Ethereum account with initial deposit (in ETH or WETH token)
- [Seth](https://github.com/dapphub/dapptools/tree/master/src/seth) command line tool, with an access to abovementioned account.

0. Setup seth settings.

Example of `~/.sethrc` file
```
export ETHERSCAN_API_KEY=<your_key>
export ETH_GAS=3000000
export ETH_GAS_PRICE=5000000000 # 5 GWei
export ETH_FROM=<your_address>
export SETH_CHAIN=ethlive
export ETH_KEYSTORE=<path to a folder with json keystore file>
export ETH_PASSWORD=<path to a file with password to your keystore file>
```

1. If you used CDP portal before, you most probably already have proxy wallet, and you can use it for Artis.
```
# check if you have proxy wallet, assossiated with your current address
seth call 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4 "proxies(address)(address)" 0x005afe523f242a177a21daeeb3bc343dd5db602c
```
If this command return non-zero code, it's a `DS_PROXY` address, that you can use for further actions. All you need is to use the owner of this proxy as a `ETH_FROM` address.

If you don't have proxy wallet, you can create a new one.
```
seth send 0x4678f0a6958e4d2bc4f1baf7bc52e8f3564f3fe4 "build()"
```
2.

heldToken - specify 0 if held asset is Ether
initialDepositAmount - specify 0 if held asset is Ether, instead you need to provide deposit amount in msg.value