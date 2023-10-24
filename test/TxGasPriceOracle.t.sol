// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "forge-std/Test.sol";
import "../src/TxGasPriceOracle.sol";

import "./mocks/MockSpotMarket.sol";
import "./mocks/MockOvmGasPriceOracle.sol";

contract TxGasPriceOracleTest is Test {
    TxGasPriceOracle txGasPriceOracle;

    function setUp() public {
        MockOvmGasPriceOracle mockOvmGasPriceOracle = new MockOvmGasPriceOracle();
        MockSpotMarket mockSpotMarket = new MockSpotMarket();
        txGasPriceOracle = new TxGasPriceOracle(
            address(mockSpotMarket), // goerli-base: 0x17633A63083dbd4941891F87Bdf31B896e91e2B9
            address(mockOvmGasPriceOracle), // goerli-ovm: 0x420000000000000000000000000000000000000F
            10,
            10,
            10,
            10,
            10,
            10,
            10,
            10
        );
    }

    function test_CallNode() public {
        NodeOutput.Data[] memory nullNodeOutputs = new NodeOutput.Data[](0);
        bytes memory parameters = abi.encode(address(0), uint128(1));
        bytes32[] memory runtimeKeys = new bytes32[](3);
        bytes32[] memory runtimeValues = new bytes32[](3);
        uint256 positionSize = 1000000000000000000;
        uint256 rateLimit = 100000000000000000000;
        uint256 numberOfUpdatedFeeds = 1;
        runtimeKeys[0] = bytes32("positionSize");
        runtimeValues[0] = bytes32(positionSize);
        runtimeKeys[1] = bytes32("rateLimit");
        runtimeValues[1] = bytes32(rateLimit);
        runtimeKeys[2] = bytes32("numberOfUpdatedFeeds");
        runtimeValues[2] = bytes32(numberOfUpdatedFeeds);

        NodeOutput.Data memory nodeOutput = txGasPriceOracle.process(
            nullNodeOutputs,
            parameters,
            runtimeKeys,
            runtimeValues
        );
        assertEq(nodeOutput.timestamp, block.timestamp);

        assertEq(nodeOutput.price, 3595);
    }
}
