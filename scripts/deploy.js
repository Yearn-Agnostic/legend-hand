const hre = require("hardhat");
const abi = require("../abi/yfiag.abi.json");
async function main() {
  const [accounts] = await hre.ethers.getSigners();
  // const Yfiag = await ethers.getContractFactory("YfiagERC20");
  // const yfiag = await ethers.getContractFactory("YfiagERC20");
  const yfiag = new ethers.Contract(
    "0x1F64703ae00C06420dd21fE75E9Ef6E008212263",
    abi,
    accounts[0]
  );
  // const yfiag = await Yfiag.deploy();
  // await yfiag.deployed();
  console.log("YfiagERC20 deployed to:", yfiag.address);
  const DiamondHand = await hre.ethers.getContractFactory("DiamondHand");
  const master = await DiamondHand.deploy(yfiag.address, accounts.address);

  await master.deployed();

  console.log("DiamondHand deployed to:", master.address);
  let treasury = await yfiag.balanceOf(accounts.address);
  console.log("treasury balance :", treasury.toString());
  await yfiag.approve(master.address, treasury);

  let approval = await yfiag.allowance(accounts.address, master.address);
  console.log("approval balance :", approval.toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
