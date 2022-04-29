// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { ConvexBackedERC721 } from "../../ConvexBackedERC721.sol";
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";

contract MockConvexBackedERC721 is ConvexBackedERC721 {
    constructor(
        string memory _name,
        string memory _symbol,
        address _teamMultisig,
        uint256 _priceToMint,
        ERC20 _CVX
    ) ConvexBackedERC721(_name, _symbol, _teamMultisig, _priceToMint, _CVX) {}

    function freeMint(address receiver, uint256 id) external {
        _mint(receiver, id);
        totalSupply++;
    }

    function freeMint(address receiver) external returns (uint256 id) {
        id = currentId++;
        _mint(receiver, id);
        totalSupply++;
    }
}
