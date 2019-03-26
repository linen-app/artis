pragma solidity >=0.5.0 <0.6.0;

import "../interfaces/ILender.sol";
import "../libraries/ERC20Lib.sol";

contract MoneyMarket {
    function supply(IERC20 asset, uint amount) public returns (uint);
    function withdraw(IERC20 asset, uint requestedAmount) public returns (uint);
    function borrow(IERC20 asset, uint amount) public returns (uint);
    function repayBorrow(IERC20 asset, uint amount) public returns (uint);
    function getAccountLiquidity(address account) view public returns (int);
    function getSupplyBalance(address account, IERC20 asset) view public returns (uint);
    function getBorrowBalance(address account, IERC20 asset) view public returns (uint);
}

contract CompoundLender is ILender {
    using ERC20Lib for IERC20;

    // 0x3FDA67f7583380E67ef93072294a7fAc882FD7E7 - mainnet
    // 0x75dc9d89d6e8b9e3790de5c1ae291334db5ddc45 - kovan
    // 0x61bbd7Bd5EE2A202d7e62519750170A52A8DFD45 - rinkeby
    
    MoneyMarket constant compound = MoneyMarket(0x3FDA67f7583380E67ef93072294a7fAc882FD7E7);

    event SupplyAndBorrow(address sender);
    event RepayAndReturn(address sender);

    function supplyAndBorrow(
        bytes32 agreementId,
        IERC20 principalToken,
        uint principalAmount,
        IERC20 collateralToken,
        uint collateralAmount
    ) external returns (bytes32 _agreementId) {
        collateralToken.ensureApproval(address(compound));
        require(compound.supply(collateralToken, collateralAmount) == 0, "compound.supply error");
        require(compound.borrow(principalToken, principalAmount) == 0, "compound.borrow error");

        emit SupplyAndBorrow(msg.sender);

        return bytes32(uint(msg.sender));
    }

    function repayAndReturn(
        bytes32 agreementId,
        IERC20 principalToken,
        uint repaymentAmount,
        IERC20 collateralToken,
        uint withdrawAmount
    ) external {
        principalToken.ensureApproval(address(compound));
        require(compound.repayBorrow(principalToken, repaymentAmount) == 0, "compound.repayBorrow error");
        require(compound.withdraw(collateralToken, withdrawAmount) == 0, "compound.withdraw error");

        emit RepayAndReturn(msg.sender);
    }

    function getOwedAmount(bytes32 agreementId, IERC20 principalToken) external returns (uint) {
        compound.getBorrowBalance(address(uint(agreementId)), principalToken);
    }
}