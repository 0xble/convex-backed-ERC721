// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { ERC721 } from "@rari-capital/solmate/src/tokens/ERC721.sol";
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { SafeTransferLib } from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ICvxLocker } from "./interfaces/ICvxLocker.sol";
import { IDelegation } from "./interfaces/IDelegation.sol";

error NotApproved();

contract ConvexBackedERC721 is ERC721, Ownable {
    using SafeTransferLib for ERC20;

    uint256 public currentId;
    uint256 public totalSupply;

    uint256 public priceToMint; // Paid for in CVX.
    mapping(address => uint256) public freeMints; // Amount of free mints gifted per address.

    uint256 public teamRate = 20_00; // Percentage of mint price that goes towards the team.
    uint256 public constant DENOMINATOR = 100_00;

    IDelegation public immutable delegateRegistry; // 0x469788fE6E9E9681C6ebF3bF78e7Fd26Fc015446
    ICvxLocker public immutable cvxLocker; // 0x72a19342e8F1838460eBFCCEf09F6585e32db86E
    ERC20 public immutable CVX; // 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _priceToMint,
        IDelegation _delegateRegistry,
        ICvxLocker _cvxLocker,
        ERC20 _CVX
    ) ERC721(_name, _symbol) Ownable() {
        priceToMint = _priceToMint;
        delegateRegistry = _delegateRegistry;
        cvxLocker = _cvxLocker;
        CVX = _CVX;

        // Delegate votes for locked CVX to team multisig.
        delegateRegistry.setDelegate("cvx.eth", owner());

        // Approve Convex to lock CVX.
        CVX.safeApprove(address(cvxLocker), type(uint256).max);
    }

    function tokenURI(uint256 id) public view override returns (string memory) {}

    function mint(address receiver) external returns (uint256 id) {
        if (freeMints[msg.sender] == 0) {
            // Transfer CVX used to pay for mint to the this contract.
            CVX.safeTransferFrom(msg.sender, address(this), priceToMint);

            // Transfer portion of CVX to team's multisig.
            CVX.safeTransfer(owner(), (priceToMint * teamRate) / DENOMINATOR);
        } else {
            // Decrement amount of free mints.
            freeMints[msg.sender]--;
        }

        // Mint NFT to receiver.
        id = currentId++;
        _mint(receiver, id);
        totalSupply++;
    }

    function redeem(uint256 id, address receiver) external returns (uint256 amount) {
        address owner = ownerOf[id];
        if (owner != msg.sender && getApproved[id] != msg.sender && !isApprovedForAll[owner][msg.sender])
            revert NotApproved();

        // Burn NFT from owner.
        _burn(id);

        // Transfer CVX backing to receiver.
        amount = totalBacking() / totalSupply--;
        CVX.safeTransfer(receiver, amount);
    }

    function totalBacking() public view returns (uint256) {
        return CVX.balanceOf(address(this));
    }

    function lockBacking(uint256 amount) external onlyOwner {
        cvxLocker.lock(address(this), amount, 0);
    }

    function giftFreeMints(address[] calldata addresses, uint256[] calldata amounts) external onlyOwner {
        for (uint256 i; i < addresses.length; i++) freeMints[addresses[i]] = amounts[i];
    }
}
