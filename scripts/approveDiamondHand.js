
const { ethers } = require("hardhat");
const hre = require("hardhat");
async function main() {
  
  const accounts = await hre.ethers.getSigners()
  const Yfiag = await ethers.getContractFactory("YfiagERC20");
  const yfiag = new ethers.Contract('0x208e4E53f9872bC3636790dBDAD2E7B983894C2a', Yfiag.interface, accounts[0]);

  // let treasury = await yfiag.balanceOf("0xeFfe75B1574Bdd2FE0Bc955b57e4f82A2BAD6bF9");
  // console.log("treasury deployed to:", treasury.toString());
  // const diamondHand = await ethers.getContractFactory("DiamondHand");
  // const diamond = new ethers.Contract('0x97A50Cd3dcc0DBc40aFdB5665B0e0e6d72c15A20', diamondHand.interface, accounts[0]);

  // await yfiag.approve(diamond.address,treasury);

  let approval = await yfiag.allowance("0xeFfe75B1574Bdd2FE0Bc955b57e4f82A2BAD6bF9","0x97A50Cd3dcc0DBc40aFdB5665B0e0e6d72c15A20");
  console.log("approval balance :", approval.toString());
  

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
