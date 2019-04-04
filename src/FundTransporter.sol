pragma solidity 0.5.0;

contract FundTransporter {
    
    function transferEther(address to, uint256 amount) {
        msg.sender.transfer(amount);
    }
}