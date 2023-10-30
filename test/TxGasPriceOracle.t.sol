// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "forge-std/Test.sol";
import "../src/TxGasPriceOracle.sol";
import "./mocks/MockOvmGasPriceOracle.sol";

contract TxGasPriceOracleTest is Test {
    TxGasPriceOracle txGasPriceOracle;
    bytes parameters;

    uint256 private constant UNIT = 10 ** uint(18);

    uint256 private constant KIND_SETTLEMENT = 0;
    uint256 private constant KIND_LIQUIDATION_ELIGIBILITY = 1;
    uint256 private constant KIND_FLAG = 2;
    uint256 private constant KIND_LIQUIDATE = 3;

    function setUp() public {
        MockOvmGasPriceOracle mockOvmGasPriceOracle = new MockOvmGasPriceOracle();
        txGasPriceOracle = new TxGasPriceOracle(
            address(mockOvmGasPriceOracle) // goerli-ovm: 0x420000000000000000000000000000000000000F
        );

        parameters = abi.encode(
            address(0),
            uint256(15),
            uint256(20),
            uint256(60),
            uint256(70),
            uint256(100),
            uint256(110)
        );
    }

    function getRuntime(
        uint256 positionSize,
        uint256 rateLimit,
        uint256 numberOfUpdatedFeeds,
        uint256 executionKind
    )
        private
        pure
        returns (bytes32[] memory runtimeKeys, bytes32[] memory runtimeValues)
    {
        runtimeKeys = new bytes32[](4);
        runtimeValues = new bytes32[](4);
        runtimeKeys[0] = bytes32("positionSize");
        runtimeKeys[1] = bytes32("rateLimit");
        runtimeKeys[2] = bytes32("numberOfUpdatedFeeds");
        runtimeKeys[3] = bytes32("executionKind");
        runtimeValues[0] = bytes32(positionSize);
        runtimeValues[1] = bytes32(rateLimit);
        runtimeValues[2] = bytes32(numberOfUpdatedFeeds);
        runtimeValues[3] = bytes32(executionKind);
    }

    function test_Settlement() public {
        (
            bytes32[] memory runtimeKeys,
            bytes32[] memory runtimeValues
        ) = getRuntime(0, 0, 0, KIND_SETTLEMENT);
        NodeOutput.Data[] memory nullNodeOutputs = new NodeOutput.Data[](0);

        NodeOutput.Data memory nodeOutput = txGasPriceOracle.process(
            nullNodeOutputs,
            parameters,
            runtimeKeys,
            runtimeValues
        );
        assertEq(nodeOutput.timestamp, block.timestamp);

        assertEq(nodeOutput.price, 7192000);
    }

    function test_Liquidate() public {
        (
            bytes32[] memory runtimeKeys,
            bytes32[] memory runtimeValues
        ) = getRuntime(0, 0, 0, KIND_LIQUIDATE);
        NodeOutput.Data[] memory nullNodeOutputs = new NodeOutput.Data[](0);

        NodeOutput.Data memory nodeOutput = txGasPriceOracle.process(
            nullNodeOutputs,
            parameters,
            runtimeKeys,
            runtimeValues
        );
        assertEq(nodeOutput.timestamp, block.timestamp);

        assertEq(nodeOutput.price, 7485500);
    }

    function test_Flag_1_feed() public {
        uint256 numberOfUpdatedFeeds = 1;
        (
            bytes32[] memory runtimeKeys,
            bytes32[] memory runtimeValues
        ) = getRuntime(0, 0, numberOfUpdatedFeeds, KIND_FLAG);
        NodeOutput.Data[] memory nullNodeOutputs = new NodeOutput.Data[](0);

        NodeOutput.Data memory nodeOutput = txGasPriceOracle.process(
            nullNodeOutputs,
            parameters,
            runtimeKeys,
            runtimeValues
        );
        assertEq(nodeOutput.timestamp, block.timestamp);

        assertEq(nodeOutput.price, 7347500);
    }

    function test_Flag_2_feeds() public {
        uint256 numberOfUpdatedFeeds = 2;
        (
            bytes32[] memory runtimeKeys,
            bytes32[] memory runtimeValues
        ) = getRuntime(0, 0, numberOfUpdatedFeeds, KIND_FLAG);
        NodeOutput.Data[] memory nullNodeOutputs = new NodeOutput.Data[](0);

        NodeOutput.Data memory nodeOutput = txGasPriceOracle.process(
            nullNodeOutputs,
            parameters,
            runtimeKeys,
            runtimeValues
        );
        assertEq(nodeOutput.timestamp, block.timestamp);

        assertEq(nodeOutput.price, 7555000);
    }

    function test_Flag_5_feeds() public {
        uint256 numberOfUpdatedFeeds = 5;
        (
            bytes32[] memory runtimeKeys,
            bytes32[] memory runtimeValues
        ) = getRuntime(0, 0, numberOfUpdatedFeeds, KIND_FLAG);
        NodeOutput.Data[] memory nullNodeOutputs = new NodeOutput.Data[](0);

        NodeOutput.Data memory nodeOutput = txGasPriceOracle.process(
            nullNodeOutputs,
            parameters,
            runtimeKeys,
            runtimeValues
        );
        assertEq(nodeOutput.timestamp, block.timestamp);

        assertEq(nodeOutput.price, 8177500);
    }

    function test_RequiredMargin_5_feeds_1_step() public {
        uint256 positionSize = 10 * UNIT;
        uint256 rateLimit = 100 * UNIT;
        uint256 numberOfUpdatedFeeds = 5;
        (
            bytes32[] memory runtimeKeys,
            bytes32[] memory runtimeValues
        ) = getRuntime(
                positionSize,
                rateLimit,
                numberOfUpdatedFeeds,
                KIND_LIQUIDATION_ELIGIBILITY
            );
        NodeOutput.Data[] memory nullNodeOutputs = new NodeOutput.Data[](0);

        NodeOutput.Data memory nodeOutput = txGasPriceOracle.process(
            nullNodeOutputs,
            parameters,
            runtimeKeys,
            runtimeValues
        );
        assertEq(nodeOutput.timestamp, block.timestamp);

        assertEq(nodeOutput.price, 8523000);
    }

    function test_RequiredMargin_5_feeds_3_step() public {
        uint256 positionSize = 210 * UNIT;
        uint256 rateLimit = 100 * UNIT;
        uint256 numberOfUpdatedFeeds = 5;
        (
            bytes32[] memory runtimeKeys,
            bytes32[] memory runtimeValues
        ) = getRuntime(
                positionSize,
                rateLimit,
                numberOfUpdatedFeeds,
                KIND_LIQUIDATION_ELIGIBILITY
            );
        NodeOutput.Data[] memory nullNodeOutputs = new NodeOutput.Data[](0);

        NodeOutput.Data memory nodeOutput = txGasPriceOracle.process(
            nullNodeOutputs,
            parameters,
            runtimeKeys,
            runtimeValues
        );
        assertEq(nodeOutput.timestamp, block.timestamp);

        assertEq(nodeOutput.price, 9214000);
    }
}
