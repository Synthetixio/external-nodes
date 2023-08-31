// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

// TODO: Import via npm after next release
import "./lib/DecimalMath.sol";
import "./lib/SafeCast.sol";
import "./lib/NodeOutput.sol";
import "./lib/NodeDefinition.sol";
import "./interfaces/external/IExternalNode.sol";
import "./interfaces/external/IPyth.sol";
import "./interfaces/external/IERC7412.sol";

contract PythERC7412Node is IExternalNode, IERC7412 {
    using DecimalMath for int64;
    using SafeCastI256 for int256;

    int256 public constant PRECISION = 18;
    address public immutable pythAddress;
    uint256 public lastFulfillmentBlockNumber;

    constructor(address _pythAddress) {
        pythAddress = _pythAddress;
    }

    function process(
        NodeOutput.Data[] memory,
        bytes memory parameters
    ) external view returns (NodeOutput.Data memory nodeOutput) {
        (bytes32 priceFeedId, uint256 stalenessTolerance) = abi.decode(
            parameters,
            (bytes32, uint256)
        );

        if(lastFulfillmentBlockNumber == block.number) {
            IPyth pyth = IPyth(pythAddress);
            PythStructs.Price memory pythData = pyth.getPriceUnsafe(priceFeedId);

            int256 factor = PRECISION + pythData.expo;
            int256 price = factor > 0
                ? pythData.price.upscale(factor.toUint())
                : pythData.price.downscale((-factor).toUint());

            if (block.timestamp - pythData.publishTime <= stalenessTolerance) {
                return NodeOutput.Data(price, pythData.publishTime, 0, 0);
            }
        }
        revert OracleDataRequired(address(this), abi.encode(priceFeedId, 0)); // "latest" represented by 0
    }

    function isValid(NodeDefinition.Data memory nodeDefinition) external returns (bool valid) {
        // Must have no parents
        if (nodeDefinition.parents.length > 0) {
            return false;
        }

        (bytes32 priceFeedId, uint256 stalenessTolerance) = abi.decode(
            nodeDefinition.parameters,
            (bytes32, uint256)
        );

        // Must return relevant functions without error
        IPyth pyth = IPyth(pythAddress);
        pyth.getPriceUnsafe(priceFeedId);

        bytes[] memory emptyUpdateData;
        pyth.getUpdateFee(emptyUpdateData);

        return true;
    }

    function oracleId() pure external returns (bytes32) {
        return bytes32("PYTH");
    }

    function fulfillOracleQuery(bytes memory oracleQuery, bytes memory signedOffchainData) payable external {
        IPyth pyth = IPyth(pythAddress);
        bytes[] memory updateData = abi.decode(signedOffchainData, (bytes[]));

        try pyth.updatePriceFeeds(updateData) {
            lastFulfillmentBlockNumber = block.number;
        } catch Error(string memory reason) {
            if (keccak256(abi.encodePacked(reason)) == keccak256(abi.encodePacked("InsufficientFee"))) {
                revert FeeRequired(pyth.getUpdateFee(updateData));
            } else {
                revert(reason);
            }
        }
    }

    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return true;
    }
}
