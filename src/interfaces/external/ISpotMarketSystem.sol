//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

interface ISpotMarketSystem {
    struct OrderFeeData {
        uint256 fixedFees;
        uint256 utilizationFees;
        int256 skewFees;
        int256 wrapperFees;
    }

    function quoteSellExactIn(
        uint128 marketId,
        uint256 synthAmount
    ) external view returns (uint256 returnAmount, OrderFeeData memory fees);

    function getSynth(
        uint128 marketId
    ) external view returns (address synthAddress);
}
