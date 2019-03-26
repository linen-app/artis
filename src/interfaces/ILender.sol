pragma solidity >=0.5.0 <0.6.0;

import "./IERC20.sol";

interface ILender {
    function supplyAndBorrow(
        bytes32 agreementId,
        IERC20 principalToken,
        uint principalAmount,
        IERC20 collateralToken,
        uint collateralAmount) external returns (bytes32 _agreementId);

    // repaymentAmount: specify uint(-1) to repay all
    // withdrawAmount: specify uint(-1) to return all 
    function repayAndReturn(
        bytes32 agreementId,
        IERC20 principalToken,
        uint repaymentAmount,
        IERC20 collateralToken,
        uint withdrawAmount) external;

    function getOwedAmount(bytes32 agreementId, IERC20 principalToken) external returns (uint);
}
