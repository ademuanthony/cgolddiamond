/* global ethers */
/* eslint prefer-const: "off" */
const hre = require('hardhat')

async function deployDiamond () {
  
  // deploy CGoldArtefact
  const C250PriceOracle = await ethers.getContractFactory('C250PriceOracle')
  const c250PriceOracle = await C250PriceOracle.deploy()
  await c250PriceOracle.deployed()
  console.log('C250PriceOracle deployed:', c250PriceOracle.address)

  const SystemFacet = await ethers.getContractFactory('SystemFacet')
  let system = await SystemFacet.attach(process.env.DEPLOYED_DIAMOND_ADDRESS);

  await system.setPriceOracle(c250PriceOracle.address)

  return c250PriceOracle.address
} 

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
  deployDiamond()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    })
}

exports.deployDiamond = deployDiamond
