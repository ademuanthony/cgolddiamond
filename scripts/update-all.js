/* global ethers */
/* eslint prefer-const: "off" */
require('dotenv').config()

const { getSelectors, FacetCutAction } = require('./libraries/diamond.js')

async function deployDiamond () {
  const diamondAddress = process.env.DEPLOYED_DIAMOND_ADDRESS
  const accounts = await ethers.getSigners()
  const contractOwner = accounts[0]

  const c250PriceOracleAddress = process.env.PRICE_ORACLE_ADDRESS;

  // const MockC250PriceOracle = await ethers.getContractFactory('C250PriceOracle')
  // const c250PriceOracle = await MockC250PriceOracle.deploy()
  // await c250PriceOracle.deployed()
  // console.log('C250PriceOracle deployed:', c250PriceOracleAddress)

  // const TimeProvider = await ethers.getContractFactory('TimeProvider')
  //   const timeProvider = await TimeProvider.deploy()
  //   await timeProvider.deployed()
  //   console.log('TimeProvider deployed:', timeProvider.address)
  //   timeProviderAddress = timeProvider.address

  const DiamondInit = await ethers.getContractFactory('DiamondInit')
  let diamondInit = await DiamondInit.deploy()
  await diamondInit.deployed()
  console.log('DiamondInit deployed:', diamondInit.address)

  const diamondInitAddress = diamondInit.address

  console.log('Deploying facets')
  const FacetNames = [
    //'GlobalFacet',
    //'SystemFacet',
    'ClassicPlanFacet',
    //'PremiumPlanFacet',
    //'PremiumExtensionFacet',
  ]
  const cut = []
  for (const FacetName of FacetNames) {
    const Facet = await ethers.getContractFactory(FacetName)
    const facet = await Facet.deploy()
    await facet.deployed()
    console.log(`${FacetName} deployed: ${facet.address}`)
    cut.push({
      facetAddress: facet.address,
      action: FacetCutAction.Replace,
      functionSelectors: getSelectors(facet)
    })
  }

  // upgrade diamond with facets
  console.log('')
  const diamondCut = await ethers.getContractAt('IDiamondCut', diamondAddress)
  let tx
  let receipt
  // call to init function
  let functionCall = diamondInit.interface.encodeFunctionData('init', [
    c250PriceOracleAddress, contractOwner.address
  ])
  tx = await diamondCut.diamondCut(cut, diamondInitAddress, functionCall)
  console.log('Diamond cut tx: ', tx.hash)
  receipt = await tx.wait()
  if (!receipt.status) {
    throw Error(`Diamond upgrade failed: ${tx.hash}`)
  }
  console.log('Completed diamond cut')
  return diamondAddress
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
