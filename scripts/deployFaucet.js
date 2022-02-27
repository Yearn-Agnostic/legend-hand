
const hre = require("hardhat");

async function main() {
  
  const YfiagTreasury = await hre.ethers.getContractFactory("YfiagTreasury");
  const treasury = await YfiagTreasury.deploy("0x208e4E53f9872bC3636790dBDAD2E7B983894C2a");

  await treasury.deployed();

  console.log("YfiagTreasury deployed to:", treasury.address);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
