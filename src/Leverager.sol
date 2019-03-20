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
        IERC20 heldToken, 
        uint depositAmount, 
        IERC20 principalToken,
        uint wadMaxBaseRatio
    );

    event PositionClosed(
        address indexed owner
    );

    // deposit token is a held token
    // FOR DELEGATECALL ONLY!
    function openShortPosition (
        IExchange exchange,
        ILender lender,
        IPriceFeed priceFeed,
        IERC20 heldToken, 
        uint depositAmount, 
        IERC20 principalToken,
        uint wadMaxBaseRatio
    ) external {
        positionsCount = add(positionsCount, 1);
        uint positionId = positionsCount;
        
        uint principalAmount = calcPrincipal(heldToken, depositAmount, principalToken, wadMaxBaseRatio, priceFeed);

        heldToken.transferFrom(msg.sender, address(this), depositAmount);

        (bool supplyAndBorrowOk, bytes memory supplyAndBorrowRes) = address(lender).delegatecall(
            abi.encodeWithSignature(
                "supplyAndBorrow(bytes32,address,uint256,address,uint256)",
                0, principalToken, principalAmount, heldToken, depositAmount
            )
        );
        require(supplyAndBorrowOk);
        bytes32 agreementId = _bytesToBytes32(supplyAndBorrowRes, 0);
        
        (bool swapOk, bytes memory swapRes) = address(exchange).delegatecall(
            abi.encodeWithSignature(
                "swap(address,uint256,address,uint256)",
                principalToken, principalAmount, heldToken, 0
            )
        );
        require(swapOk);
        uint recievedAmount = uint(_bytesToBytes32(swapRes, 0));

        uint heldAmount = add(depositAmount, recievedAmount);
        positions[positionId] = Position({
            agreementId: agreementId,
            owner: msg.sender,
            heldToken: heldToken,
            heldAmount: heldAmount,
            principalToken: principalToken
        });

        emit PositionOpened(msg.sender, positionId, heldToken, depositAmount, principalToken, wadMaxBaseRatio);
    }
    
    // IMPLEMENTATION IS NOT WORKING
    // FOR DELEGATECALL ONLY!
    // function closeShortPosition(
    //     bytes32 positionId,
    //     IExchange exchange,
    //     ILender lender
    // ) external {
    //     require(positions[positionId].owner == msg.sender, "The specified position doesn't exist or belongs to a different owner");
    //     Position storage position = positions[positionId];

    //     uint owedAmount = lender.getOwedAmount(position.agreementId, position.principalToken);

    //     exchange.swap(position.heldToken, 0, position.principalToken, owedAmount);

    //     lender.repayAndReturn(position.agreementId, position.principalToken, uint(-1), position.heldToken, uint(-1));

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

    function _bytesToBytes32(bytes memory b, uint offset) internal pure returns (bytes32) {
        bytes32 out;

        for (uint i = 0; i < 32; i++) {
            out |= bytes32(b[offset + i] & 0xFF) >> (i * 8);
        }
        return out;
    }
}
