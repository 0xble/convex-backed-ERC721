import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { Greeter, Greeter__factory } from "../../src/types";

task("deploy:Greeter")
  .addParam("greeting", "Say hello, be nice")
  .setAction(async function (taskArguments: TaskArguments, { ethers }) {
    const signers = await ethers.getSigners();
    const deployer = signers[0];

    console.log("Deployer address: ", deployer.address);
    console.log("Deployer balance: ", (await deployer.getBalance()).toString());

    const greeter: Greeter = await new Greeter__factory(deployer).deploy(taskArguments.greeting);

    await greeter.deployed();

    console.log("Greeter deployed to: ", greeter.address);
  });
