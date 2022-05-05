// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { SafeTransferLib } from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import { ICvxLocker } from "./interfaces/ICvxLocker.sol";
import { IDelegation } from "./interfaces/IDelegation.sol";

// TODO:
// - [ ] Add functionality to claim and autocompound rewards.
// - [ ] Add functionality to relock expired vlCVX.
// - [ ] Integrate this with ConvexBackedERC721 contract.

contract WrappedVlCVX is ERC20 {
    using SafeTransferLib for ERC20;

    address public teamMultisig;

    ERC20 public immutable CVX; // 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B
    ICvxLocker public immutable cvxLocker; // 0x72a19342e8F1838460eBFCCEf09F6585e32db86E
    IDelegation public immutable delegateRegistry; // 0x469788fE6E9E9681C6ebF3bF78e7Fd26Fc015446

    constructor(
        ERC20 _CVX,
        ICvxLocker _cvxLocker,
        IDelegation _delegateRegistry,
        address _teamMultisig
    ) ERC20("Wrapped vlCVX", "wvlCVX", 18) {
        CVX = _CVX;
        cvxLocker = _cvxLocker;
        teamMultisig = _teamMultisig;
        delegateRegistry = _delegateRegistry;

        // Delegate votes for locked CVX to team multisig.
        delegateRegistry.setDelegate("cvx.eth", _teamMultisig);

        // Approve Convex to lock CVX.
        CVX.safeApprove(address(cvxLocker), type(uint256).max);
    }

    function mint(uint256 amount, address receiver) external {
        // Transfer CVX to this contract.
        CVX.safeTransferFrom(msg.sender, address(this), amount);

        // Lock in Convex.
        cvxLocker.lock(address(this), amount, 0);

        // Mint proportional amount of wvlCVX to receiver.
        _mint(receiver, amount);
    }
}
