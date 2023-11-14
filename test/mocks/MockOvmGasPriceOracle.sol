// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

contract MockOvmGasPriceOracle {
    function gasPrice() public pure returns (uint256) {
        return 50;
    }

    function overhead() public pure returns (uint256) {
        return 2100;
    }

    function l1BaseFee() public pure returns (uint256) {
        return 3400;
    }

    function decimals() public pure returns (uint256) {
        return 6;
    }

    function scalar() public pure returns (uint256) {
        return 1000000;
    }
}
