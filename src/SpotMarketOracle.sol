// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.8.20;

import "./lib/OrderFees.sol";
import "./lib/DecimalMath.sol";
import "./interfaces/external/IExternalNode.sol";
import "./interfaces/external/ISpotMarketSystem.sol";
import "./interfaces/external/IAtomicOrderModule.sol";

contract SpotMarketOracle is IExternalNode {
    using DecimalMath for int256;
    using DecimalMath for uint256;

    using SafeCastI256 for int256;
    using SafeCastU256 for uint256;

    int256 public constant PRECISION = 18;

    address public immutable spotMarketAddress;

    constructor(address _spotMarketAddress) {
        spotMarketAddress = _spotMarketAddress;
    }

    function process(
        NodeOutput.Data[] memory,
        bytes memory parameters,
        bytes32[] memory runtimeKeys,
        bytes32[] memory runtimeValues
    ) external view returns (NodeOutput.Data memory nodeOutput) {
        (, uint128 marketId) = abi.decode(parameters, (address, uint128));

        uint256 synthAmount;
        bool useStrictStalenessTolerance;
        for (uint256 i = 0; i < runtimeKeys.length; i++) {
            if (runtimeKeys[i] == "size") {
                synthAmount = uint256(runtimeValues[i]);
            }

            if (runtimeKeys[i] == "useStrictStalenessTolerance") {
                useStrictStalenessTolerance = _bytes32ToBool(runtimeValues[i]);
            }
        }

        if (synthAmount == 0) {
            return NodeOutput.Data(int256(0), block.timestamp, 0, 0);
        }

        (uint256 synthValue, ) = ISpotMarketSystem(spotMarketAddress)
            .quoteSellExactIn(marketId, synthAmount, useStrictStalenessTolerance);

        return
            NodeOutput.Data(
                int256(synthValue.divDecimal(synthAmount)),
                block.timestamp,
                0,
                0
            );
    }

    function isValid(
        NodeDefinition.Data memory nodeDefinition
    ) external view returns (bool valid) {
        // Must have no parents
        if (nodeDefinition.parents.length > 0) {
            return false;
        }

        (, uint128 marketId) = abi.decode(
            nodeDefinition.parameters,
            (address, uint128)
        );

        address synthAddress = ISpotMarketSystem(spotMarketAddress).getSynth(
            marketId
        );

        //check if the market is registered
        if (synthAddress == address(0)) {
            return false;
        }

        return true;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IExternalNode).interfaceId ||
            interfaceId == this.supportsInterface.selector;
    }

    function _bytes32ToBool(bytes32 data) internal pure returns (bool) {
        // Define specific bytes32 values to represent true and false
        bytes32 trueValue = 0x0000000000000000000000000000000000000000000000000000000000000001;
        bytes32 falseValue = 0x0000000000000000000000000000000000000000000000000000000000000000;

        // Compare the input data with the values
        if (data == trueValue) {
            return true;
        } else if (data == falseValue) {
            return false;
        }

        // If the input data doesn't match either, you can handle it as needed.
        revert("Invalid input data");
    }
}
