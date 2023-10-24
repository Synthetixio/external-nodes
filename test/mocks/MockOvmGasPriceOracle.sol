// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

contract MockOvmGasPriceOracle {
    function gasPrice() public view returns (uint256) {
        return 50;
    }

    function overhead() public view returns (uint256) {
        return 2100;
    }

    function l1BaseFee() public view returns (uint256) {
        return 3359;
    }

    function decimals() public view returns (uint256) {
        return 6;
    }

    function scalar() public view returns (uint256) {
        return 1000000;
    }
}
