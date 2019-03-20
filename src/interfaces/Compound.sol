pragma solidity >=0.5.0 <0.6.0;

import "./IERC20.sol";

contract PriceOracle {
    /**
      * @notice retrieves price of an asset
      * @dev function to get price for an asset
      * @param asset Asset for which to get the price
      * @return uint mantissa of asset price (scaled by 1e18) or zero if unset or contract paused
      */
    function getPrice(IERC20 asset) public view returns (uint);
}

contract MoneyMarket {
    function supply(IERC20 asset, uint amount) public returns (uint);
    function withdraw(IERC20 asset, uint requestedAmount) public returns (uint);
    function borrow(IERC20 asset, uint amount) public returns (uint);
    function repayBorrow(IERC20 asset, uint amount) public returns (uint);
    function getAccountLiquidity(address account) view public returns (int);
    function getSupplyBalance(address account, IERC20 asset) view public returns (uint);
    function getBorrowBalance(address account, IERC20 asset) view public returns (uint);
}