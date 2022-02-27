const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DiamondHand", function () {
  it("DiamondHand test...", async function () {

    const [owner,invester] = await ethers.getSigners();
    //console.log("Treasury address: " +owner.address);
    console.log("Invester address: " +invester.address);
    const YfiagG = await ethers.getContractFactory("YfiagERC20");
    const yfiag = await YfiagG.deploy();
    await yfiag.deployed();
    let treasury = await yfiag.balanceOf(owner.address);
    console.log("Treasury YFIAG balance: " +treasury.toString());

    await yfiag.approve(invester.address,1000000);
    await yfiag.transfer(invester.address,1000000);
    let investerBalance = await yfiag.balanceOf(invester.address);
    console.log("Invester YFIAG balance: " +investerBalance.toString());
    const DiamondHand = await ethers.getContractFactory("DiamondHand");
    const diamond = await DiamondHand.deploy(yfiag.address,owner.address);
    await diamond.deployed();

    await yfiag.approve(diamond.address,treasury);

    /// start checking

    const config = [
      {
        apy:10,
        duration: 3 * 30 * 24 * 60 * 60,
        halfDuration: Math.round((3 * 30 * 24 * 60 * 60) / 2)
      },
      {
        apy:30,
        duration:6 * 30 * 24 * 60 * 60,
        halfDuration: Math.round((6 * 30 * 24 * 60 * 60) / 2)
      },
      {
        apy:60,
        duration:365 * 24 * 60 * 60,
        halfDuration: Math.round((365 * 24 * 60 * 60) / 2)
      }
    ]
    let deposit = 1000;
    let poolSetting = 1;
    console.log(`---------------Deposit test------------------`);
    console.log(`Deposited amount : ${deposit}`);
    console.log(`Pool setting : ${JSON.stringify(config[poolSetting])}`);
    await yfiag.connect(invester).approve(diamond.address,deposit);
    await diamond.connect(invester).deposit(deposit,poolSetting);
    console.log("Invester YFIAG balance: " +(await yfiag.balanceOf(invester.address)).toString());
    
    await network.provider.send("evm_increaseTime", [config[poolSetting].halfDuration]);
    await network.provider.send("evm_mine");


    let pending = await diamond.pendingYFIAG(0,invester.address);

    console.log(`Pending ` + pending.toNumber() / 10**12);
    await network.provider.send("evm_increaseTime", [config[poolSetting].halfDuration]);
    await network.provider.send("evm_mine");

    await diamond.connect(invester).withdraw(invester.address,0);

    
    let b = await yfiag.balanceOf(invester.address);

    console.log("Invester YFIAG balance: " +b.toString());


    let treasury2 = await yfiag.balanceOf(owner.address);
    console.log("Treasury YFIAG balance: " +treasury2.toString());
    expect(investerBalance.toNumber() + (deposit * config[poolSetting].apy / 100)).to.equal(b.toNumber());

    let total = await diamond.allClaimed();
    let poolLength = await diamond.poolLength();
    console.log(`Total`,total.toString())
    console.log(`poolLength`,poolLength.toString())

    await diamond.emergencyWithdraw();
    //Owner 
    await diamond.updatePoolApySetting(0,20);
    let pSetting = await  diamond.poolSetting(0);
    expect(pSetting.apy.toNumber()).to.equal(20);
    console.log(pSetting.apy.toString());
    
    //Not owner
    //await diamond.connect(invester).updatePoolApySetting(0,20);


     //Owner 1 day
     await diamond.updatePoolDurationSetting(0,(24 * 60 * 60));

     await diamond.updateTreasury(invester.address);
     console.log((await diamond.TREASURY()).toString())
     pSetting = await diamond.poolSetting(0);
     expect(pSetting.duration.toNumber()).to.equal((24 * 60 * 60));
     console.log(pSetting.duration.toString());
     //Not owner
     //await diamond.connect(invester).updatePoolDurationSetting(0,(24 * 60 * 60));


  });
});
