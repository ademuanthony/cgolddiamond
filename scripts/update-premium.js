/* global ethers */
/* eslint prefer-const: "off" */
require('dotenv').config()

const { ethers } = require('hardhat')
const { getSelectors, FacetCutAction } = require('./libraries/diamond.js')

async function deployDiamond () {
  const diamondAddress = process.env.DEPLOYED_DIAMOND_ADDRESS
  const accounts = await ethers.getSigners()
  const contractOwner = accounts[0]
  const priceOracleAddress = process.env.PRICE_ORACLE_ADDRESS

   const timeProviderAddress = process.env.TIME_PROVIDER_ADDRESS

  const diamondInitAddress = process.env.DIAMOND_INIT_ADDRESS
  
  console.log('Deploying facets')
  const FacetNames = [
    'PremiumExtensionFacet',
  ]
  const cut = []
  for (const FacetName of FacetNames) {
    const Facet = await ethers.getContractFactory(FacetName)
    const facet = await Facet.deploy()
    await facet.deployed()
    console.log(`${FacetName} deployed: ${facet.address}`)
    cut.push({
      //facetAddress: ethers.constants.AddressZero,
      facetAddress: facet.address,
      //action: FacetCutAction.Remove,
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(facet)
    })
  }

  // if it is the first day, the classic level fails
  
  // upgrade diamond with facets
  console.log('')
  console.log('Diamond Cut:', cut)
  const diamondCut = await ethers.getContractAt('IDiamondCut', diamondAddress)
  const diamondInit = await ethers.getContractAt('DiamondInit', diamondInitAddress)
  let tx
  let receipt
  // call to init function
  let functionCall = diamondInit.interface.encodeFunctionData('init', [
    priceOracleAddress, timeProviderAddress, contractOwner.address
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
