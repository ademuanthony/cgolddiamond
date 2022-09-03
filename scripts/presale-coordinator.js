// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // We get the contract to deploy
  const C250GoldPresale = await hre.ethers.getContractFactory("TokenMarket");
  const c250Gold = await C250GoldPresale.deploy("process.env.DEPLOYED_DIAMOND_ADDRESS", 1, 1);

  await c250Gold.deployed();

  console.log("TokenMarket deployed to:", c250Gold.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
