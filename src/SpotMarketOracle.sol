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
        for (uint256 i = 0; i < runtimeKeys.length; i++) {
            if (runtimeKeys[i] == "size") {
                synthAmount = uint256(runtimeValues[i]);
                break;
            }
        }

        if (synthAmount == 0) {
            return NodeOutput.Data(int256(0), block.timestamp, 0, 0);
        }

        (uint256 synthValue, ) = ISpotMarketSystem(spotMarketAddress)
            .quoteSellExactIn(marketId, synthAmount);

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
    ) external pure returns (bool valid) {
        // Must have no parents
        if (nodeDefinition.parents.length > 0) {
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
}
