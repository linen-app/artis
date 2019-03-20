pragma solidity >=0.5.0 <0.6.0;

import "./IERC20.sol";

contract ILender {
    function supplyAndBorrow(
        bytes32 agreementId,
        IERC20 principalToken,
        uint principalAmount,
        IERC20 collateralToken,
        uint collateralAmount) external returns (bytes32 _agreementId);

    function repayAndReturn(
        bytes32 agreementId,
        IERC20 principalToken,
        uint repaymentAmount,
        IERC20 collateralToken,
        uint withdrawAmount) external;

    function getOwedAmount(bytes32 agreementId, IERC20 principalToken) external returns (uint);
}
