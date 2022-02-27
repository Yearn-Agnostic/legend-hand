
const hre = require("hardhat");

async function main() {
    const YfiagG = await ethers.getContractFactory("YfiagERC20");
    const yfiag = await YfiagG.deploy();
    await yfiag.deployed();
    console.log("YfiagERC20 deployed to:", yfiag.address);
    const DiamondHand = await hre.ethers.getContractFactory("DiamondHand");
    const master = await DiamondHand.deploy(yfiag.address, "0xeFfe75B1574Bdd2FE0Bc955b57e4f82A2BAD6bF9");

    await master.deployed();

    console.log("DiamondHand deployed to:", master.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
