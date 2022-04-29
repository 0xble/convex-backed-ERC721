// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { MockConvexBackedERC721 } from "./mocks/MockConvexBackedERC721.sol";
import { MockDelegateRegistry } from "./mocks/MockDelegateRegistry.sol";
import { MockCvxLocker } from "./mocks/MockCvxLocker.sol";
import { MockERC20 } from "@rari-capital/solmate/src/test/utils/mocks/MockERC20.sol";
import { ICvxLocker } from "../interfaces/ICvxLocker.sol";
import { IDelegation } from "../interfaces/IDelegation.sol";
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DSTestPlus } from "./utils/DSTestPlus.sol";

contract ConvexBackedERC721Test is DSTestPlus {
    MockConvexBackedERC721 private ERC721;
    MockDelegateRegistry private delegateRegistry;
    MockCvxLocker private cvxLocker;
    MockERC20 private CVX;

    address private teamMultisig = hevm.addr(1);
    uint256 private priceToMint = 1000e18; // 1000 CVX

    function setUp() public {
        // Deploy mocks.
        delegateRegistry = new MockDelegateRegistry();
        CVX = new MockERC20("Convex Token", "CVX", 18);
        cvxLocker = new MockCvxLocker(IERC20(address(CVX)));

        // Deploy contract with team multisig.
        hevm.prank(teamMultisig);
        ERC721 = new MockConvexBackedERC721(
            "Convex Backed ERC721",
            "ERC721",
            priceToMint,
            IDelegation(address(delegateRegistry)),
            ICvxLocker(address(cvxLocker)),
            ERC20(CVX)
        );

        // Approve contract to spend all CVX.
        CVX.approve(address(ERC721), type(uint256).max);
    }

    function testInitialization() external {
        // Expect to have delegated votes to team multisig.
        assertEq(delegateRegistry.delegation(address(ERC721), "cvx.eth"), teamMultisig);
    }

    function testMintRedeem() external {
        CVX.mint(address(this), priceToMint);
        uint256 id = ERC721.mint(address(this));

        assertEq(ERC721.ownerOf(id), address(this));
        assertEq(ERC721.totalBacking() + CVX.balanceOf(teamMultisig), priceToMint);
        assertEq(CVX.balanceOf(address(this)), 0);
        assertEq(ERC721.currentId(), 1);
        assertEq(ERC721.totalSupply(), 1);

        uint256 expectedAmount = CVX.balanceOf(address(ERC721));
        uint256 amount = ERC721.redeem(id, address(this));

        assertEq(amount, expectedAmount);
        assertEq(ERC721.ownerOf(id), address(0));
        assertEq(ERC721.totalBacking(), 0);
        assertEq(ERC721.totalSupply(), 0);
    }

    function testLockBacking() external {
        CVX.mint(address(this), priceToMint);
        ERC721.mint(address(this));

        uint256 lockAmount = 500e18;

        hevm.prank(teamMultisig);
        ERC721.lockBacking(lockAmount);

        assertEq(cvxLocker.lockedBalanceOf(address(ERC721)), lockAmount);
    }
}
