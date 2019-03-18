pragma solidity ^0.5.2;

import "ds-test/test.sol";

import "./Leverager.sol";

contract LeveragerTest is DSTest {
    Leverager leverager;

    function setUp() public {
        leverager = new Leverager();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
