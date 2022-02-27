const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("master", function () {
  it("Should return the new master once it's changed", async function () {

    const [owner,invester,invester2] = await ethers.getSigners();
    //console.log("Treasury address: " +owner.address);
    //console.log("Invester address: " +invester.address);
    const YfiagG = await ethers.getContractFactory("YfiagERC20");
    const yfiag = await YfiagG.deploy();
    await yfiag.deployed();

    const YfiagVirtualToken = await ethers.getContractFactory("YfiagVirtualToken");
    const yfiagv = await YfiagVirtualToken.deploy(yfiag.address);
    await yfiagv.deployed();


    await yfiag.approve(invester.address,1000000);
    await yfiag.transfer(invester.address,1000000);

    await yfiag.approve(invester2.address,1000000);
    await yfiag.transfer(invester2.address,1000000);
    
    let investerBalance = await yfiag.balanceOf(invester.address);
    console.log("Invester YFIAG balance: " +investerBalance.toString());

    const MasterVault = await ethers.getContractFactory("MasterVault");
    const master = await MasterVault.deploy(yfiag.address,yfiagv.address,owner.address);
    await master.deployed();
    await master.updateMasterSupplier(owner.address);
    await yfiagv.transferOwnership(master.address);
    await yfiag.approve(master.address,18000000000000);

    let deposit = 17000;
    let duration = 30 * 24 * 60 * 60;

    await yfiag.connect(invester).approve(master.address,deposit);

    await master.connect(invester).enterStaking(deposit);
    

    for (let index = 0; index < 28800 / 2; index++) {
      await network.provider.send("evm_mine");
    }

    await yfiag.connect(invester2).approve(master.address,100000);

    await master.connect(invester2).enterStaking(100000);


    //await master.connect(invester).leaveStaking(deposit);

    //investerBalance = await yfiag.balanceOf(invester.address);
    //console.log("Invester YFIAG balance: " +investerBalance.toString());

    let pending = await master.pendingYfiag(0,invester.address);
    let pending2 = await master.pendingYfiag(0,invester2.address);
    console.log(`Pending ` + pending.toString());
    console.log(`Pending ` + pending2.toString());
    
  });
});
