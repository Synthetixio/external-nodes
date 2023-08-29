//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {OrderFees} from "../../lib/OrderFees.sol";

/**
 * @title Module for atomic buy and sell orders for traders.
 */
interface IAtomicOrderModule {
    /**
     * @notice  quote for buyExactIn.  same parameters and return values as buyExactIn
     * @param   synthMarketId  market id value
     * @param   usdAmount  amount of USD to use for the trade
     * @return  synthAmount  return amount of synth given the USD amount - fees
     * @return  fees  breakdown of all the quoted fees for the buy txn
     */
    function quoteBuyExactIn(
        uint128 synthMarketId,
        uint256 usdAmount
    ) external view returns (uint256 synthAmount, OrderFees.Data memory fees);

    /**
     * @notice  quote for buyExactOut.  same parameters and return values as buyExactOut
     * @param   synthMarketId  market id value
     * @param   synthAmount  amount of synth requested
     * @return  usdAmountCharged  USD amount charged for the synth requested - fees
     * @return  fees  breakdown of all the quoted fees for the buy txn
     */
    function quoteBuyExactOut(
        uint128 synthMarketId,
        uint256 synthAmount
    ) external view returns (uint256 usdAmountCharged, OrderFees.Data memory);

    /**
     * @notice  quote for sellExactIn
     * @dev     returns expected USD amount trader would receive for the specified synth amount
     * @param   marketId  synth market id
     * @param   synthAmount  synth amount trader is providing for the trade
     * @return  returnAmount  amount of USD expected back
     * @return  fees  breakdown of all the quoted fees for the txn
     */
    function quoteSellExactIn(
        uint128 marketId,
        uint256 synthAmount
    ) external view returns (uint256 returnAmount, OrderFees.Data memory fees);

    /**
     * @notice  quote for sellExactOut
     * @dev     returns expected synth amount expected from trader for the requested USD amount
     * @param   marketId  synth market id
     * @param   usdAmount  USD amount trader wants to receive
     * @return  synthToBurn  amount of synth expected from trader
     * @return  fees  breakdown of all the quoted fees for the txn
     */
    function quoteSellExactOut(
        uint128 marketId,
        uint256 usdAmount
    ) external view returns (uint256 synthToBurn, OrderFees.Data memory fees);
}
