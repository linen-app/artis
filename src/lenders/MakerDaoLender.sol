pragma solidity >=0.5.0 <0.6.0;

import "ds-math/math.sol";
import "../interfaces/ILender.sol";
import "../libraries/ERC20Lib.sol";

interface DSValue {
    function peek() external view returns (bytes32, bool);
}

interface Vox {
    function par() external returns (uint);
}

interface ISaiTub {
    function vox() external view returns (Vox);     // Target price feed

    function sai() external view returns (IERC20);  // Stablecoin
    function sin() external view returns (IERC20);  // Debt (negative sai)
    function skr() external view returns (IERC20);  // Abstracted collateral
    function gem() external view returns (IERC20);  // Underlying collateral
    function gov() external view returns (IERC20);  // Governance token

    function open() external returns (bytes32 cup);
    function join(uint wad) external;
    function exit(uint wad) external;
    function give(bytes32 cup, address guy) external;
    function lock(bytes32 cup, uint wad) external;
    function free(bytes32 cup, uint wad) external;
    function draw(bytes32 cup, uint wad) external;
    function wipe(bytes32 cup, uint wad) external;
    function shut(bytes32 cup) external;
    function per() external view returns (uint ray);
    function tag() external view returns (uint wad);
    function lad(bytes32 cup) external view returns (address);
    
    function tab(bytes32 cup) external returns (uint);
    function rap(bytes32 cup) external returns (uint);
    function ink(bytes32 cup) external view returns (uint);
    function mat() external view returns (uint);    // Liquidation ratio
    function fee() external view returns (uint);    // Governance fee
    function pep() external view returns (DSValue); // Governance price feed
    function cap() external view returns (uint); // Debt ceiling

    function cups(bytes32) external view returns (address, uint, uint, uint);
}

contract MakerDaoLender is ILender, DSMath {
    using ERC20Lib for IERC20;

    // 0x448a5065aeBB8E423F0896E6c5D525C040f59af3 - mainnet

    ISaiTub constant saiTub = ISaiTub(0x448a5065aeBB8E423F0896E6c5D525C040f59af3);
    Vox constant vox = Vox(0x9B0F70Df76165442ca6092939132bBAEA77f2d7A);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant peth = IERC20(0xf53AD2c6851052A81B42133467480961B2321C09);
    IERC20 constant dai = IERC20(0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359);
    IERC20 constant mkr = IERC20(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);

    event SupplyAndBorrow(address sender);
    event RepayAndReturn(address sender);

    function supplyAndBorrow(
        bytes32 agreementId,
        IERC20 principalToken,
        uint wadCollateralRatio,
        IERC20 collateralToken,
        uint collateralAmount)
    external returns (bytes32 _agreementId, uint _principalAmount) {
        require(address(collateralToken) == address(weth));
        require(address(principalToken) == address(dai));

        _agreementId = agreementId;
        if (_agreementId == 0) {
            _agreementId = saiTub.open();
        }

        weth.ensureApproval(address(saiTub));
        uint pethAmount = pethForWeth(collateralAmount);
        saiTub.join(pethAmount);
        peth.ensureApproval(address(saiTub));
        saiTub.lock(_agreementId, pethAmount);

        _principalAmount = calcPrincipal(pethAmount, wadCollateralRatio);
        saiTub.draw(_agreementId, _principalAmount);

        emit SupplyAndBorrow(msg.sender);
    }

    function repayAndReturn(
        bytes32 agreementId,
        IERC20 principalToken,
        uint repaymentAmount,
        IERC20 collateralToken,
        uint wadCollateralRatio)
    external {
        require(address(collateralToken) == address(weth));
        require(address(principalToken) == address(dai));

        dai.ensureApproval(address(saiTub));
        mkr.ensureApproval(address(saiTub));
        uint _daiAmount = repaymentAmount;
        if (_daiAmount == uint(- 1)) {
            // repay all outstanding debt
            _daiAmount = saiTub.tab(agreementId);
        }
        // uint govFeeAmount = _calcGovernanceFee(agreementId, _daiAmount);
        // _handleGovFee(govFeeAmount, payFeeInDai);
        saiTub.wipe(agreementId, _daiAmount);


        uint pethAmount;
        if (wadCollateralRatio == uint(-1)) {
            // return all collateral
            pethAmount = saiTub.ink(agreementId);
        } else {
            pethAmount = calcFreeCollateral(agreementId, wadCollateralRatio);
        }
        saiTub.free(agreementId, pethAmount);
        peth.ensureApproval(address(saiTub));
        saiTub.exit(pethAmount);

        emit RepayAndReturn(msg.sender);
    }

    function getOwedAmount(bytes32 agreementId, IERC20 principalToken) external returns (uint) {
        require(address(principalToken) == address(saiTub.sai()));

        return add(saiTub.rap(agreementId), saiTub.tab(agreementId));
    }

    // determines how much we can borrow from a lender in order to maintain provided collateral ratio
    function calcPrincipal(
        uint pethAmount,
        uint wadMaxBaseRatio
    ) internal returns (uint principalAmount){
        uint collateralRef = rmul(saiTub.tag(), pethAmount);
        uint principalRef = wdiv(collateralRef, wadMaxBaseRatio);
        principalAmount = rdiv(principalRef, vox.par());
    }

    function calcFreeCollateral(
        bytes32 agreementId,
        uint wadCollateralRatio
    ) internal returns (uint freePethAmount) {
        uint collPrice = saiTub.tag();
        uint heldCollateralRef = rmul(collPrice, saiTub.ink(agreementId));
        uint effectiveDebtRef = rmul(vox.par(), saiTub.tab(agreementId));
        uint neededCollateralRef = wmul(effectiveDebtRef, wadCollateralRatio);
        uint freeCollateralRef = sub(heldCollateralRef, neededCollateralRef);
        freePethAmount = rdiv(freeCollateralRef, collPrice);
    }

    function pethForWeth(uint wethAmount) internal view returns (uint) {
        return rdiv(wethAmount, saiTub.per());
    }
}