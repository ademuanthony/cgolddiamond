/* global ethers */
/* eslint prefer-const: "off" */
require('dotenv').config()

const { getSelectors, FacetCutAction } = require('./libraries/diamond.js')

async function deployDiamond () {
  const diamondAddress = process.env.DEPLOYED_DIAMOND_ADDRESS
  const accounts = await ethers.getSigners()
  const contractOwner = accounts[0]

  console.log('owner', contractOwner.address);

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
  // let diamondInit = await DiamondInit.deploy()
  let diamondInit = DiamondInit.attach(process.env.DIAMOND_INIT_ADDRESS)
  // await diamondInit.deployed()
  console.log('DiamondInit deployed:', diamondInit.address)

  const diamondInitAddress = diamondInit.address

  console.log('Deploying facets')
  const FacetNames = [
    //'GlobalFacet',
    //'SystemFacet',
    //'SystemFacet2',
    //'ClassicPlanFacet',
    //'ClassicExplorerFacet',
    //'PremiumPlanFacet',
    //'PremiumExtensionFacet',
    //'MigrationFacet',
    //'Migration2Facet',
    //'Migration3Facet',
    //'RecoveryFacet',
    // 'V3UpdateAndFix'
    //'ERC20ExtensionFacet'
    'ERC20ExtensionV2Facet'
    // 'ERC20Facet'
  ]
  const cut = []
  for (const FacetName of FacetNames) {
    const Facet = await ethers.getContractFactory(FacetName)
    const facet = await Facet.deploy()
    await facet.deployed()
    //const facet = await Facet.attach(diamondAddress)
    console.log(`${FacetName} deployed: ${facet.address}`)
    cut.push({
      //facetAddress: ethers.constants.AddressZero,
      facetAddress: facet.address,
      //action: FacetCutAction.Remove,
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(facet)
    })
  }

  // upgrade diamond with facets
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

  const SystemFacet = await ethers.getContractFactory('SystemFacet');
  const systemContract = await SystemFacet.attach(diamondAddress);
  await systemContract.setPriceOracle('0x949c7a1f33c5ca3b1ad346e273d6653910775082');
  console.log('Updated price oracle');

  const ERC20ExtensionFacet = await ethers.getContractFactory('ERC20ExtensionFacet');
  const eRC20ExtensionFacet = await ERC20ExtensionFacet.attach(diamondAddress);
  
  await eRC20ExtensionFacet.setExchange('0xBD0731bD724556aDc56888727307EEe688b773d6', true);
 
  await eRC20ExtensionFacet.blacklist('0xC3ff25a334f43fedE289b0dC0EEcfe2f688f9dDA', true);
  // 0xBD0731bD724556aDc56888727307EEe688b773d6
  // blacklist
  console.log('ERC20ExtensionFacet setExchange');

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
