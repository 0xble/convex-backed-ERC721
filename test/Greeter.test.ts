import { ethers } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { Greeter, Greeter__factory } from "../src/types";

describe("Greeter", () => {
  let owner: SignerWithAddress;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let greeter: Greeter;

  beforeEach(async () => {
    [owner, alice, bob] = await ethers.getSigners();

    greeter = await new Greeter__factory(owner).deploy("Hello world!");
    await greeter.deployed();
  });

  it("should return correct greeting", async () => {
    expect(await greeter.greet()).to.eq("Hello world!");
  });
});
