pragma solidity >=0.5.0 <0.6.0;

import "../interfaces/IERC20.sol";

library ERC20Lib {
    function ensureApproval(IERC20 token, address spender) internal {
        if (token.allowance(address(this), spender) != uint(-1)) {
            require(token.approve(spender, uint(-1)));
        }
    }
}