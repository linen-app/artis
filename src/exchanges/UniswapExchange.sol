pragma solidity >=0.5.0 <0.6.0;

import "../interfaces/IExchange.sol";

contract UniswapFactoryInterface {
    function getExchange(IERC20 token) external view returns (UniswapExchangeInterface exchange);
}

contract UniswapExchangeInterface {
       // Trade ERC20 to ERC20
    function tokenToTokenSwapInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, IERC20 token_addr) external returns (uint256  tokens_bought);
    function tokenToTokenSwapOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, IERC20 token_addr) external returns (uint256  tokens_sold);
}

contract UniswapExchange is IExchange {
    // 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95 - mainnet
    // 0xf5D915570BC477f9B8D6C0E980aA81757A3AaC36 - rinkeby

    UniswapFactoryInterface constant factory = UniswapFactoryInterface(0xf5D915570BC477f9B8D6C0E980aA81757A3AaC36);

    // specify either srcAmount = 0 or dstAmount = 0
    // actual amount - actual srcAmount if srcAmount is zero or actual dstAmount if dstAmount is zero
    function swap(IERC20 srcToken, uint srcAmount, IERC20 dstToken, uint dstAmount) external returns (uint actualAmount) {
        require(srcAmount > 0 || dstAmount > 0, "Either srcAmount or dstAmount must be positive");

        UniswapExchangeInterface srcExchange = factory.getExchange(srcToken);
        UniswapExchangeInterface dstExchange = factory.getExchange(dstToken);
        require(address(srcExchange) != address(0), "Can't find srcToken exchange");
        require(address(dstExchange) != address(0), "Can't find dstToken exchange");

        _ensureApproval(srcToken, address(srcExchange));

        uint deadline = now;
        if (srcAmount == 0) {
            return srcExchange.tokenToTokenSwapOutput(dstAmount, uint(-1), uint(-1), deadline, dstToken);
        } else if (dstAmount == 0) {
            return srcExchange.tokenToTokenSwapInput(srcAmount, 1, 1, deadline, dstToken);
        } else {
            revert("Either srcAmount or dstAmount must be 0");
        }
    }

    function _ensureApproval(IERC20 token, address spender) internal {
        if (token.allowance(address(this), spender) != uint(-1)) {
            require(token.approve(spender, uint(-1)));
        }
    }
}