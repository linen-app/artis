pragma solidity >=0.5.0 <0.6.0;

import "ds-math/math.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IExchange.sol";
import "./interfaces/IPriceFeed.sol";
import "./interfaces/ILender.sol";

contract Leverager is DSMath {

    struct Position {
        bytes32 agreementId;
        address owner;
        IERC20 heldToken;
        uint heldAmount;
        IERC20 principalToken;
    }

    uint public positionsCount;
    mapping (uint => Position) public positions;

    event PositionOpened(
        address indexed owner,
        uint positionId,
        // IExchange exchange,
        // ILender lender,
        // IPriceFeed priceFeed,
        address heldToken, 
        uint heldAmount, 
        address principalToken,
        uint wadMaxBaseRatio
    );

    event Iteration(uint num, uint recievedEthAmount);

    event PositionClosed(
        address indexed owner,
        uint positionId
    );

    // deposit token is a held token
    // FOR DELEGATECALL ONLY!
    // addresses[0] = lender
    // addresses[1] = exchange
    // addresses[2] = priceFeed
    // addresses[3] = heldToken
    // addresses[4] = principalToken
    // uints[0] =     initialDepositAmount
    // uints[1] =     wadMaxBaseRatio
    // uints[2] =     maxIterations
    // uints[3] =     minCollateralEthAmount
    // 
    // arrays in params used to evade "stack too deep" during compilation
    function openShortPosition (
        address[5] calldata addresses,
        uint[4] calldata uints
    ) external {
        positionsCount = add(positionsCount, 1);
        uint positionId = positionsCount;
        uint recievedAmount = uints[0];
        uint recievedEthAmount;
        uint heldAmount = uints[0];
        bytes32 agreementId;

        IERC20(addresses[3]).transferFrom(msg.sender, address(this), uints[0]);

        for (uint i = 0; i < uints[2]; i++) {
            uint principalAmount = calcPrincipal(IERC20(addresses[3]), recievedAmount, IERC20(addresses[4]), uints[1], IPriceFeed(addresses[2]));

            bool ok;
            bytes memory result;
            (ok, result) = addresses[0].delegatecall(
                abi.encodeWithSignature(
                    "supplyAndBorrow(bytes32,address,uint256,address,uint256)",
                    agreementId, addresses[4], principalAmount, addresses[3], recievedAmount
                )
            );
            require(ok, "supplyAndBorrow failed");
            agreementId = _bytesToBytes32(result);
            
            (ok, result) = addresses[1].delegatecall(
                abi.encodeWithSignature(
                    "swap(address,uint256,address,uint256)",
                    addresses[4], principalAmount, addresses[3], 0
                )
            );
            require(ok, "swap failed");
            recievedAmount = uint(_bytesToBytes32(result));
            recievedEthAmount = IPriceFeed(addresses[2]).convertAmountToETH(IERC20(addresses[3]), recievedAmount);
            heldAmount += recievedAmount;

            emit Iteration(i, recievedEthAmount);

            if(recievedEthAmount < uints[3])
                break;
        }

        positions[positionId] = Position({
            agreementId: agreementId,
            owner: msg.sender,
            heldToken: IERC20(addresses[3]),
            heldAmount: heldAmount,
            principalToken: IERC20(addresses[4])
        });

        emit PositionOpened(msg.sender, positionId, addresses[3], heldAmount, addresses[4], uints[1]);
    }
    
    // FOR DELEGATECALL ONLY!
    // addresses[0] = lender
    // addresses[1] = exchange
    // addresses[2] = priceFeed
    // uints[0] =     positionId
    // uints[1] =     wadMaxBaseRatio
    // uints[2] =     maxIterations
    function closeShortPosition(
        address[3] calldata addresses,
        uint[3] calldata uints
    ) external {

        /*
        - get needed held token amount for swap
        - swap back to principal
        - repay principal
        - return collateral
        */
        Position storage position = positions[uints[0]];

        for (uint i = 0; i < uints[2]; i++) {
            uint owedAmountInPrincipalToken = ILender(addresses[0]).getOwedAmount(position.agreementId, position.principalToken);

            // TODO: EXCHANGE price feed
            uint owedAmountInHeldToken = IPriceFeed(addresses[2]).convertAmount(position.principalToken, owedAmountInPrincipalToken, position.heldToken);
            uint heldTokenBalance = position.heldToken.balanceOf(address(this));

            // do we have enough tokens to repay all debt?
            if (owedAmountInHeldToken > heldTokenBalance) {
                bool ok;
                bytes memory result;
                (ok, result) = addresses[1].delegatecall(
                    abi.encodeWithSignature(
                        "swap(address,uint256,address,uint256)",
                        position.heldToken, heldTokenBalance, position.principalToken, 0
                    )
                );
                require(ok, "swap failed");
                uint recievedAmount = uint(_bytesToBytes32(result));

                // TODO: LENDER price feed
                uint withdrawalAmount = calcFreeCollateral(
                    position,
                    owedAmountInPrincipalToken,
                    recievedAmount,
                    uints[1],
                    IPriceFeed(addresses[2])
                );

                (ok, result) = addresses[0].delegatecall(
                    abi.encodeWithSignature(
                        "repayAndReturn(bytes32,address,uint256,address,uint256)",
                        position.agreementId, position.principalToken, recievedAmount, position.heldToken, withdrawalAmount
                    )
                );
                require(ok, "supplyAndBorrow failed");
            } else {
                bool ok;
                bytes memory result;
                (ok, result) = addresses[1].delegatecall(
                    abi.encodeWithSignature(
                        "swap(address,uint256,address,uint256)",
                        position.heldToken, 0, position.principalToken, owedAmountInPrincipalToken
                    )
                );
                require(ok, "swap failed");
                uint recievedAmount = uint(_bytesToBytes32(result));

                (ok, result) = addresses[0].delegatecall(
                    abi.encodeWithSignature(
                        "repayAndReturn(bytes32,address,uint256,address,uint256)",
                        position.agreementId, position.principalToken, uint(-1), position.heldToken, uint(-1)
                    )
                );
                require(ok, "supplyAndBorrow failed");

                break;
            }
        }

        delete positions[uints[0]];
        
        emit PositionClosed(msg.sender, uints[0]);
    }

    // determines how much we can borrow from a lender in order to maintain provided collateral ratio
    function calcPrincipal(
        IERC20 heldToken,
        uint depositAmount,
        IERC20 principalToken,
        uint wadMaxBaseRatio,
        IPriceFeed priceFeed
    ) public view returns (uint principalAmount){
        uint collateralETH = priceFeed.convertAmountToETH(heldToken, depositAmount);
        uint principalETH = wdiv(collateralETH, wadMaxBaseRatio);
        principalAmount = priceFeed.convertAmountFromETH(principalToken, principalETH);
    }

    // TODO: should we move it to the Lender?
    function calcFreeCollateral(
        Position storage position,
        uint currentDebt,
        uint repaymentAmountInPrincipalToken,
        uint wadMaxBaseRatio,
        IPriceFeed priceFeed
    ) internal view returns (uint freeCollateralAmount){
        // freeCollateral = heldCollateral - neededCollateral
        // neededCollateral = remainingPrincipal * collRatio
        // remainingPrincipal = currentPrincipal - repaymentAmount
        uint remainingDebt = sub(currentDebt, repaymentAmountInPrincipalToken);
        uint remainingDebtETH = priceFeed.convertAmountToETH(position.principalToken, remainingDebt);
        uint neededCollateralETH = wmul(remainingDebtETH, wadMaxBaseRatio);
        uint neededCollateral = priceFeed.convertAmountFromETH(position.heldToken, neededCollateralETH);
        freeCollateralAmount = sub(position.heldAmount, neededCollateral);
    }

    function _bytesToBytes32(bytes memory source) internal pure returns (bytes32 result) {
        if (source.length == 0)
            return 0x0;

        assembly {
            result := mload(add(source, 32))
        }
    }
}
