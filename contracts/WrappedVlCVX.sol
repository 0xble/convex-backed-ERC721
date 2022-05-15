// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { ERC4626 } from "./tokens/ERC4626.sol";
import { SafeTransferLib } from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import { Auth, Authority } from "@rari-capital/solmate/src/auth/Auth.sol";
import { MathUtils } from "./utils/MathUtils.sol";

import { ICvxLocker } from "./interfaces/ICvxLocker.sol";
import { IDelegation } from "./interfaces/IDelegation.sol";
import { ISushiSwapRouter } from "./interfaces/ISushiSwapRouter.sol";

// TODO:
// - [x] Add functionality to relock expired vlCVX after 1 week unlock period.
// - [x] Add functionality to claim and autocompound rewards.
// - [x] Only allow EOAs or approved contracts to withdraw as a security measure.
// - [ ] Consider using Uniswap instead of Sushiswap for autocompounding.
// - [ ] Add events.

error UnapprovedContractOrNotEOA();
error WithdrawPeriodExpired();
error NotContract();
error AboveMax();
error InvalidPath();

/**
 * @title Wrapped Vote-Locked Convex
 * @notice ERC4626 wrapper that tokenizes vlCVX and delegates votes to the Curvance team.
 * @author Brian Le
 */
contract WrappedVlCVX is ERC4626, Auth {
    using SafeTransferLib for ERC20;
    using MathUtils for uint256;

    // ======================================== WITHDRAW PERIOD CONFIG ========================================

    /**
     * @notice By design, withdraws are limited to certain times and on a first come first served
     *         basis. Any users wishing to withdraw may do so on a first come first served basis for
     *         the length of the withdraw period, after which any remaining CVX will be relocked.
     */
    uint32 public withdrawPeriod = 7 days;

    /**
     * @notice Used to determine whether a withdraw period is current ongoing or has expired.
     */
    uint64 public lastWithdrawPeriod;

    /**
     * @notice Used to determine whether a batch of locked CVX has recently been unlocked.
     */
    uint112 public lastLockedBalance;

    /**
     * @notice Whether remaining CVX has been locked for the last withdraw period.
     */
    bool public locked;

    /**
     * @notice Change the withdraw period after which remaining CVX is relocked.
     */
    function setWithdrawPeriod(uint32 newWithdrawPeriod) external requiresAuth {
        withdrawPeriod = newWithdrawPeriod;
    }

    /**
     * @notice Whether a withdraw period is currently active.
     */
    function isWithdrawPeriodActive() public returns (bool) {
        return block.timestamp < lastWithdrawPeriod + withdrawPeriod;
    }

    // ============================================ REWARDS CONFIG ============================================

    /**
     * @notice List of reward tokens claimable from Convex for locking CVX.
     */
    ERC20[] public rewardTokens;

    /**
     * @notice Gets the list of reward tokens.
     * @dev This is provided because Solidity converts public arrays into index getters,
     *      but we want a way to allow external contracts and users to access the whole array
     *      in a single call.
     */
    function getRewardTokens() external view returns (ERC20[] memory) {
        return rewardTokens;
    }

    /**
     * @notice Change the list of reward tokens.
     * @param newRewardTokens addresses of new list of reward tokens
     */
    function setRewardTokens(ERC20[] calldata newRewardTokens) external requiresAuth {
        rewardTokens = newRewardTokens;
    }

    // ============================================ SECURITY LOGIC ============================================

    /**
     * @notice A security measure in-place to prevent contracts and bots from swooping up all newly
     *         unlocked CVX before users. Only approved contracts will be able to interact with this
     *         contract like users.
     */
    mapping(address => bool) public approved;

    /**
     * @notice Restricts calls to users (externally owned accounts, or EOAs) or approved contracts.
     */
    modifier onlyApprovedOrEOA() {
        if (!approved[msg.sender] && msg.sender != tx.origin) revert UnapprovedContractOrNotEOA();
    }

    /**
     * @notice Approve a contract to perform withdraws.
     * @param account address of the contract
     * @param approve whether the contract is approved
     */
    function setApproval(address account, bool approve) external {
        if (account.code.length == 0) revert NotContract();

        approved[account] = approve;
    }

    // ============================================= CONSTRUCTOR =============================================

    /**
     * @notice Address which contract delegates its CVX voting power to which will cast votes to
     *         maximize yields of token holders and act in the best interest of the protocol.
     */
    address public immutable teamMultisig;

    ICvxLocker public immutable cvxLocker; // 0x72a19342e8F1838460eBFCCEf09F6585e32db86E
    IDelegation public immutable delegateRegistry; // 0x469788fE6E9E9681C6ebF3bF78e7Fd26Fc015446
    ISushiSwapRouter public constant swapRouter; // 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F

    constructor(
        ERC20 _cvx,
        ERC20[] _rewardTokens,
        address _teamMultisig,
        Authority _authority,
        ICvxLocker _cvxLocker,
        IDelegation _delegateRegistry,
        ISushiSwapRouter _swapRouter
    ) Auth(_teamMultisig, _authority) ERC4626(_cvx, "Wrapped vlCVX", "wvlCVX", 18) {
        cvxLocker = _cvxLocker;
        teamMultisig = _teamMultisig;
        delegateRegistry = _delegateRegistry;
        swapRouter = _swapRouter;

        // Initialize rewards.
        rewardsToken = _rewardTokens;

        // Delegate votes for locked CVX to team multisig.
        delegateRegistry.setDelegate("cvx.eth", _teamMultisig);

        // Approve Convex to lock CVX.
        CVX.safeApprove(address(cvxLocker), type(uint256).max);
    }

    // ============================================= ACCOUNTING LOGIC =============================================

    /**
     * @notice Total unlocked CVX in the contract.
     */
    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    // ============================================= CORE LOGIC =============================================

    function beforeWithdraw(uint256 assets, uint256) internal override onlyApprovedOrEOA {
        // Get current locked balance of CVX.
        uint112 currentLockedBalance = cvxLocker.lockedBalanceOf(address(this));

        // Check if a withdraw period is currently ongoing.
        if (!isWithdrawPeriodActive()) {
            // Begin withdraw period if CVX has recently been unlocked.
            if (currentLockedBalance < lastLockedBalance) {
                lastWithdrawPeriod = block.timestamp;
                locked = false;
            } else {
                // Lock any remaining CVX after the withdraw period has just expired if not locked already.
                if (!locked) {
                    uint256 remainingAfterWithdraw = totalAssets() - assets;

                    if (remainingAfterWithdraw > 0) cvxLocker.lock(address(this), remainingAfterWithdraw, 0);

                    locked = true;
                }
            }
        }

        lastLockedBalance = currentLockedBalance;
    }

    // =============================================== REWARDS LOGIC ===============================================

    /**
     * @notice Claim rewards from Convex for locking CVX.
     */
    function claim() external {
        cvxLocker.getReward(address(this));
    }

    /**
     * @notice Reinvest claimed rewards back into CVX.
     * @param minAssetsOut minimum amount of CVX to receive after swapping each reward
     * @param swapPathsToAsset swap path from each reward token to CVX on Sushiswap
     */
    function reinvest(uint256[] minAssetsOut, address[][] swapPathsToAsset) external requiresAuth {
        for (uint256 i; i < rewardTokens.length; i++) {
            ERC20 reward = rewardTokens[i];
            address[] path = swapPathsToAsset[i];

            // Check to make sure swap path is valid.
            if (path[0] != address(reward) || path[path.length - 1] != address(asset)) revert InvalidPath();

            // Swap rewards for CVX.
            swapRouter.swapExactTokensForTokens(
                reward.balanceOf(address(this)), // Amount of rewards to swap for CVX.
                minAssetsOut[i], // Minimum amount of CVX to receive from swap.
                path, // Swap path from reward token to CVX
                address(this), // Address that should receive CVX.
                block.timestamp // Deadline before swap is invalid.
            );
        }
    }

    // ================================================ LOCK LOGIC ================================================

    /**
     * @notice Lock a specified amount of CVX.
     * @param assets amount of CVX to lock
     */
    function lock(uint256 assets) external requiresAuth {
        cvxLocker.lock(address(this), assets, 0);

        // Initialize last locked balance if this is the first time locking.
        if (lastLockedBalance == 0) lastLockedBalance = assets;
    }

    /**
     * @notice Process all expired locks by either relocking or unlocking to the contract to be withdrawn.
     * @param relock whether to relock or not
     */
    function processExpiredLocks(bool relock) external requiresAuth {
        cvxLocker.processExpiredLocks(relock);
    }
}
