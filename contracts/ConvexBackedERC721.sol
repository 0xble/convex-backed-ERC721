// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { ERC721 } from "@rari-capital/solmate/src/tokens/ERC721.sol";
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { SafeTransferLib } from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

error NotAuthorized();

contract ConvexBackedERC721 is ERC721, Ownable {
    using SafeTransferLib for ERC20;

    uint256 public currentId;
    uint256 public totalSupply;

    // Percentage that goes towards team's multisig.
    address public teamMultisig;
    uint256 public teamRate = 80_00;
    uint256 public constant DENOMINATOR = 100_00;

    uint256 public priceToMint; // Denoted in CVX.

    ERC20 public immutable CVX; // 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B

    constructor(
        string memory _name,
        string memory _symbol,
        address _teamMultisig,
        uint256 _priceToMint,
        ERC20 _CVX
    ) ERC721(_name, _symbol) Ownable() {
        teamMultisig = _teamMultisig;
        priceToMint = _priceToMint;

        CVX = _CVX;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {}

    function mint(address receiver) external returns (uint256 id) {
        // Transfer CVX used to pay for mint to the this contract.
        CVX.safeTransferFrom(msg.sender, address(this), priceToMint);

        // Transfer portion of CVX to team's multisig.
        CVX.safeTransfer(teamMultisig, (priceToMint * teamRate) / DENOMINATOR);

        // Mint NFT to receiver.
        id = currentId++;
        _mint(receiver, id);
        totalSupply++;
    }

    function redeem(uint256 id, address receiver) external returns (uint256 assets) {
        address owner = ownerOf[id];
        if (owner != msg.sender && getApproved[id] != msg.sender && !isApprovedForAll[owner][msg.sender])
            revert NotAuthorized();

        // Burn NFT from owner.
        _burn(id);

        // Transfer CVX backing to receiver.
        assets = totalAssets() / totalSupply--;
        CVX.safeTransfer(receiver, assets);
    }

    function totalAssets() public view returns (uint256) {
        return CVX.balanceOf(address(this));
    }
}
