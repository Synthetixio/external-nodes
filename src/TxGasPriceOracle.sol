// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "./lib/DecimalMath.sol";
import "./interfaces/external/IExternalNode.sol";
import "./interfaces/external/ISpotMarketSystem.sol";
import "./interfaces/external/IAtomicOrderModule.sol";
import "./interfaces/external/IOVM_GasPriceOracle.sol";

contract TxGasPriceOracle is IExternalNode {
    using DecimalMath for int256;
    using DecimalMath for uint256;

    using SafeCastI256 for int256;
    using SafeCastU256 for uint256;

    int256 public constant PRECISION = 18;
    uint256 private constant UNIT = 10 ** uint(18);

    address public immutable spotMarketAddress;
    address public immutable ovmGasPriceOracleAddress;

    uint256 private immutable variableL1FlagGasUnits;
    uint256 private immutable variableL2FlagGasUnits;
    uint256 private immutable fixedL1FlagGasUnits;
    uint256 private immutable fixedL2FlagGasUnits;
    uint256 private immutable variableL1RateLimitedGasUnits;
    uint256 private immutable variableL2RateLimitedGasUnits;
    uint256 private immutable fixedL1RateLimitedGasUnits;
    uint256 private immutable fixedL2RateLimitedGasUnits;

    constructor(
        address _spotMarketAddress,
        address _ovmGasPriceOracleAddress,
        uint256 _variableL1FlagGasUnits,
        uint256 _variableL2FlagGasUnits,
        uint256 _fixedL1FlagGasUnits,
        uint256 _fixedL2FlagGasUnits,
        uint256 _variableL1RateLimitedGasUnits,
        uint256 _variableL2RateLimitedGasUnits,
        uint256 _fixedL1RateLimitedGasUnits,
        uint256 _fixedL2RateLimitedGasUnits
    ) {
        // Addresses configuration
        spotMarketAddress = _spotMarketAddress;
        ovmGasPriceOracleAddress = _ovmGasPriceOracleAddress;

        // Params configuration
        variableL1FlagGasUnits = _variableL1FlagGasUnits;
        variableL2FlagGasUnits = _variableL2FlagGasUnits;
        fixedL1FlagGasUnits = _fixedL1FlagGasUnits;
        fixedL2FlagGasUnits = _fixedL2FlagGasUnits;
        variableL1RateLimitedGasUnits = _variableL1RateLimitedGasUnits;
        variableL2RateLimitedGasUnits = _variableL2RateLimitedGasUnits;
        fixedL1RateLimitedGasUnits = _fixedL1RateLimitedGasUnits;
        fixedL2RateLimitedGasUnits = _fixedL2RateLimitedGasUnits;
    }

    function process(
        NodeOutput.Data[] memory,
        bytes memory parameters,
        bytes32[] memory runtimeKeys,
        bytes32[] memory runtimeValues
    ) external view returns (NodeOutput.Data memory nodeOutput) {
        (, uint128 marketId) = abi.decode(parameters, (address, uint128));

        uint256 positionSize;
        uint256 rateLimit;
        uint256 numberOfUpdatedFeeds;

        for (uint256 i = 0; i < runtimeKeys.length; i++) {
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

        ISpotMarketSystem spotMarketSystem = ISpotMarketSystem(
            spotMarketAddress
        );

        uint256 costOfExecutionGrossEth = getCostOfExecutionGrossEth(
            positionSize,
            rateLimit,
            numberOfUpdatedFeeds
        );

        // ETH to USD
        (uint256 ethPrice, ) = spotMarketSystem.quoteSellExactIn(
            marketId,
            costOfExecutionGrossEth
        );

        uint256 costOfExecutionGross = costOfExecutionGrossEth.divDecimal(
            ethPrice
        );

        // uint256 maxProfitMargin = _profitMarginUSD.max(
        //     costOfExecutionGross.mulDiv(_profitMarginPercent, UNIT)
        // );
        // uint256 costOfExecutionNet = costOfExecutionGross + maxProfitMargin;

        return
            NodeOutput.Data(
                costOfExecutionGross.toInt(),
                block.timestamp,
                0,
                0
            );
    }

    // function getParameters()
    //     external
    //     view
    //     returns (
    //         uint256 variableL1FlagGasUnits,
    //         uint256 variableL2FlagGasUnits,
    //         uint256 fixedL1FlagGasUnits,
    //         uint256 fixedL2FlagGasUnits,
    //         uint256 variableL1RateLimitedGasUnits,
    //         uint256 variableL2RateLimitedGasUnits,
    //         uint256 fixedL1RateLimitedGasUnits,
    //         uint256 fixedL2RateLimitedGasUnits
    //     )
    // {
    //     variableL1FlagGasUnits = _variableL1FlagGasUnits;
    //     variableL2FlagGasUnits = _variableL2FlagGasUnits;
    //     fixedL1FlagGasUnits = _fixedL1FlagGasUnits;
    //     fixedL2FlagGasUnits = _fixedL2FlagGasUnits;
    //     variableL1RateLimitedGasUnits = _variableL1RateLimitedGasUnits;
    //     variableL2RateLimitedGasUnits = _variableL2RateLimitedGasUnits;
    //     fixedL1RateLimitedGasUnits = _fixedL1RateLimitedGasUnits;
    //     fixedL2RateLimitedGasUnits = _fixedL2RateLimitedGasUnits;
    // }

    // @dev Sets params used for gas price computation.
    // function setParameters(
    //     uint256 variableL1FlagGasUnits,
    //     uint256 variableL2FlagGasUnits,
    //     uint256 fixedL1FlagGasUnits,
    //     uint256 fixedL2FlagGasUnits,
    //     uint256 variableL1RateLimitedGasUnits,
    //     uint256 variableL2RateLimitedGasUnits,
    //     uint256 fixedL1RateLimitedGasUnits,
    //     uint256 fixedL2RateLimitedGasUnits
    // ) external /* onlyOwner */ {
    //     _variableL1FlagGasUnits = variableL1FlagGasUnits;
    //     _variableL2FlagGasUnits = variableL2FlagGasUnits;
    //     _fixedL1FlagGasUnits = fixedL1FlagGasUnits;
    //     _fixedL2FlagGasUnits = fixedL2FlagGasUnits;
    //     _variableL1RateLimitedGasUnits = variableL1RateLimitedGasUnits;
    //     _variableL2RateLimitedGasUnits = variableL2RateLimitedGasUnits;
    //     _fixedL1RateLimitedGasUnits = fixedL1RateLimitedGasUnits;
    //     _fixedL2RateLimitedGasUnits = fixedL2RateLimitedGasUnits;
    // }

    function getCostOfExecutionGrossEth(
        uint positionSize,
        uint rateLimit,
        uint numberOfUpdatedFeeds
    ) internal view returns (uint256) {
        IOVM_GasPriceOracle ovmGasPriceOracle = IOVM_GasPriceOracle(
            ovmGasPriceOracleAddress
        );

        uint256 gasPriceL2 = ovmGasPriceOracle.gasPrice();
        uint256 overhead = ovmGasPriceOracle.overhead();
        uint256 l1BaseFee = ovmGasPriceOracle.l1BaseFee();
        uint256 decimals = ovmGasPriceOracle.decimals();
        uint256 scalar = ovmGasPriceOracle.scalar();

        uint256 rateLimitRuns = ceilDivide(positionSize, rateLimit);
        uint256 gasUnitsRateLimitedL1 = (variableL1RateLimitedGasUnits +
            fixedL1RateLimitedGasUnits) * rateLimitRuns;
        uint256 gasUnitsRateLimitedL2 = (variableL2RateLimitedGasUnits +
            fixedL2RateLimitedGasUnits) * rateLimitRuns;

        uint256 gasUnitsFlagL1 = numberOfUpdatedFeeds *
            variableL1FlagGasUnits +
            fixedL1FlagGasUnits;
        uint256 gasUnitsFlagL2 = numberOfUpdatedFeeds *
            variableL2FlagGasUnits +
            fixedL2FlagGasUnits;

        uint256 gasUnitsL1 = gasUnitsFlagL1 + gasUnitsRateLimitedL1;
        uint256 gasUnitsL2 = gasUnitsFlagL2 + gasUnitsRateLimitedL2;

        uint256 costOfExecutionGrossEth = ((((gasUnitsL1 + overhead) *
            l1BaseFee *
            scalar) / 10 ** decimals) + (gasUnitsL2 * gasPriceL2));

        return costOfExecutionGrossEth;
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

    function ceilDivide(uint a, uint b) internal pure returns (uint) {
        if (b == 0) return 0;
        return a / b + (a % b == 0 ? 0 : 1);
    }
}
