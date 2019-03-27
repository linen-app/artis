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

    event SupplyAndBorrow(address sender);
    event RepayAndReturn(address sender);

    function supplyAndBorrow(
        bytes32 agreementId,
        IERC20 principalToken,
        uint principalAmount,
        IERC20 collateralToken,
        uint collateralAmount)
    external returns (bytes32 _agreementId) {
        IERC20 weth = saiTub.gem();
        IERC20 peth = saiTub.skr();
        IERC20 dai = saiTub.sai();

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
        saiTub.draw(_agreementId, principalAmount);

        emit SupplyAndBorrow(msg.sender);
    }

    function repayAndReturn(
        bytes32 agreementId,
        IERC20 principalToken,
        uint repaymentAmount,
        IERC20 collateralToken,
        uint wadNewCollateralRatio)
    external {
        IERC20 weth = saiTub.gem();
        IERC20 peth = saiTub.skr();
        IERC20 dai = saiTub.sai();
        IERC20 mkr = saiTub.gov();

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
        if (wadNewCollateralRatio == uint(-1)) {
            // return all collateral
            pethAmount = saiTub.ink(agreementId);
        } else {
            pethAmount = calcFreeCollateral(agreementId, wadNewCollateralRatio);
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

    function calcFreeCollateral(
        bytes32 agreementId,
        uint wadNewCollateralRatio
    ) internal returns (uint freeCollateralAmount) {
        uint collPrice = saiTub.tag();
        uint heldCollateralRef = rmul(collPrice, saiTub.ink(agreementId));
        uint effectiveDebtRef = rmul(saiTub.vox().par(), saiTub.tab(agreementId));
        uint neededCollateralRef = wmul(effectiveDebtRef, wadNewCollateralRatio);
        uint freeCollateralRef = sub(heldCollateralRef, neededCollateralRef);
        freeCollateralAmount = rdiv(freeCollateralRef, collPrice);
    }

    function pethForWeth(uint wethAmount) internal view returns (uint) {
        return rdiv(wethAmount, saiTub.per());
    }
}