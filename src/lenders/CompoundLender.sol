pragma solidity >=0.5.0 <0.6.0;

import "../interfaces/ILender.sol";
import "../interfaces/Compound.sol";

contract CompoundLender is ILender {
    // 0x3fda67f7583380e67ef93072294a7fac882fd7e7 - mainnet
    // 0x75dc9d89d6e8b9e3790de5c1ae291334db5ddc45 - kovan
    // 0x61bbd7Bd5EE2A202d7e62519750170A52A8DFD45 - rinkeby
    
    MoneyMarket constant compound = MoneyMarket(0x61bbd7Bd5EE2A202d7e62519750170A52A8DFD45);

    event SupplyAndBorrow(address sender);
    event RepayAndReturn(address sender);

    function supplyAndBorrow(
        bytes32 agreementId,
        IERC20 principalToken,
        uint principalAmount,
        IERC20 collateralToken,
        uint collateralAmount
    ) external returns (bytes32 _agreementId) {
        _ensureApproval(collateralToken, address(compound));
        compound.supply(collateralToken, collateralAmount);
        compound.borrow(principalToken, principalAmount);

        emit SupplyAndBorrow(msg.sender);

        return bytes32(uint(msg.sender));
    }

    function repayAndReturn(
        bytes32 agreementId,
        IERC20 principalToken,
        uint repaymentAmount,
        IERC20 collateralToken,
        uint withdrawAmount
    ) external {
        _ensureApproval(principalToken, address(compound));
        compound.repayBorrow(principalToken, repaymentAmount);
        compound.withdraw(collateralToken, withdrawAmount);

        emit RepayAndReturn(msg.sender);
    }

    function getOwedAmount(bytes32 agreementId, IERC20 principalToken) external returns (uint) {
        compound.getBorrowBalance(address(uint(agreementId)), principalToken);
    }

    function _ensureApproval(IERC20 token, address spender) internal {
        if (token.allowance(address(this), spender) != uint(-1)) {
            require(token.approve(spender, uint(-1)));
        }
    }
}