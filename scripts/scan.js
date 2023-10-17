const main = async () => {

  const diamondAddress = process.env.DEPLOYED_DIAMOND_ADDRESS
  const accounts = await ethers.getSigners()
  const contractOwner = accounts[0]

  console.log('owner', contractOwner.address);

  const ERC20ExtensionFacet = await ethers.getContractFactory('ERC20ExtensionFacet');
  const eRC20ExtensionFacet = await ERC20ExtensionFacet.attach(diamondAddress);
}

main();
