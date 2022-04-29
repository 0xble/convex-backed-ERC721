// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { MockERC20 } from "@rari-capital/solmate/src/test/utils/mocks/MockERC20.sol";

import { MockConvexBackedERC721 } from "./mocks/MockConvexBackedERC721.sol";
import { DSTestPlus } from "./utils/DSTestPlus.sol";

contract ConvexBackedERC721Test is DSTestPlus {
    MockConvexBackedERC721 private ERC721;
    MockERC20 private CVX;

    address private teamMultisig = hevm.addr(1);
    uint256 private priceToMint = 1000e18; // 1000 CVX

    function setUp() public {
        CVX = new MockERC20("Convex Token", "CVX", 18);
        ERC721 = new MockConvexBackedERC721("Convex Backed ERC721", "ERC721", teamMultisig, priceToMint, ERC20(CVX));

        CVX.approve(address(ERC721), type(uint256).max);
    }

    function testMintRedeem() external {
        CVX.mint(address(this), priceToMint);
        uint256 id = ERC721.mint(address(this));

        assertEq(ERC721.ownerOf(id), address(this));
        assertEq(ERC721.totalAssets() + CVX.balanceOf(teamMultisig), priceToMint);
        assertEq(CVX.balanceOf(address(this)), 0);
        assertEq(ERC721.currentId(), 1);
        assertEq(ERC721.totalSupply(), 1);

        uint256 expectedAssets = CVX.balanceOf(address(ERC721));
        uint256 assets = ERC721.redeem(id, address(this));

        assertEq(assets, expectedAssets);
        assertEq(ERC721.ownerOf(id), address(0));
        assertEq(ERC721.totalAssets(), 0);
        assertEq(ERC721.totalSupply(), 0);
    }
}
