// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ICvxLocker {
    function lock(
        address _account,
        uint256 _amount,
        uint256 _spendRatio
    ) external;
}
