pragma solidity >=0.5.0 <0.6.0;

import "ds-math/math.sol";
import "../interfaces/IPriceFeed.sol";
import "../interfaces/Compound.sol";

contract CompoundPriceFeed is IPriceFeed, DSMath {

    PriceOracle public priceOracle;

    constructor (PriceOracle _priceOracle) public {
        // 0x02557a5E05DeFeFFD4cAe6D83eA3d173B272c904 - mainnet
        // 0xc2426fc73edab51e3870eca8101e17bf338d8f38 - kovan
        // 0x9680100ca7b3c07112a0b84ed8b7a23081d56118 - rinkeby
        priceOracle = _priceOracle;
    }

    function convertAmountToETH(IERC20 srcToken, uint srcAmount) external view returns (uint ethAmount) {
        uint price = priceOracle.getPrice(srcToken);
        ethAmount = wmul(srcAmount, price);
    }

    function convertAmountFromETH(IERC20 dstToken, uint ethAmount) external view returns (uint dstAmount) {
        uint price = priceOracle.getPrice(dstToken);
        dstAmount = wdiv(ethAmount, price);
    }
    
}