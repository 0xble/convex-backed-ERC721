// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ICvxLocker {
    function lock(
        address _account,
        uint256 _amount,
        uint256 _spendRatio
    ) external;

    function lockedBalanceOf(address _user) external view returns (uint256 amount);

    function getReward(address _account) external;
}
