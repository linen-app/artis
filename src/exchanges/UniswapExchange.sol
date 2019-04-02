pragma solidity >=0.5.0 <0.6.0;

import "../interfaces/IExchange.sol";
import "../interfaces/IWrappedEther.sol";
import "../libraries/ERC20Lib.sol";

interface UniswapFactoryInterface {
    function getExchange(IERC20 token) external view returns (UniswapExchangeInterface exchange);
}

interface UniswapExchangeInterface {
    // Get Prices
    function getEthToTokenInputPrice(uint256 eth_sold) external view returns (uint256 tokens_bought);
    function getEthToTokenOutputPrice(uint256 tokens_bought) external view returns (uint256 eth_sold);
    function getTokenToEthInputPrice(uint256 tokens_sold) external view returns (uint256 eth_bought);
    function getTokenToEthOutputPrice(uint256 eth_bought) external view returns (uint256 tokens_sold);
     // Trade ETH to ERC20
    function ethToTokenSwapInput(uint256 min_tokens, uint256 deadline) external payable returns (uint256  tokens_bought);
    function ethToTokenSwapOutput(uint256 tokens_bought, uint256 deadline) external payable returns (uint256  eth_sold);
    // Trade ERC20 to ETH
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256  eth_bought);
    function tokenToEthSwapOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline) external returns (uint256  tokens_sold);
    // Trade ERC20 to ERC20
    function tokenToTokenSwapInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, IERC20 token_addr) external returns (uint256  tokens_bought);
    function tokenToTokenSwapOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, IERC20 token_addr) external returns (uint256  tokens_sold);
}

contract UniswapExchange is IExchange {
    using ERC20Lib for IERC20;

    // 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95 - mainnet
    // 0xf5D915570BC477f9B8D6C0E980aA81757A3AaC36 - rinkeby

    UniswapFactoryInterface constant factory = UniswapFactoryInterface(0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95);
    IWrappedEther constant weth = IWrappedEther(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);


    // CHECK EVERYTHING!!!
    function convertAmountSrc(IERC20 srcToken, uint srcAmount, IERC20 dstToken) external view returns (uint dstAmount){
        UniswapExchangeInterface srcExchange = factory.getExchange(srcToken);
        UniswapExchangeInterface dstExchange = factory.getExchange(dstToken);

        if (address(srcToken) == address(weth)) {
            dstAmount = dstExchange.getEthToTokenInputPrice(srcAmount);
        } else if (address(dstToken) == address(weth)) {
            dstAmount = srcExchange.getTokenToEthInputPrice(srcAmount);
        } else {
            uint ethAmount = srcExchange.getTokenToEthInputPrice(srcAmount);
            dstAmount = dstExchange.getEthToTokenInputPrice(ethAmount);
        }
    }

    function convertAmountDst(IERC20 srcToken, IERC20 dstToken, uint dstAmount) external view returns (uint srcAmount){
        UniswapExchangeInterface srcExchange = factory.getExchange(srcToken);
        UniswapExchangeInterface dstExchange = factory.getExchange(dstToken);

        if (address(srcToken) == address(weth)) {
            srcAmount = dstExchange.getEthToTokenOutputPrice(dstAmount);
        } else if (address(dstToken) == address(weth)) {
            srcAmount = srcExchange.getTokenToEthOutputPrice(dstAmount);
        } else {
            uint ethAmount = dstExchange.getEthToTokenOutputPrice(dstAmount);
            srcAmount = srcExchange.getTokenToEthOutputPrice(ethAmount);
        }
    }

    // specify either srcAmount = 0 or dstAmount = 0
    // actual amount - actual srcAmount if srcAmount is zero or actual dstAmount if dstAmount is zero
    function swap(IERC20 srcToken, uint srcAmount, IERC20 dstToken, uint dstAmount) external returns (uint actualAmount) {
        require(srcAmount > 0 || dstAmount > 0, "Either srcAmount or dstAmount must be positive");

        UniswapExchangeInterface srcExchange = factory.getExchange(srcToken);
        UniswapExchangeInterface dstExchange = factory.getExchange(dstToken);
        require(address(srcExchange) != address(0), "Can't find srcToken exchange");
        require(address(dstExchange) != address(0), "Can't find dstToken exchange");
        uint deadline = now;

        if (address(srcToken) == address(weth)) {
            if (srcAmount == 0) {
                uint ethNeeded = dstExchange.getEthToTokenOutputPrice(dstAmount);
                weth.withdraw(ethNeeded);
                return dstExchange.ethToTokenSwapOutput.value(ethNeeded)(dstAmount, deadline);
            } else if (dstAmount == 0) {
                weth.withdraw(srcAmount);
                return dstExchange.ethToTokenSwapInput.value(srcAmount)(1, deadline);
            } else {
                revert("Either srcAmount or dstAmount must be 0");
            }

        } else if (address(dstToken) == address(weth)) {
            srcToken.ensureApproval(address(srcExchange));
            uint ethAmount;
            if (srcAmount == 0) {
                ethAmount = srcExchange.tokenToEthSwapOutput(dstAmount, uint(-1), deadline);
            } else if (dstAmount == 0) {
                ethAmount = srcExchange.tokenToEthSwapInput(srcAmount, 1, deadline);
            } else {
                revert("Either srcAmount or dstAmount must be 0");
            }
            weth.deposit.value(ethAmount)();
            return ethAmount;
        } else {
            srcToken.ensureApproval(address(srcExchange));
            if (srcAmount == 0) {
                return srcExchange.tokenToTokenSwapOutput(dstAmount, uint(-1), uint(-1), deadline, dstToken);
            } else if (dstAmount == 0) {
                return srcExchange.tokenToTokenSwapInput(srcAmount, 1, 1, deadline, dstToken);
            } else {
                revert("Either srcAmount or dstAmount must be 0");
            }
        }
    }
}