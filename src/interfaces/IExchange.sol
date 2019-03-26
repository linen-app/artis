pragma solidity >=0.5.0 <0.6.0;

import "./IERC20.sol";

interface IExchange {
    // specify either srcAmount = 0 or dstAmount = 0
    // actualAmount - actual srcAmount if srcAmount is zero or actual dstAmount if dstAmount is zero
    function swap(IERC20 srcToken, uint srcAmount, IERC20 dstToken, uint dstAmount) external returns (uint actualAmount);
}
