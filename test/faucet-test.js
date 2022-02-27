const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Faucet", function () {
  it("Should return the new DiamondHand once it's changed", async function () {

    const [owner,begger] = await ethers.getSigners();
    console.log("owner address: " +owner.address);
    console.log("begger address: " +begger.address);
    const YfiagG = await ethers.getContractFactory("YfiagERC20");
    const yfiag = await YfiagG.deploy();
    await yfiag.deployed();

    let investerBalance = await yfiag.balanceOf(begger.address);
    console.log("begger YFIAG balance: " +investerBalance.toString());

    const Faucet = await ethers.getContractFactory("YfiagTreasury");
    const faucet = await Faucet.deploy(yfiag.address);
    await faucet.deployed();
    
    await yfiag.approve(faucet.address,10000);
    await yfiag.transfer(faucet.address,10000);

    let faucetBalance = await faucet.balanceOf();
    console.log("faucetBalance YFIAG balance: " +faucetBalance.toString());

    await faucet.faucet(begger.address);

    let b = await yfiag.balanceOf(begger.address);
    console.log("begger YFIAG balance: " +b.toString());

    expect(b.toNumber()).to.equal(1000);
  });
});
