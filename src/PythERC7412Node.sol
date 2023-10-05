// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.8.20;

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

    error NotSupported(uint8 updateType);

    constructor(address _pythAddress) {
        pythAddress = _pythAddress;
    }

    function process(
        NodeOutput.Data[] memory,
        bytes memory parameters,
        bytes32[] memory,
        bytes32[] memory
    ) external view returns (NodeOutput.Data memory) {
        (, bytes32 priceId) = abi.decode(
            parameters,
            (address, bytes32)
        );

        bytes32[] memory priceIds = new bytes32[](1);
        priceIds[0] = priceId;
        
        revert OracleDataRequired(
            address(this),
            abi.encode(
                uint8(0), // PythQuery::Latest tag
                priceIds
            )
        );
    }

    function isValid(
        NodeDefinition.Data memory nodeDefinition
    ) external view returns (bool valid) {
        // Must have no parents
        if (nodeDefinition.parents.length > 0) {
            return false;
        }

        (, bytes32 priceFeedId) = abi.decode(
            nodeDefinition.parameters,
            (address, bytes32)
        );

        // Must return relevant functions without error
        IPyth pyth = IPyth(pythAddress);
        pyth.getPriceUnsafe(priceFeedId);

        bytes[] memory emptyUpdateData;
        pyth.getUpdateFee(emptyUpdateData);

        return true;
    }

    function oracleId() external pure returns (bytes32) {
        return bytes32("PYTH");
    }

    function fulfillOracleQuery(
        bytes memory signedOffchainData
    ) external payable {
        IPyth pyth = IPyth(pythAddress);
        bytes[] memory updateData = abi.decode(signedOffchainData, (bytes[]));
        
        try
            pyth.updatePriceFeeds{value: msg.value}(
                updateData
            )
        {
        } catch (bytes memory reason) {
            if (
                reason.length == 4 &&
                reason[0] == 0x02 &&
                reason[1] == 0x5d &&
                reason[2] == 0xbd &&
                reason[3] == 0xd4
            ) {
                revert FeeRequired(pyth.getUpdateFee(updateData));
            } else {
                uint256 len = reason.length;
                assembly {
                    revert(add(reason, 0x20), len)
                }
            }
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IExternalNode).interfaceId ||
            interfaceId == type(IERC7412).interfaceId ||
            interfaceId == this.supportsInterface.selector;
    }
}
