pragma solidity >=0.5.0 <0.6.0;

import "../interfaces/IPriceFeed.sol";

contract UniswapFactoryInterface {
    function getExchange(IERC20 token) external view returns (UniswapExchangeInterface exchange);
}

contract UniswapExchangeInterface {
       // Trade ERC20 to ERC20
    function getEthToTokenInputPrice(uint256 eth_sold) external view returns (uint256 tokens_bought);
    function getTokenToEthInputPrice(uint256 tokens_sold) external view returns (uint256 eth_bought);
}

contract UniswapPriceFeed is IPriceFeed {
    // 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95 - mainnet
    // 0xf5D915570BC477f9B8D6C0E980aA81757A3AaC36 - rinkeby

    UniswapFactoryInterface constant factory = UniswapFactoryInterface(0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95);

    function convertAmountToETH(IERC20 srcToken, uint srcAmount) external view returns (uint ethAmount){
        UniswapExchangeInterface srcExchange = factory.getExchange(srcToken);
        ethAmount = srcExchange.getTokenToEthInputPrice(srcAmount);
    }

    function convertAmountFromETH(IERC20 dstToken, uint ethAmount) external view returns (uint dstAmount){
        UniswapExchangeInterface dstExchange = factory.getExchange(dstToken);
        dstAmount = dstExchange.getEthToTokenInputPrice(ethAmount);
    }

    function convertAmount(IERC20 srcToken, uint srcAmount, IERC20 dstToken) external view returns (uint dstAmount){
        UniswapExchangeInterface srcExchange = factory.getExchange(srcToken);
        UniswapExchangeInterface dstExchange = factory.getExchange(dstToken);
        uint ethAmount = srcExchange.getTokenToEthInputPrice(srcAmount);
        dstAmount = dstExchange.getEthToTokenInputPrice(ethAmount);
    }
}