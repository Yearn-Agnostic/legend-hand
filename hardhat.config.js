require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ganache");
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

module.exports = {
  solidity: "0.6.12",
  
  networks: {
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/f7b6615c064a4003aad244f4ee088191`,
      accounts: [`0x91567866ffbacbdb623e7114d7b0ace80c187a1ca69aed94573e7695bf41aa31`]
    },
    bscTestnet: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545/`,
      accounts: [`0x3590ea66a0a44e34ec307c142cabbe0b468c11791dbbb752c2dd9e861a169762`]
    }
  },
  etherscan: {
    apiKey: "EECC3R44MHDXK862BF2YVI26KQI9757NAF",//bscscan
    //apiKey: "45QCR35X7V6I5PWIBGKC2AA7Y8HSV1AY4M", // ethscan
  }
};
