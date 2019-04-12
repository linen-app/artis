pragma solidity >=0.5.0 <0.6.0;

import "ds-math/math.sol";
import "../interfaces/ILender.sol";
import "../libraries/ERC20Lib.sol";

interface ComptrollerInterface {
    function enterMarkets(CToken[] calldata cTokens) external returns (uint[] memory);
    function exitMarket(CToken cToken) external returns (uint);
}

interface CToken {
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
    PriceOracle constant priceOracle = PriceOracle(0x04396A3e673980dAfa3BCC1EfD3632f075E57447);

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

        return (bytes32(uint256(msg.sender) << 96), _principalAmount);
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

    function _getCToken(IERC20 token) internal pure returns (bool isEther, CToken) {
        address addr = address(token);
        if (addr == ethAddress) {
            return (true,  CToken(0x8a9447df1FB47209D36204e6D56767a33bf20f9f)); // CEther
        } else if (addr == 0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa) {
            return (false, CToken(0xB5E5D0F8C0cbA267CD3D7035d6AdC8eBA7Df7Cdd)); // cDAI
        } else {
            revert("Unknown token");
        }
    }

    // determines how much we can borrow from a lender in order to maintain provided collateral ratio
    function _calcPrincipal(
        CToken collateralToken,
        uint collateralAmount,
        CToken principalToken,
        uint wadMaxBaseRatio
    ) internal returns (uint principalAmount){
        uint collateralPrice = priceOracle.getUnderlyingPrice(collateralToken);
        uint principalPrice = priceOracle.getUnderlyingPrice(principalToken);

        uint collateralEth = wmul(collateralPrice, collateralAmount);
        uint principalEth = wdiv(collateralEth, wadMaxBaseRatio);
        principalAmount = wdiv(principalEth, principalPrice);
    }
    
}