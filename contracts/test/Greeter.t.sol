// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { Greeter } from "../Greeter.sol";

import { DSTestPlus } from "./utils/DSTestPlus.sol";

contract GreeterTest is DSTestPlus {
    Greeter private greeter;

    function setUp() public {
        greeter = new Greeter("Hello world!");
    }

    function testInitialization() public {
        assertEq(greeter.greeting(), "Hello world!");
    }
}
