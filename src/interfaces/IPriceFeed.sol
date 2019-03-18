pragma solidity >=0.4.21 <0.6.0;

import "./IERC20.sol";

interface IPriceFeed {
    function convertAmount(IERC20 srcToken, uint baseAmount, IERC20 dstToken) external view returns (uint dstAmount);
}
