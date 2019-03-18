pragma solidity >=0.4.21 <0.6.0;

import "./IERC20.sol";
import "./IPriceFeed.sol";

contract IExchange is IPriceFeed{
    function swap(IERC20 srcToken, IERC20 srcAmount, IERC20 dstToken, IERC20 dstAmount) external;
}
