// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "./lib/OrderFees.sol";
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

    constructor(address _spotMarketAddress, address _ovmGasPriceOracleAddress) {
        spotMarketAddress = _spotMarketAddress;
        ovmGasPriceOracleAddress = _ovmGasPriceOracleAddress;
    }

    // uint256 private _profitMarginUSD;
    // uint256 private _profitMarginPercent;
    // uint256 private _minKeeperFeeUpperBound;
    // uint256 private _minKeeperFeeLowerBound;
    // uint256 private _gasUnitsL1;
    // uint256 private _gasUnitsL2;
    // uint256 private _lastUpdatedAtTime;

    function process(
        NodeOutput.Data[] memory,
        bytes memory parameters,
        bytes32[] memory runtimeKeys,
        bytes32[] memory runtimeValues
    ) external view returns (NodeOutput.Data memory nodeOutput) {
        (, uint128 marketId) = abi.decode(parameters, (address, uint128));

        uint256 gasUnitsL1;
        uint256 gasUnitsL2;

        for (uint256 i = 0; i < runtimeKeys.length; i++) {
            if (runtimeKeys[i] == "gasUnitsL1") {
                gasUnitsL1 = uint256(runtimeValues[i]);
                continue;
            }
            if (runtimeKeys[i] == "gasUnitsL2") {
                gasUnitsL2 = uint256(runtimeValues[i]);
                continue;
            }
        }

        IOVM_GasPriceOracle ovmGasPriceOracle = IOVM_GasPriceOracle(
            ovmGasPriceOracleAddress
        );
        ISpotMarketSystem spotMarketSystem = ISpotMarketSystem(
            spotMarketAddress
        );

        uint256 gasPriceL2 = ovmGasPriceOracle.gasPrice();
        uint256 overhead = ovmGasPriceOracle.overhead();
        uint256 l1BaseFee = ovmGasPriceOracle.l1BaseFee();
        uint256 decimals = ovmGasPriceOracle.decimals();
        uint256 scalar = ovmGasPriceOracle.scalar();

        uint256 costOfExecutionGrossEth = ((((gasUnitsL1 + overhead) *
            l1BaseFee *
            scalar) / 10 ** decimals) + (gasUnitsL2 * gasPriceL2));

        (uint256 ethPrice, ) = spotMarketSystem.quoteSellExactIn(
            marketId,
            costOfExecutionGrossEth
        );
        uint256 costOfExecutionGross = costOfExecutionGrossEth.mulDiv(
            ethPrice,
            UNIT
        );

        uint256 maxProfitMargin = _profitMarginUSD.max(
            costOfExecutionGross.mulDiv(_profitMarginPercent, UNIT)
        );
        uint256 costOfExecutionNet = costOfExecutionGross + maxProfitMargin;

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
