// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

contract MockSpotMarket {
    struct Data {
        uint256 fixedFees;
        uint256 utilizationFees;
        int256 skewFees;
        int256 wrapperFees;
    }

    function quoteSellExactIn(
        uint128 marketId,
        uint256 synthAmount
    ) public view returns (uint256 returnAmount, Data memory fees) {
        returnAmount = 2000000000000000000000;
        fees = Data(0, 0, 0, 0);
    }
}
