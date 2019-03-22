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
        address heldToken;
        uint heldAmount;
        address principalToken;
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
        address indexed owner
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
            heldToken: addresses[3],
            heldAmount: heldAmount,
            principalToken: addresses[4]
        });

        emit PositionOpened(msg.sender, positionId, addresses[3], heldAmount, addresses[4], uints[1]);
    }
    
    // FOR DELEGATECALL ONLY!
    // function closeShortPosition(
    //     bytes32 positionId,
    //     address exchange,
    //     address lender,
    //     uint maxIterations
    // ) external {
    //     Position storage position = positions[positionId];

    //     for (var i = 0; i < maxIterations; i++) {
    //         uint owedAmount = lender.getOwedAmount(position.agreementId, position.principalToken);

    //         bool ok;
    //         bytes memory result;
    //         (ok, result) = exchange.delegatecall(
    //             abi.encodeWithSignature(
    //                 "swap(address,uint256,address,uint256)",
    //                 position.heldToken, 0, position.principalToken, owedAmount
    //             )
    //         );
    //         require(ok, "swap failed");
    //         recievedAmount = uint(_bytesToBytes32(result));

    //         (ok, result) = lender.delegatecall(
    //             abi.encodeWithSignature(
    //                 "repayAndReturn(bytes32,address,uint256,address,uint256)",
    //                 position.agreementId, position.principalToken, uint(-1), position.heldToken, uint(-1)
    //             )
    //         );
    //         require(ok, "supplyAndBorrow failed");
    //     }

    //     delete positions[positionId];
        
    //     emit PositionClosed(msg.sender);
    // }

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

    function _bytesToBytes32(bytes memory source) internal pure returns (bytes32 result) {
        if (source.length == 0)
            return 0x0;

        assembly {
            result := mload(add(source, 32))
        }
    }
}
