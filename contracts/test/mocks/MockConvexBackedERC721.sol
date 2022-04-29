// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { ConvexBackedERC721 } from "../../ConvexBackedERC721.sol";
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { ICvxLocker } from "../../interfaces/ICvxLocker.sol";
import { IDelegation } from "../../interfaces/IDelegation.sol";

contract MockConvexBackedERC721 is ConvexBackedERC721 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _priceToMint,
        IDelegation _delegateRegistry,
        ICvxLocker _cvxLocker,
        ERC20 _CVX
    ) ConvexBackedERC721(_name, _symbol, _priceToMint, _delegateRegistry, _cvxLocker, _CVX) {}

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
