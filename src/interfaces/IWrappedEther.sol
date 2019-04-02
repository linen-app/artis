pragma solidity >=0.5.0 <0.6.0;

import "./IERC20.sol";

contract IWrappedEther is IERC20 {
    function deposit() external payable;
    function withdraw(uint amount) external;
}