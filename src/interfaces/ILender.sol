pragma solidity >=0.4.21 <0.6.0;

import "./IERC20.sol";

contract ILender {
    function borrow(IERC20 principalToken, uint principalAmount, IERC20 collateralToken, uint collateralAmount) external;
}
