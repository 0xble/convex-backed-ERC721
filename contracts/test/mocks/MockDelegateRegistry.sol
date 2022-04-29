// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract MockDelegateRegistry {
    mapping(address => mapping(bytes32 => address)) public delegation;

    event SetDelegate(address indexed delegator, bytes32 indexed id, address indexed delegate);
    event ClearDelegate(address indexed delegator, bytes32 indexed id, address indexed delegate);

    function setDelegate(bytes32 id, address delegate) public {
        require(delegate != msg.sender, "Can't delegate to self");
        require(delegate != address(0), "Can't delegate to 0x0");
        address currentDelegate = delegation[msg.sender][id];
        require(delegate != currentDelegate, "Already delegated to this address");

        delegation[msg.sender][id] = delegate;

        if (currentDelegate != address(0)) {
            emit ClearDelegate(msg.sender, id, currentDelegate);
        }

        emit SetDelegate(msg.sender, id, delegate);
    }

    function clearDelegate(bytes32 id) public {
        address currentDelegate = delegation[msg.sender][id];
        require(currentDelegate != address(0), "No delegate set");

        // update delegation mapping
        delegation[msg.sender][id] = address(0);

        emit ClearDelegate(msg.sender, id, currentDelegate);
    }
}
