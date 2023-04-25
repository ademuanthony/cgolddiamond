/* global ethers */
/* eslint prefer-const: "off" */
const hre = require('hardhat')

async function deployDiamond () {
  
  // deploy CGoldArtefact
  const CGoldArtefact = await ethers.getContractFactory('CGoldArtefact')
  const cGoldArtefact = await CGoldArtefact.deploy(
    'https://cgold-artefact.herokuapp.com/api/item/{id}.json',
    'process.env.DEPLOYED_DIAMOND_ADDRESS'
  )
  await cGoldArtefact.deployed()
  console.log('CGoldArtefact deployed:', cGoldArtefact.address)

  return cGoldArtefact.address
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
