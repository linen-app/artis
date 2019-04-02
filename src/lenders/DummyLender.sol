pragma solidity >=0.5.0 <0.6.0;

import "../interfaces/ILender.sol";

contract DummyLender is ILender {

    event SupplyAndBorrow(address sender);
    event RepayAndReturn(address sender);

    function supplyAndBorrow(
        bytes32 agreementId,
        IERC20 principalToken,
        uint principalAmount,
        IERC20 collateralToken,
        uint collateralAmount)
    external payable returns (bytes32 _agreementId, uint _principalAmount) {
        emit SupplyAndBorrow(msg.sender);

        return (0, 0);
    }

    function repayAndReturn(
        bytes32 agreementId,
        IERC20 principalToken,
        uint repaymentAmount,
        IERC20 collateralToken,
        uint withdrawAmount)
    external {
        emit RepayAndReturn(msg.sender);
    }

    function getOwedAmount(bytes32 agreementId, IERC20 principalToken) external returns (uint) {
        return 0;
    }
    
}