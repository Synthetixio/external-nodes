// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.8.20;

import "./lib/DecimalMath.sol";
import "./lib/SafeCast.sol";
import "./interfaces/external/IPyth.sol";
import "./interfaces/external/IERC7412.sol";

contract PythERC7412Wrapper is IERC7412 {
    using DecimalMath for int64;
    using SafeCastI256 for int256;

    address public immutable pythAddress;

    mapping(bytes32 => mapping(uint64 => PythStructs.Price))
        public benchmarkPrices;

    error NotSupported(uint8 updateType);

    constructor(address _pythAddress) {
        pythAddress = _pythAddress;
    }

    function oracleId() external pure returns (bytes32) {
        return bytes32("PYTH");
    }

    function getBenchmarkPrice(
        bytes32 priceId,
        uint64 requestedTime
    ) external view returns (int64) {
        PythStructs.Price memory priceData = benchmarkPrices[priceId][
            requestedTime
        ];

        if (priceData.price > 0) {
            return priceData.price;
        }

        revert OracleDataRequired(
            address(this),
            abi.encode(
                uint8(2), // PythQuery::Benchmark tag
                uint64(requestedTime),
                [priceId]
            )
        );
    }

    function getLatestPrice(
        bytes32 priceId,
        uint256 stalenessTolerance
    ) external view returns (int64) {
        IPyth pyth = IPyth(pythAddress);
        PythStructs.Price memory pythData = pyth.getPriceUnsafe(priceId);

        if (block.timestamp <= stalenessTolerance + pythData.publishTime) {
            return pythData.price;
        }

        //price too stale
        revert OracleDataRequired(
            address(this),
            abi.encode(uint8(1), uint64(stalenessTolerance), [priceId])
        );
    }

    function fulfillOracleQuery(
        bytes memory signedOffchainData
    ) external payable {
        IPyth pyth = IPyth(pythAddress);

        (
            uint8 updateType,
            uint64 timestamp,
            bytes32[] memory priceIds,
            bytes[] memory updateData
        ) = abi.decode(signedOffchainData, (uint8, uint64, bytes32[], bytes[]));

        if (updateType != 2) {
            revert NotSupported(updateType);
        }

        try
            pyth.parsePriceFeedUpdatesUnique{value: msg.value}(
                updateData,
                priceIds,
                timestamp,
                type(uint64).max
            )
        returns (PythStructs.PriceFeed[] memory priceFeeds) {
            for (uint i = 0; i < priceFeeds.length; i++) {
                benchmarkPrices[priceIds[i]][timestamp] = priceFeeds[i].price;
            }
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
}
