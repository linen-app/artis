pragma solidity >=0.4.21 <0.6.0;

import "./interfaces/IERC20.sol";
import "./interfaces/IExchange.sol";
import "./interfaces/IPriceFeed.sol";
import "./interfaces/ILender.sol";

contract Leverager {
    function openShortPosition (
        IExchange exchange,
        ILender lender,
        IPriceFeed priceFeed,
        IERC20 depositToken, 
        uint depositAmount, 
        IERC20 principalToken, 
        uint principalAmount
    ) external {
        
    }
}
