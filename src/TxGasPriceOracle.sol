// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "./lib/DecimalMath.sol";
import "./interfaces/external/IExternalNode.sol";
import "./interfaces/external/IOVM_GasPriceOracle.sol";

contract TxGasPriceOracle is IExternalNode {
    using SafeCastU256 for uint256;

    address public immutable ovmGasPriceOracleAddress;

    uint256 public constant KIND_SETTLEMENT = 0;
    uint256 public constant KIND_REQUIRED_MARGIN = 1;
    uint256 public constant KIND_FLAG = 2;
    uint256 public constant KIND_LIQUIDATE = 3;

    // Order execution
    uint256 private immutable l1ExecuteGasUnits;
    uint256 private immutable l2ExecuteGasUnits;

    // Flag
    uint256 private immutable variableL1FlagGasUnits;
    uint256 private immutable variableL2FlagGasUnits;
    uint256 private immutable fixedL1FlagGasUnits;
    uint256 private immutable fixedL2FlagGasUnits;

    // Liquidate (Rate limited)
    uint256 private immutable l1RateLimitedGasUnits;
    uint256 private immutable l2RateLimitedGasUnits;

    constructor(
        address _ovmGasPriceOracleAddress,
        uint256 _L1ExecuteGasUnits,
        uint256 _L2ExecuteGasUnits,
        uint256 _variableL1FlagGasUnits,
        uint256 _variableL2FlagGasUnits,
        uint256 _fixedL1FlagGasUnits,
        uint256 _fixedL2FlagGasUnits,
        uint256 _l1RateLimitedGasUnits,
        uint256 _l2RateLimitedGasUnits
    ) {
        // Addresses configuration
        ovmGasPriceOracleAddress = _ovmGasPriceOracleAddress;

        // Params configuration
        l1ExecuteGasUnits = _L1ExecuteGasUnits;
        l2ExecuteGasUnits = _L2ExecuteGasUnits;
        variableL1FlagGasUnits = _variableL1FlagGasUnits;
        variableL2FlagGasUnits = _variableL2FlagGasUnits;
        fixedL1FlagGasUnits = _fixedL1FlagGasUnits;
        fixedL2FlagGasUnits = _fixedL2FlagGasUnits;
        l1RateLimitedGasUnits = _l1RateLimitedGasUnits;
        l2RateLimitedGasUnits = _l2RateLimitedGasUnits;
    }

    function process(
        NodeOutput.Data[] memory,
        bytes memory,
        bytes32[] memory runtimeKeys,
        bytes32[] memory runtimeValues
    ) external view returns (NodeOutput.Data memory nodeOutput) {
        uint256 positionSize;
        uint256 rateLimit;
        uint256 numberOfUpdatedFeeds;
        uint256 executionKind;

        for (uint256 i = 0; i < runtimeKeys.length; i++) {
            if (runtimeKeys[i] == "executionKind") {
                executionKind = uint256(runtimeValues[i]);
                continue;
            }
            if (runtimeKeys[i] == "positionSize") {
                positionSize = uint256(runtimeValues[i]);
                continue;
            }
            if (runtimeKeys[i] == "rateLimit") {
                rateLimit = uint256(runtimeValues[i]);
                continue;
            }
            if (runtimeKeys[i] == "numberOfUpdatedFeeds") {
                numberOfUpdatedFeeds = uint256(runtimeValues[i]);
                continue;
            }
        }

        uint256 costOfExecutionEth = getCostOfExecutionEth(
            positionSize,
            rateLimit,
            numberOfUpdatedFeeds,
            executionKind
        );

        return
            NodeOutput.Data(costOfExecutionEth.toInt(), block.timestamp, 0, 0);
    }

    function getCostOfExecutionEth(
        uint positionSize,
        uint rateLimit,
        uint numberOfUpdatedFeeds,
        uint executionKind
    ) internal view returns (uint256 costOfExecutionGrossEth) {
        IOVM_GasPriceOracle ovmGasPriceOracle = IOVM_GasPriceOracle(
            ovmGasPriceOracleAddress
        );

        uint256 gasPriceL2 = ovmGasPriceOracle.gasPrice();
        uint256 overhead = ovmGasPriceOracle.overhead();
        uint256 l1BaseFee = ovmGasPriceOracle.l1BaseFee();
        uint256 decimals = ovmGasPriceOracle.decimals();
        uint256 scalar = ovmGasPriceOracle.scalar();

        (uint256 gasUnitsL1, uint256 gasUnitsL2) = getGasUnits(
            positionSize,
            rateLimit,
            numberOfUpdatedFeeds,
            executionKind
        );

        costOfExecutionGrossEth = ((((gasUnitsL1 + overhead) *
            l1BaseFee *
            scalar) / 10 ** decimals) + (gasUnitsL2 * gasPriceL2));
    }

    function getGasUnits(
        uint positionSize,
        uint rateLimit,
        uint numberOfUpdatedFeeds,
        uint executionKind
    ) internal view returns (uint256 gasUnitsL1, uint256 gasUnitsL2) {
        if (executionKind == KIND_SETTLEMENT) {
            gasUnitsL1 = l1ExecuteGasUnits;
            gasUnitsL2 = l2ExecuteGasUnits;
        } else if (executionKind == KIND_REQUIRED_MARGIN) {
            // Rate limit gas units
            uint256 rateLimitRuns = ceilDivide(positionSize, rateLimit);
            uint256 gasUnitsRateLimitedL1 = l1RateLimitedGasUnits *
                rateLimitRuns;
            uint256 gasUnitsRateLimitedL2 = l2RateLimitedGasUnits *
                rateLimitRuns;

            // Flag gas units
            uint256 gasUnitsFlagL1 = numberOfUpdatedFeeds *
                variableL1FlagGasUnits +
                fixedL1FlagGasUnits;
            uint256 gasUnitsFlagL2 = numberOfUpdatedFeeds *
                variableL2FlagGasUnits +
                fixedL2FlagGasUnits;

            gasUnitsL1 = gasUnitsFlagL1 + gasUnitsRateLimitedL1;
            gasUnitsL2 = gasUnitsFlagL2 + gasUnitsRateLimitedL2;
        } else if (executionKind == KIND_FLAG) {
            // Flag gas units
            gasUnitsL1 =
                numberOfUpdatedFeeds *
                variableL1FlagGasUnits +
                fixedL1FlagGasUnits;
            gasUnitsL2 =
                numberOfUpdatedFeeds *
                variableL2FlagGasUnits +
                fixedL2FlagGasUnits;
        } else if (executionKind == KIND_LIQUIDATE) {
            // Iterations is fixed to 1 for liquidations
            gasUnitsL1 = l1RateLimitedGasUnits;
            gasUnitsL2 = l2RateLimitedGasUnits;
        } else {
            revert("Invalid execution kind");
        }
    }

    function ceilDivide(uint a, uint b) internal pure returns (uint) {
        if (b == 0) return 0;
        return a / b + (a % b == 0 ? 0 : 1);
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
