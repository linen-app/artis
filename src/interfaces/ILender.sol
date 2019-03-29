pragma solidity >=0.5.0 <0.6.0;

import "./IERC20.sol";

interface ILender {
    function supplyAndBorrow(
        bytes32 agreementId,
        IERC20 principalToken,
        uint wadCollateralRatio,
        IERC20 collateralToken,
        uint collateralAmount) external returns (bytes32 _agreementId, uint _principalAmount);

    // repaymentAmount: specify uint(-1) to repay all
    // wadNewCollateralRatio: specify uint(-1) to return all 
    function repayAndReturn(
        bytes32 agreementId,
        IERC20 principalToken,
        uint repaymentAmount,
        IERC20 collateralToken,
        uint wadCollateralRatio) external;

    function getOwedAmount(bytes32 agreementId, IERC20 principalToken) external returns (uint);
}
