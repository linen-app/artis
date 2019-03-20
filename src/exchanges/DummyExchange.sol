pragma solidity >=0.5.0 <0.6.0;

import "../interfaces/IExchange.sol";

contract DummyExchange is IExchange {
    
    event Swap();

    function swap(IERC20 srcToken, uint srcAmount, IERC20 dstToken, uint dstAmount) external returns (uint actualAmount) {
        emit Swap();
        return 2;
    }
}
