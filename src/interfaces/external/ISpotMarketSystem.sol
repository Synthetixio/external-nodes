//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

interface ISpotMarketSystem {
    struct OrderFeeData {
        uint256 fixedFees;
        uint256 utilizationFees;
        int256 skewFees;
        int256 wrapperFees;
    }

    function sellExactIn(
        uint128 synthMarketId,
        uint256 sellAmount,
        uint256 minAmountReceived,
        address referrer
    ) external payable returns (uint256 returnAmount, OrderFeeData memory fees);
}
