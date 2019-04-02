pragma solidity >=0.5.0 <0.6.0;

import "ds-math/math.sol";
import "./interfaces/IWrappedEther.sol";
import "./interfaces/IExchange.sol";
import "./interfaces/ILender.sol";

contract Leverager is DSMath {

    struct Position {
        bytes32 agreementId;
        address owner;
        IERC20 heldToken;
        uint heldAmount;
        IERC20 principalToken;
        bool isClosed;
    }

    uint public positionsCount;
    mapping (uint => Position) public positions;

    IWrappedEther constant weth = IWrappedEther(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    event PositionOpened(
        address indexed owner,
        uint positionId,
        // IExchange exchange,
        // ILender lender,
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
    // addresses[2] = heldToken
    // addresses[3] = principalToken
    // uints[0] =     initialDepositAmount
    // uints[1] =     wadMaxBaseRatio
    // uints[2] =     maxIterations
    // uints[3] =     minCollateralAmount
    // 
    // arrays in params used to evade "stack too deep" during compilation
    function openShortPosition (
        address[4] calldata addresses,
        uint[4] calldata uints
    ) external payable {
        positionsCount = add(positionsCount, 1);
        uint positionId = positionsCount;
        uint recievedAmount = uints[0];
        uint heldAmount = uints[0];
        address heldToken = addresses[2];
        bytes32 agreementId;

        if(heldToken == address(0)){
            require(msg.value > 0, "Ether should be supplied");
            weth.deposit.value(msg.value)();
            heldToken = address(weth);
        } else {
            IERC20(heldToken).transferFrom(msg.sender, address(this), uints[0]);
        }

        for (uint i = 0; i < uints[2]; i++) {
            bool ok;
            bytes memory result;
            (ok, result) = addresses[0].delegatecall(
                abi.encodeWithSignature(
                    "supplyAndBorrow(bytes32,address,uint256,address,uint256)",
                    agreementId, addresses[3], uints[1], heldToken, recievedAmount
                )
            );
            require(ok, "supplyAndBorrow failed");
            agreementId = _bytesToBytes32(result, 0);
            uint principalAmount = uint(_bytesToBytes32(result, 32));
            
            (ok, result) = addresses[1].delegatecall(
                abi.encodeWithSignature(
                    "swap(address,uint256,address,uint256)",
                    addresses[3], principalAmount, heldToken, 0
                )
            );
            require(ok, "swap failed");
            recievedAmount = uint(_bytesToBytes32(result, 0));
            heldAmount += recievedAmount;

            emit Iteration(i, recievedAmount);

            if(recievedAmount < uints[3])
                break;
        }

        positions[positionId] = Position({
            agreementId: agreementId,
            owner: msg.sender,
            heldToken: IERC20(addresses[2]),
            heldAmount: heldAmount,
            principalToken: IERC20(addresses[3]),
            isClosed: false
        });

        emit PositionOpened(msg.sender, positionId, addresses[2], heldAmount, addresses[3], uints[1]);
    }
    
    // FOR DELEGATECALL ONLY!
    // addresses[0] = lender
    // addresses[1] = exchange
    // uints[0] =     positionId
    // uints[1] =     wadMaxBaseRatio
    // uints[2] =     maxIterations
    function closeShortPosition(
        address[2] calldata addresses,
        uint[3] calldata uints
    ) external {

        /*
        - get needed held token amount for swap
        - swap back to principal
        - repay principal
        - return collateral
        */
        Position storage position = positions[uints[0]];
        IERC20 heldToken = address(position.heldToken) == address(0) ? weth : position.heldToken;
        uint initWethBalance = weth.balanceOf(address(this));

        for (uint i = 0; i < uints[2]; i++) {
            // Should it include interest?
            uint owedAmountInPrincipalToken = ILender(addresses[0]).getOwedAmount(position.agreementId, position.principalToken);

            // TODO: EXCHANGE price feed
            uint owedAmountInHeldToken = IExchange(addresses[1]).convertAmountDst(heldToken, position.principalToken, owedAmountInPrincipalToken);
            uint heldTokenBalance = heldToken.balanceOf(address(this));

            // do we have enough tokens to repay all debt?
            if (owedAmountInHeldToken > heldTokenBalance) {
                bool ok;
                bytes memory result;
                (ok, result) = addresses[1].delegatecall(
                    abi.encodeWithSignature(
                        "swap(address,uint256,address,uint256)",
                        heldToken, heldTokenBalance, position.principalToken, 0
                    )
                );
                require(ok, "swap failed");
                uint recievedAmount = uint(_bytesToBytes32(result, 0));

                (ok, result) = addresses[0].delegatecall(
                    abi.encodeWithSignature(
                        "repayAndReturn(bytes32,address,uint256,address,uint256)",
                        position.agreementId, position.principalToken, recievedAmount, heldToken, uints[1]
                    )
                );
                require(ok, "supplyAndBorrow failed");
            } else {
                bool ok;
                bytes memory result;
                (ok, result) = addresses[1].delegatecall(
                    abi.encodeWithSignature(
                        "swap(address,uint256,address,uint256)",
                        heldToken, 0, position.principalToken, owedAmountInPrincipalToken
                    )
                );
                require(ok, "swap failed");

                (ok, result) = addresses[0].delegatecall(
                    abi.encodeWithSignature(
                        "repayAndReturn(bytes32,address,uint256,address,uint256)",
                        position.agreementId, position.principalToken, uint(-1), heldToken, uint(-1)
                    )
                );
                require(ok, "supplyAndBorrow failed");

                break;
            }
        }

        if (address(position.heldToken) == address(0)){
            uint finalWethBalance = weth.balanceOf(address(this));
            if (finalWethBalance > initWethBalance){
                weth.withdraw(sub(finalWethBalance, initWethBalance));
            }
        }

        positions[uints[0]].isClosed = true;
        
        emit PositionClosed(msg.sender, uints[0]);
    }

    function _bytesToBytes32(bytes memory source, uint offset) internal pure returns (bytes32 result) {
        if (source.length == 0)
            return 0x0;

        assembly {
            result := mload(add(source, add(32, offset)))
        }
    }
}
