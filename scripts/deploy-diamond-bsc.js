const hre = require("hardhat");

async function main() {
  
  const DiamondHand = await hre.ethers.getContractFactory("DiamondHand");
  const master = await DiamondHand.deploy("0x916792fd41855914ba4b71285c8a05b866f0618b","0xb8E2624d3F5329D701d2aa99f2b9562399Ac4488");

  await master.deployed();

  console.log("DiamondHand deployed to:", master.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
