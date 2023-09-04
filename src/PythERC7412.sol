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
        bytes memory parameters,
				bytes32[] memory,
				bytes32[] memory
    ) external view returns (NodeOutput.Data memory nodeOutput) {
        (, bytes32 priceId, uint256 stalenessTolerance) = abi.decode(
            parameters,
            (address, bytes32, uint256)
        );

        if(lastFulfillmentBlockNumber == block.number) {
            IPyth pyth = IPyth(pythAddress);
            PythStructs.Price memory pythData = pyth.getPriceUnsafe(priceId);

            int256 factor = PRECISION + pythData.expo;
            int256 price = factor > 0
                ? pythData.price.upscale(factor.toUint())
                : pythData.price.downscale((-factor).toUint());

            if (block.timestamp - pythData.publishTime <= stalenessTolerance) {
                return NodeOutput.Data(price, pythData.publishTime, 0, 0);
            }
        }

        bytes32[] memory priceIds = new bytes32[](1);
        priceIds[0] = priceId;

        // The query is like this:
        // Struct PythQuery {
        //  priceIds: bytes32[],
        //  request: PythRequest
        // }
        //
        // Enum PythRequest {
        //  Latest,
        //  NoOlderThan(uint64), // Staleness tolerance
        //  Benchmark(uint64)
        // }
        // 
        // Currently only type 1 (NoOlderThan) is implemented
        revert OracleDataRequired(
            address(this),
            abi.encode( // TODO: Use encodePacked in the future
                priceIds,
                uint8(1),
                uint64(stalenessTolerance)
            )
        ); 
    }

    function isValid(NodeDefinition.Data memory nodeDefinition) external view returns (bool valid) {
        // Must have no parents
        if (nodeDefinition.parents.length > 0) {
            return false;
        }

        (, bytes32 priceFeedId,) = abi.decode(
            nodeDefinition.parameters,
            (address, bytes32, uint256)
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

        (bytes32[] memory priceIds, uint8 updateType, uint64 stalenessTolerance) = 
            abi.decode(oracleQuery, (bytes32[], uint8, uint64));

        require(updateType == 1, "Other update types are not supported yet");

        uint64 minAcceptedPublishTime = uint64(block.timestamp) - stalenessTolerance;
        
        uint64[] memory publishTimes = new uint64[](priceIds.length);
        
        for (uint i = 0; i < priceIds.length; i++) {
            publishTimes[i] = minAcceptedPublishTime;
        }

        try pyth.updatePriceFeedsIfNecessary{value: msg.value}(updateData, priceIds, publishTimes) {
            lastFulfillmentBlockNumber = block.number;
        } catch Error(string memory reason) {
            bytes32 hash = keccak256(abi.encodePacked(reason));
            if (hash == keccak256(abi.encodePacked("NoFreshUpdate"))) {
                // This revert means that there existed an update with
                // publishTime >= minAcceptedPublishTime and hence the
                // method reverts.
                lastFulfillmentBlockNumber = block.number;
            } else if (hash == keccak256(abi.encodePacked("InsufficientFee"))) {
                revert FeeRequired(pyth.getUpdateFee(updateData));
            } else {
                revert(reason);
            }
        }
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == type(IExternalNode).interfaceId ||
            interfaceId == type(IERC7412).interfaceId ||
            interfaceId == this.supportsInterface.selector;
    }
}
