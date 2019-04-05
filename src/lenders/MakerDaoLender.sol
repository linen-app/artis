pragma solidity >=0.5.0 <0.6.0;

import "ds-math/math.sol";
import "../interfaces/ILender.sol";
import "../interfaces/IExchange.sol";
import "../interfaces/IWrappedEther.sol";
import "../libraries/ERC20Lib.sol";

interface DSValue {
    function peek() external view returns (bytes32, bool);
}

interface Vox {
    function par() external returns (uint);
}

interface ISaiTub {
    function open() external returns (bytes32 cup);
    function join(uint wad) external;
    function exit(uint wad) external;
    function lock(bytes32 cup, uint wad) external;
    function free(bytes32 cup, uint wad) external;
    function draw(bytes32 cup, uint wad) external;
    function wipe(bytes32 cup, uint wad) external;
    function shut(bytes32 cup) external;
    function per() external view returns (uint ray);
    function tag() external view returns (uint wad);
    function bid(uint wad) external view returns (uint);
    
    function tab(bytes32 cup) external returns (uint);
    function rap(bytes32 cup) external returns (uint);
    function ink(bytes32 cup) external view returns (uint);
    function mat() external view returns (uint);    // Liquidation ratio
}

contract MakerDaoLender is ILender, DSMath {
    using ERC20Lib for IERC20;

    ISaiTub constant saiTub = ISaiTub(0x448a5065aeBB8E423F0896E6c5D525C040f59af3);
    Vox constant vox = Vox(0x9B0F70Df76165442ca6092939132bBAEA77f2d7A);
    IWrappedEther constant weth = IWrappedEther(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant peth = IERC20(0xf53AD2c6851052A81B42133467480961B2321C09);
    IERC20 constant dai = IERC20(0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359);
    IERC20 constant mkr = IERC20(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);
    DSValue constant pep = DSValue(0x99041F808D598B782D5a3e498681C2452A31da08);
    IExchange constant exchange = IExchange(0x238A19577695384222548BA1cD1CF65D48d027A3);

    address constant ethAddress = address(0);

    event SupplyAndBorrow(address sender);
    event RepayAndReturn(address sender);

    function supplyAndBorrow(
        bytes32 agreementId,
        IERC20 principalToken,
        uint wadCollateralRatio,
        IERC20 collateralToken,
        uint collateralAmount)
    external payable returns (bytes32 _agreementId, uint _principalAmount) {
        require(address(collateralToken) == ethAddress);
        require(address(principalToken) == address(dai));

        _agreementId = agreementId;
        if (_agreementId == 0) {
            _agreementId = saiTub.open();
        }

        weth.deposit.value(collateralAmount)();
        weth.ensureApproval(address(saiTub));
        uint pethAmount = _pethForWeth(collateralAmount);
        saiTub.join(pethAmount);
        peth.ensureApproval(address(saiTub));
        saiTub.lock(_agreementId, pethAmount);

        _principalAmount = _calcPrincipal(pethAmount, wadCollateralRatio);
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
        require(address(collateralToken) == ethAddress);
        require(address(principalToken) == address(dai));

        dai.ensureApproval(address(saiTub));
        mkr.ensureApproval(address(saiTub));
        uint _daiAmount = repaymentAmount;
        bool repayAll = repaymentAmount == uint(-1);
        if (repayAll) {
            // repay all outstanding debt
            _daiAmount = saiTub.tab(agreementId);
        }
        uint govFeeAmount = _calcGovernanceFee(agreementId, _daiAmount);

        uint mkrBalance = mkr.balanceOf(address(this));
        uint spentDai;
        if (mkrBalance < govFeeAmount){
            uint neededMkr = sub(govFeeAmount, mkrBalance);
            (bool ok, bytes memory result) = address(exchange).delegatecall(
                abi.encodeWithSignature(
                    "swap(address,uint256,address,uint256)",
                    address(dai), 0, address(mkr), neededMkr
                )
            );
            require(ok, "swap failed");
            spentDai = uint(_bytesToBytes32(result, 0));
        }
        uint remainingDai = repayAll ? _daiAmount : sub(_daiAmount, spentDai);
        saiTub.wipe(agreementId, remainingDai);

        uint pethAmount;
        if (wadCollateralRatio == uint(-1)) {
            // return all collateral
            pethAmount = saiTub.ink(agreementId);
        } else {
            pethAmount = _calcFreeCollateral(agreementId, wadCollateralRatio);
        }
        saiTub.free(agreementId, pethAmount);
        peth.ensureApproval(address(saiTub));
        saiTub.exit(pethAmount);

        weth.withdraw(saiTub.bid(pethAmount));

        emit RepayAndReturn(msg.sender);
    }

    function getOwedAmount(bytes32 agreementId, IERC20 principalToken) external returns (uint) {
        require(address(principalToken) == address(dai));

        uint daiOwed = saiTub.tab(agreementId);
        uint mkrBalance = mkr.balanceOf(address(this));
        uint govFeeAmount = _calcGovernanceFee(agreementId, daiOwed);

        if (mkrBalance >= govFeeAmount)
            return daiOwed;

        uint daiFeeAmount = exchange.convertAmountDst(dai, mkr, sub(govFeeAmount, mkrBalance));
        return add(daiOwed, daiFeeAmount);
    }

    function _calcGovernanceFee(bytes32 agreementId, uint daiAmount) internal returns (uint mkrFeeAmount) {
        uint daiFeeAmount = rmul(daiAmount, rdiv(saiTub.rap(agreementId), saiTub.tab(agreementId)));
        (bytes32 val, bool ok) = pep.peek();
        require(ok && val != 0, 'Unable to get mkr rate');

        return wdiv(daiFeeAmount, uint(val));
    }

    // determines how much we can borrow from a lender in order to maintain provided collateral ratio
    function _calcPrincipal(
        uint pethAmount,
        uint wadMaxBaseRatio
    ) internal returns (uint principalAmount){
        uint collateralRef = rmul(saiTub.tag(), pethAmount);
        uint principalRef = wdiv(collateralRef, wadMaxBaseRatio);
        principalAmount = rdiv(principalRef, vox.par());
    }

    function _calcFreeCollateral(
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

    function _pethForWeth(uint wethAmount) internal view returns (uint) {
        uint pethAmount = rdiv(wethAmount, saiTub.per());
        return sub(pethAmount, 1); // we subtract 1 from computed PETH value because there is a problems with fixed-pointed values division 
    }

    function _bytesToBytes32(bytes memory source, uint offset) internal pure returns (bytes32 result) {
        if (source.length == 0)
            return 0x0;

        assembly {
            result := mload(add(source, add(32, offset)))
        }
    }
}