pragma solidity >=0.5.0 <0.6.0;

import "./IERC20.sol";

interface IPriceFeed {
    function convertAmountToETH(IERC20 srcToken, uint srcAmount) external view returns (uint ethAmount);
    function convertAmountFromETH(IERC20 dstToken, uint ethAmount) external view returns (uint dstAmount);
    function convertAmount(IERC20 srcToken, uint srcAmount, IERC20 dstToken) external view returns (uint dstAmount);
}
