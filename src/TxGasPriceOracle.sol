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
    struct RuntimeParams {
        // Order execution
        uint256 l1ExecuteGasUnits;
        uint256 l2ExecuteGasUnits;
        // Flag
        uint256 l1FlagGasUnits;
        uint256 l2FlagGasUnits;
        // Liquidate (Rate limited)
        uint256 l1RateLimitedGasUnits;
        uint256 l2RateLimitedGasUnits;
        // Call params
        uint256 positionSize;
        uint256 rateLimit;
        uint256 numberOfUpdatedFeeds;
        uint256 executionKind;
    }

    constructor(address _ovmGasPriceOracleAddress) {
        // Addresses configuration
        ovmGasPriceOracleAddress = _ovmGasPriceOracleAddress;
    }

    function process(
        NodeOutput.Data[] memory,
        bytes memory parameters,
        bytes32[] memory runtimeKeys,
        bytes32[] memory runtimeValues
    ) external view returns (NodeOutput.Data memory nodeOutput) {
        RuntimeParams memory runtimeParams;
        (
            ,
            runtimeParams.l1ExecuteGasUnits,
            runtimeParams.l2ExecuteGasUnits,
            runtimeParams.l1FlagGasUnits,
            runtimeParams.l2FlagGasUnits,
            runtimeParams.l1RateLimitedGasUnits,
            runtimeParams.l2RateLimitedGasUnits
        ) = abi.decode(
            parameters,
            (address, uint256, uint256, uint256, uint256, uint256, uint256)
        );

        for (uint256 i = 0; i < runtimeKeys.length; i++) {
            if (runtimeKeys[i] == "executionKind") {
                runtimeParams.executionKind = uint256(runtimeValues[i]);
                continue;
            }
            if (runtimeKeys[i] == "positionSize") {
                runtimeParams.positionSize = uint256(runtimeValues[i]);
                continue;
            }
            if (runtimeKeys[i] == "rateLimit") {
                runtimeParams.rateLimit = uint256(runtimeValues[i]);
                continue;
            }
            if (runtimeKeys[i] == "numberOfUpdatedFeeds") {
                runtimeParams.numberOfUpdatedFeeds = uint256(runtimeValues[i]);
                continue;
            }
        }

        uint256 costOfExecutionEth = getCostOfExecutionEth(runtimeParams);

        return
            NodeOutput.Data(costOfExecutionEth.toInt(), block.timestamp, 0, 0);
    }

    function getCostOfExecutionEth(
        RuntimeParams memory runtimeParams
    ) internal view returns (uint256 costOfExecutionGrossEth) {
        IOVM_GasPriceOracle ovmGasPriceOracle = IOVM_GasPriceOracle(
            ovmGasPriceOracleAddress
        );

        uint256 gasPriceL2 = ovmGasPriceOracle.gasPrice();
        uint256 overhead = ovmGasPriceOracle.overhead();
        uint256 l1BaseFee = ovmGasPriceOracle.l1BaseFee();
        uint256 decimals = ovmGasPriceOracle.decimals();
        uint256 scalar = ovmGasPriceOracle.scalar();

        (uint256 gasUnitsL1, uint256 gasUnitsL2) = getGasUnits(runtimeParams);

        costOfExecutionGrossEth = ((((gasUnitsL1 + overhead) *
            l1BaseFee *
            scalar) / 10 ** decimals) + (gasUnitsL2 * gasPriceL2));
    }

    function getGasUnits(
        RuntimeParams memory runtimeParams
    ) internal pure returns (uint256 gasUnitsL1, uint256 gasUnitsL2) {
        if (runtimeParams.executionKind == KIND_SETTLEMENT) {
            gasUnitsL1 = runtimeParams.l1ExecuteGasUnits;
            gasUnitsL2 = runtimeParams.l2ExecuteGasUnits;
        } else if (runtimeParams.executionKind == KIND_REQUIRED_MARGIN) {
            // Rate limit gas units
            uint256 rateLimitRuns = ceilDivide(
                runtimeParams.positionSize,
                runtimeParams.rateLimit
            );
            uint256 gasUnitsRateLimitedL1 = runtimeParams
                .l1RateLimitedGasUnits * rateLimitRuns;
            uint256 gasUnitsRateLimitedL2 = runtimeParams
                .l2RateLimitedGasUnits * rateLimitRuns;

            // Flag gas units
            uint256 gasUnitsFlagL1 = runtimeParams.numberOfUpdatedFeeds *
                runtimeParams.l1FlagGasUnits;
            uint256 gasUnitsFlagL2 = runtimeParams.numberOfUpdatedFeeds *
                runtimeParams.l2FlagGasUnits;

            gasUnitsL1 = gasUnitsFlagL1 + gasUnitsRateLimitedL1;
            gasUnitsL2 = gasUnitsFlagL2 + gasUnitsRateLimitedL2;
        } else if (runtimeParams.executionKind == KIND_FLAG) {
            // Flag gas units
            gasUnitsL1 =
                runtimeParams.numberOfUpdatedFeeds *
                runtimeParams.l1FlagGasUnits;
            gasUnitsL2 =
                runtimeParams.numberOfUpdatedFeeds *
                runtimeParams.l2FlagGasUnits;
        } else if (runtimeParams.executionKind == KIND_LIQUIDATE) {
            // Iterations is fixed to 1 for liquidations
            gasUnitsL1 = runtimeParams.l1RateLimitedGasUnits;
            gasUnitsL2 = runtimeParams.l2RateLimitedGasUnits;
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
