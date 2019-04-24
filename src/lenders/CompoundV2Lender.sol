pragma solidity >=0.5.0 <0.6.0;

import "ds-math/math.sol";
import "../interfaces/ILender.sol";
import "../libraries/ERC20Lib.sol";

interface ComptrollerInterface {
    function enterMarkets(CToken[] calldata cTokens) external returns (uint[] memory);
    function exitMarket(CToken cToken) external returns (uint);
}

contract CToken is IERC20 {
    /**
     * @notice Sender redeems cTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of cTokens to redeem into underlying
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeem(uint redeemTokens) external returns (uint);

    /**
     * @notice Sender redeems cTokens in exchange for a specified amount of underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemAmount The amount of underlying to redeem
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeemUnderlying(uint redeemAmount) external returns (uint);

        /**
      * @notice Sender borrows assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function borrow(uint borrowAmount) external returns (uint);

    function comptroller() external view returns (ComptrollerInterface) ;

    function borrowBalanceCurrent(address account) external returns (uint);

    function exchangeRateCurrent() external returns (uint);
}

contract CErc20 is CToken {
    /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param mintAmount The amount of the underlying asset to supply
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function mint(uint mintAmount) external returns (uint);

    /**
     * @notice Sender repays their own borrow
     * @param repayAmount The amount to repay
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function repayBorrow(uint repayAmount) external returns (uint);
}

contract CEther is CToken {

    /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Reverts upon any failure
     */
    function mint() external payable;

    /**
     * @notice Sender repays their own borrow
     * @dev Reverts upon any failure
     */
    function repayBorrow() external payable;
}

interface PriceOracle {
    /**
      * @notice Get the underlying price of a cToken asset
      * @param cToken The cToken to get the underlying price of
      * @return The underlying asset price mantissa (scaled by 1e18).
      *  Zero means the price is unavailable.
      */
    function getUnderlyingPrice(CToken cToken) external view returns (uint);
}

contract CompoundV2Lender is ILender, DSMath {
    using ERC20Lib for IERC20;

    address constant ethAddress = address(0);
    PriceOracle constant priceOracle = PriceOracle(0x7FDF35011220E2e3FE624F47A51e1D2B4CaBfB43);
    address constant cEtherAddress = 0xbED6D9490a7CD81fF0F06f29189160a9641a358F;

    event SupplyAndBorrow(address sender);
    event RepayAndReturn(address sender);

    function supplyAndBorrow(
        bytes32 agreementId,
        IERC20 principalToken,
        uint wadCollateralRatio,
        IERC20 collateralToken,
        uint collateralAmount)
    external payable returns (bytes32 _agreementId, uint _principalAmount) {
        (bool isEther, CToken collateralCToken) = _getCToken(collateralToken);

        if (isEther) {
            CEther cEther = CEther(address(collateralCToken));
            cEther.mint.value(collateralAmount)(); // TODO: add require()
        } else {
            collateralToken.ensureApproval(address(collateralCToken));
            CErc20 cErc20 = CErc20(address(collateralCToken));
            require(cErc20.mint(collateralAmount) == 0);
        }

        (,CToken principalCToken) = _getCToken(principalToken);

        CToken[] memory cTokens = new CToken[](2);
        ComptrollerInterface comptroller = principalCToken.comptroller();
        cTokens[0] = collateralCToken;
        cTokens[1] = principalCToken;
        comptroller.enterMarkets(cTokens);

        _principalAmount = _calcPrincipal(collateralCToken, collateralAmount, principalCToken, wadCollateralRatio);

        require(principalCToken.borrow(_principalAmount) == 0);

        emit SupplyAndBorrow(msg.sender);

        return (bytes32(uint256(address(this))), _principalAmount);
    }

    function repayAndReturn(
        bytes32 agreementId,
        IERC20 principalToken,
        uint repaymentAmount,
        IERC20 collateralToken,
        uint wadCollateralRatio)
    external {
        (bool isEther, CToken principalCToken) = _getCToken(principalToken);

        if (isEther) {
            CEther cEther = CEther(address(principalCToken));
            cEther.repayBorrow.value(repaymentAmount)(); // TODO: add require()
        } else {
            principalToken.ensureApproval(address(principalCToken));
            CErc20 cErc20 = CErc20(address(principalCToken));
            require(cErc20.repayBorrow(repaymentAmount) == 0);
        }

        (,CToken collateralCToken) = _getCToken(collateralToken);

        address user = address(uint256(agreementId));
        uint amountToFree = _calcFreeCollateral(user, collateralCToken, wadCollateralRatio, principalCToken);
        require(collateralCToken.redeemUnderlying(amountToFree) == 0);

        emit RepayAndReturn(msg.sender);
    }

    function getOwedAmount(bytes32 agreementId, IERC20 principalToken) external returns (uint) {
        (,CToken principalCToken) = _getCToken(principalToken);
        address addr = address(uint256(agreementId));
        return principalCToken.borrowBalanceCurrent(addr);
    }

    function _getCToken(IERC20 token) internal pure returns (bool isEther, CToken) {
        address addr = address(token);
        if (addr == ethAddress) {
            return (true,  CToken(cEtherAddress)); // CEther
        } else if (addr == 0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa) {
            return (false, CToken(0x2ACC448d73e8D53076731fEA2EF3fc38214d0A7d)); // cDAI
        } else {
            revert("Unknown token");
        }
    }

    // determines how much we can borrow from a lender in order to maintain provided collateral ratio
    function _calcPrincipal(
        CToken collateralCToken,
        uint collateralAmount,
        CToken principalCToken,
        uint wadMaxBaseRatio
    ) internal returns (uint principalAmount){
        uint collateralPrice = _getPrice(collateralCToken);
        uint principalPrice = _getPrice(principalCToken);

        uint collateralEth = wmul(collateralPrice, collateralAmount);
        uint principalEth = wdiv(collateralEth, wadMaxBaseRatio);
        principalAmount = wdiv(principalEth, principalPrice);
    }

    function _calcFreeCollateral(
        address user,
        CToken collateralCToken,
        uint wadCollateralRatio,
        CToken principalCToken
    ) internal returns (uint freeCollateralAmount) {
        uint collateralPrice = _getPrice(collateralCToken);
        uint collateralCTokenAmount = collateralCToken.balanceOf(user);
        uint collateralRate = collateralCToken.exchangeRateCurrent();
        uint heldCollateral = wmul(collateralCTokenAmount, collateralRate);
        uint heldCollateralETH = wmul(heldCollateral, collateralPrice);

        uint principalPrice = _getPrice(principalCToken);
        uint borrowBalance = principalCToken.borrowBalanceCurrent(user);
        uint borrowBalanceEth = wmul(borrowBalance, principalPrice);

        uint neededCollateralEth = wmul(borrowBalanceEth, wadCollateralRatio);
        uint freeCollateralEth = sub(heldCollateralETH, neededCollateralEth);

        freeCollateralAmount = wdiv(freeCollateralEth, collateralPrice);
    }

    function _getPrice(CToken cToken) internal view returns (uint) {
        if (address(cToken) == cEtherAddress) {
            return WAD;
        }

        return priceOracle.getUnderlyingPrice(cToken);
    }
    
}