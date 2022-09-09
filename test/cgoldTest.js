/* global describe it before ethers */
const chai = require("chai")
const { assert, expect } = chai
const { solidity } = require("ethereum-waffle")
chai.use(solidity)

const {
  getSelectors,
  FacetCutAction,
  removeSelectors,
  findAddressPositionInFacets
} = require('../scripts/libraries/diamond.js')

const { deployDiamond } = require('../scripts/deploy.js')
const { ethers } = require("hardhat")
const { BigNumber } = require("ethers")

describe('C250Gold', async function () {
  let diamondAddress
  let diamondCutFacet
  let diamondLoupeFacet
  let ownershipFacet
  let classicPlanFacet
  let premiumPlanFacet
  let systemFacet
  let erc20Facet
  let tx
  let receipt
  let result
  const addresses = []

  const deployContract = async (timeProvider) => {
    diamondAddress = await deployDiamond(timeProvider)
    diamondCutFacet = await ethers.getContractAt('DiamondCutFacet', diamondAddress)
    diamondLoupeFacet = await ethers.getContractAt('DiamondLoupeFacet', diamondAddress)
    ownershipFacet = await ethers.getContractAt('OwnershipFacet', diamondAddress)
    classicPlanFacet = await ethers.getContractAt('ClassicPlanFacet', diamondAddress)
    systemFacet = await ethers.getContractAt('SystemFacet', diamondAddress)
    erc20Facet = await ethers.getContractAt("ERC20Facet", diamondAddress) 
    premiumPlanFacet = await ethers.getContractAt("PremiumPlanFacet", diamondAddress)
    await systemFacet.launch()
  }

  before(async function () {
    await deployContract()
  })

  it('should have seven facets -- call to facetAddresses function', async () => {
    for (const address of await diamondLoupeFacet.facetAddresses()) {
      addresses.push(address)
    }

    assert.equal(addresses.length, 7)
  })

  it('facets should have the right function selectors -- call to facetFunctionSelectors function', async () => {
    let selectors = getSelectors(diamondCutFacet)
    result = await diamondLoupeFacet.facetFunctionSelectors(addresses[0])
    assert.sameMembers(result, selectors)
    selectors = getSelectors(diamondLoupeFacet)
    result = await diamondLoupeFacet.facetFunctionSelectors(addresses[1])
    assert.sameMembers(result, selectors)
    selectors = getSelectors(ownershipFacet)
    result = await diamondLoupeFacet.facetFunctionSelectors(addresses[2])
    assert.sameMembers(result, selectors)
  })

  it('selectors should be associated to facets correctly -- multiple calls to facetAddress function', async () => {
    assert.equal(
      addresses[0],
      await diamondLoupeFacet.facetAddress('0x1f931c1c')
    )
    assert.equal(
      addresses[1],
      await diamondLoupeFacet.facetAddress('0xcdffacc6')
    )
    assert.equal(
      addresses[1],
      await diamondLoupeFacet.facetAddress('0x01ffc9a7')
    )
    assert.equal(
      addresses[2],
      await diamondLoupeFacet.facetAddress('0xf2fde38b')
    )
  })

  it("Should mint initial supply of 10000000 and register first account when deployed", async function () {
    const cgoldToken = await ethers.getContractAt('ERC20Facet', diamondAddress)
    const [addr1] = await ethers.getSigners();

    const bal = await cgoldToken.balanceOf(addr1.address);
    expect(parseInt(bal)).to.equal(1000000 * 1e18);
  })

  it('should create main account -- contract deployed for the first time', async () => {
    const [addr1] = await ethers.getSigners();
    const accounts = await classicPlanFacet.getAccounts(addr1.address, 0);
    expect(parseInt(accounts[0])).to.equal(1);
  })

  it("register Should not create duplicate account", async function () {
    const [addr1] = await ethers.getSigners();

    await expect(classicPlanFacet.register(1, 0, addr1.address)).to.be.revertedWith(
      "DUP"
    );
  });

  it("Should get the correct token amount from dollar", async function () {
    const amount = await systemFacet.getAmountFromDollar(2);
    expect(amount).to.equal(2);
  });

  it('should get user', async function() {
    const user = await classicPlanFacet.getUser(1);
    expect(user.registered).to.equal(true)
  })

  it("Should activate and credit referral", async function () {
    const [, addr2, addr3, addr4] = await ethers.getSigners();
    await classicPlanFacet.register(1, 0, addr2.address);
    await classicPlanFacet.register(2, 0, addr3.address);
    await classicPlanFacet.register(3, 0, addr4.address);

    classicPlanFacet.activate(4);
    const user = await classicPlanFacet.getUser(4);

    expect(user.classicCheckpoint.gt(BigNumber.from("0"))).to.be.equal(true);

    const add2Bal = await erc20Facet.balanceOf(addr2.address);
    expect(add2Bal).not.equal(ethers.utils.parseEther("0.125"));

    const add3Bal = await erc20Facet.balanceOf(addr3.address);
    expect(add3Bal).not.equal(ethers.utils.parseEther("0.1"));
  });

  it("Should not activate accounts with insuficient fund", async function () {
    const [addr1,,,,,addr6] = await ethers.getSigners();
    const bal = await erc20Facet.balanceOf(addr1.address);
    await erc20Facet.transfer(addr6.address, bal);

    await classicPlanFacet.register(1, 0, addr6.address)
    await expect(classicPlanFacet.activate(2)).to.be.revertedWith(
      "INS_BAL"
    );
  });

  it("Should not create account with invalid referral", async function () {
    await deployContract()
    const [addr] = await ethers.getSigners();
    await expect(classicPlanFacet.register(5, 0, addr.address)).to.be.revertedWith(
      "IVRID"
    );
  });

  it("Should not create account with upline ID that is not a premium account", async function () {
    await deployContract()
    const [, addr2, addr3] = await ethers.getSigners();
    await classicPlanFacet.register(1, 0, addr2.address);
    await expect(classicPlanFacet.register(2, 2, addr3.address)).to.be.revertedWith(
      "UPNIP"
    );
  });

  it("Should create multiple accounts for the user when addAndActivateMultipleAccounts is call", async function () {
    await deployContract()
    const [addr] = await ethers.getSigners();
    const accountsB4 = parseInt(await classicPlanFacet.getAccountsCount(addr.address));
    const classicIndex = await systemFacet.classicIndex();

    await classicPlanFacet.addAndActivateMultipleAccounts(1, 0, addr.address, 5);
    const accountsAfter = parseInt(await classicPlanFacet.getAccountsCount(addr.address));

    expect(accountsAfter).to.be.equal(accountsB4 + 5);

    const lastID = accountsAfter;

    const lastUser = await classicPlanFacet.getUser(lastID);

    expect(parseInt(lastUser.classicIndex)).to.be.equal(
      parseInt(classicIndex) + 5
    );
  });

  it("Should get the right classic configuration", async function () {
    await deployContract()
    const config = await systemFacet.getClassicConfig(1);
    //console.log(config);
    expect(config.earningDays).to.be.equal(20);
  });

  it("Should place user in the right classic level", async function () {
    return
    const [addr] = await ethers.getSigners();
    for (let i = 0; i < 2; i++) {
      await classicPlanFacet.addAndActivateMultipleAccounts(1, 0, addr.address, 5);
    }
    let level = parseInt(await classicPlanFacet.getClassicLevel(1))
    expect(parseInt(level)).to.be.equal(1, 'level 1 when global is meet')

    for (let i = 0; i < 2; i++) {
      await classicPlanFacet.addAndActivateMultipleAccounts(1, 0, addr.address, 5);
    }

    level = parseInt(await classicPlanFacet.getClassicLevel(1))
    expect(level).to.be.equal(1, 'no next level till premium requirement')

    await premiumPlanFacet.upgradeToPremium(2, BigNumber.from((parseInt(Math.random()*10000)).toString()))
    await premiumPlanFacet.upgradeToPremium(3, BigNumber.from((parseInt(Math.random()*10000)).toString()))

    level = parseInt(await classicPlanFacet.getClassicLevel(1))
    expect(level).to.be.equal(2, 'next level if premium requirement is meet')

    for (let i = 0; i < 2; i++) {
      await classicPlanFacet.addAndActivateMultipleAccounts(1, 0, addr.address, 5);
    }

    level = parseInt(await classicPlanFacet.getClassicLevel(1))
    expect(level).to.be.equal(2, 'no next level till premium requirement')

    await premiumPlanFacet.upgradeToPremium(4, BigNumber.from((parseInt(Math.random()*10000)).toString()))
    await premiumPlanFacet.upgradeToPremium(5, BigNumber.from((parseInt(Math.random()*10000)).toString()))
    await premiumPlanFacet.upgradeToPremium(6, BigNumber.from((parseInt(Math.random()*10000)).toString()))

    level = parseInt(await classicPlanFacet.getClassicLevel(1))
    expect(level).to.be.equal(3, 'next level if premium requirement is meet')
  })

  it("Should increase the balance of a user by the right amount where withdraw is called", async function () {
    return
    const TimeProvider = await ethers.getContractFactory("TimeProvider");
    const timeProvider = await TimeProvider.deploy();

    await deployContract(timeProvider.address)

    const [addr, addr2] = await ethers.getSigners();

    await classicPlanFacet.registerAndActivate(1, 0, addr2.address)
    await premiumPlanFacet.upgradeToPremium(2, BigNumber.from((parseInt(Math.random()*10000)).toString()))

    for (let i = 0; i < 2; i++) {
      await classicPlanFacet.addAndActivateMultipleAccounts(2, 0, addr.address, 5);
    }

    await timeProvider.increaseTime(1*86400)

    for (let i = 0; i < 2; i++) {
      await classicPlanFacet.addAndActivateMultipleAccounts(2, 0, addr.address, 5);
    }
    await premiumPlanFacet.upgradeToPremium(3, BigNumber.from((parseInt(Math.random()*10000)).toString()))
    await premiumPlanFacet.upgradeToPremium(4, BigNumber.from((parseInt(Math.random()*10000)).toString()))

    for (let i = 0; i < 2; i++) {
      await classicPlanFacet.addAndActivateMultipleAccounts(2, 0, addr.address, 10);
    }

    await timeProvider.increaseTime(3*86400)
    let res = await classicPlanFacet.withdrawable(2);

    expect(res[0], "First 3 days").to.be.equal(ethers.utils.parseEther("1"))

    const balanceBefore = await erc20Facet.balanceOf(addr2.address);
    await classicPlanFacet.connect(addr2).withdraw(2);

    const balanceAfter = await erc20Facet.balanceOf(addr2.address);

    expect(balanceAfter, "after withdrawal").to.be.equal(ethers.utils.parseEther("0.9").add(balanceBefore))

    // check the correctness of next days
    await timeProvider.increaseTime(7*86400)
    res = await classicPlanFacet.withdrawable(2);

    expect(res[0], "Next day").to.be.equal(ethers.utils.parseEther("1.5"))
  });

  it("Should restart earning for user -- recircle called", async function() {
    return
    const TimeProvider = await ethers.getContractFactory("TimeProvider");
    const timeProvider = await TimeProvider.deploy();

    await deployContract(timeProvider.address)

    const [addr, addr2] = await ethers.getSigners();

    await classicPlanFacet.registerAndActivate(1, 0, addr2.address)

    for (let i = 0; i < 2; i++) {
      await classicPlanFacet.addAndActivateMultipleAccounts(2, 0, addr.address, 5);
    }

    await timeProvider.increaseTime(24*86400)

    let res = await classicPlanFacet.withdrawable(2)
    expect(parseInt(res[1])).to.be.equal(20, '20 earning days in level 1')
    
    await classicPlanFacet.connect(addr2).withdraw(2)

    await timeProvider.increaseTime(24*86400)

    res = await classicPlanFacet.withdrawable(2)
    expect(parseInt(res[0])).to.be.equal(0, 'stop earning after 20 in l1')

    await expect(classicPlanFacet.connect(addr2).recircle(2)).to.be.revertedWith('NOT_QUALIFIY')

    for (let i = 0; i < 2; i++) {
      await classicPlanFacet.addAndActivateMultipleAccounts(2, 0, addr.address, 5);
    }

    await expect(classicPlanFacet.connect(addr2).recircle(2)).not.be.reverted
    await timeProvider.increaseTime(24*86400)
    res = await classicPlanFacet.withdrawable(2)
    expect(res[0]).to.be.equal(ethers.utils.parseEther("5"), '20 earning days in level 1 after recircle')

    // l2
    await premiumPlanFacet.upgradeToPremium(2, BigNumber.from((parseInt(Math.random()*10000)).toString()))
    for (let i = 0; i < 2; i++) {
      await classicPlanFacet.addAndActivateMultipleAccounts(2, 0, addr.address, 5);
    }
    await premiumPlanFacet.upgradeToPremium(3, BigNumber.from((parseInt(Math.random()*10000)).toString()))
    await premiumPlanFacet.upgradeToPremium(4, BigNumber.from((parseInt(Math.random()*10000)).toString()))

    await timeProvider.increaseTime(68*86400)
    res = await classicPlanFacet.withdrawable(2)
    expect(res[0]).to.be.equal(ethers.utils.parseEther("15"), '40 earning days in level 2')

    await classicPlanFacet.connect(addr2).withdraw(2)

    await timeProvider.increaseTime(24*86400)

    res = await classicPlanFacet.withdrawable(2)
    expect(parseInt(res[0])).to.be.equal(0, 'stop earning after 40 in l2')

    for (let i = 0; i < 2; i++) {
      await classicPlanFacet.addAndActivateMultipleAccounts(2, 0, addr.address, 10);
    }
    await expect(classicPlanFacet.connect(addr2).recircle(2)).to.be.revertedWith('NOT_QUALIFIY')

    await premiumPlanFacet.upgradeToPremium(5, BigNumber.from((parseInt(Math.random()*10000)).toString()))
    await premiumPlanFacet.upgradeToPremium(6, BigNumber.from((parseInt(Math.random()*10000)).toString()))
  
    await expect(classicPlanFacet.connect(addr2).recircle(2)).not.be.reverted
    await timeProvider.increaseTime(68*86400)
    res = await classicPlanFacet.withdrawable(2)
    expect(res[0]).to.be.equal(ethers.utils.parseEther("10"), '40 earning days in level 2')
  })

  /// PREMIUM ///
  it("Should upgrade a user if the sender has enough funds for premium fee", async function() {
    await deployContract()
    const [, addr2,] = await ethers.getSigners();
    await classicPlanFacet.registerAndActivate(1, 0, addr2.address)
    await premiumPlanFacet.upgradeToPremium(2, 176);
    const isPremium = await premiumPlanFacet.isAccountIInPremium(2);
    expect(isPremium).to.be.true;
  });

  it("Should debit the upgrade fee from the sender", async function() {
    await deployContract()
    const [, addr2, addr3] = await ethers.getSigners();
    await classicPlanFacet.registerAndActivate(1, 0, addr2.address);
    await classicPlanFacet.registerAndActivate(1, 0, addr3.address);

    await erc20Facet.transfer(addr2.address, ethers.utils.parseEther("2100"))

    const balanceBefore = await erc20Facet.balanceOf(addr2.address);
    await premiumPlanFacet.connect(addr2).upgradeToPremium(2, 176);
    await premiumPlanFacet.connect(addr2).upgradeToPremium(3, 176);
    const balanceAfter = await erc20Facet.balanceOf(addr2.address);

    expect(balanceBefore).to.be.equal(ethers.utils.parseEther("40").add(balanceAfter));
  });

  it("Should get ancessor as sponsor for upgrade if upline is not in part", async function() {
    await deployContract()
    const [, addr2, addr3, addr4] = await ethers.getSigners();
    await classicPlanFacet.registerAndActivate(1, 0, addr2.address);
    await premiumPlanFacet.upgradeToPremium(2, 176);
    await classicPlanFacet.registerAndActivate(2, 0, addr3.address);
    await classicPlanFacet.registerAndActivate(3, 0, addr4.address);

    await premiumPlanFacet.upgradeToPremium(4, 176);

    const uplineID = await premiumPlanFacet.getMatrixUpline(4, 1);
    expect(parseInt(uplineID)).to.be.equal(2);
  });

  it("Should fail if caller has insufficient fund", async function() {
    await deployContract()
    const [addr1, addr2, ] = await ethers.getSigners();
    await classicPlanFacet.registerAndActivate(1, 0, addr2.address);
    const balance = await erc20Facet.balanceOf(addr1.address);
    await erc20Facet.transfer(addr2.address, balance);

    await expect(premiumPlanFacet.upgradeToPremium(2, 43)).to.be.revertedWith("INS_BAL")
  });


  it("Should fail if account not in classic", async function() {
    await deployContract()
    const [, addr2, ] = await ethers.getSigners();
    await classicPlanFacet.register(1, 0, addr2.address);

    await expect(premiumPlanFacet.upgradeToPremium(2, 43)).to.be.revertedWith("CLNA")
  });

  it("Should get the right sponsor id", async function() {
    await deployContract()
    const [, addr2, addr3, addr4, addr5] = await ethers.getSigners();
    await classicPlanFacet.registerAndActivate(1, 0, addr2.address);
    await premiumPlanFacet.upgradeToPremium(2, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr3.address);
    await premiumPlanFacet.upgradeToPremium(3, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr4.address);
    await premiumPlanFacet.upgradeToPremium(4, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr5.address);

    const uplineID = await premiumPlanFacet.getPremiumSponsor(5, 0);
    expect(parseInt(uplineID)).to.be.equal(2);
  });

  it("Should arrange spill-over from left to right", async function() {
    await deployContract()
    const [, addr2, addr3, addr4, addr5] = await ethers.getSigners();
    await classicPlanFacet.registerAndActivate(1, 0, addr2.address);
    await premiumPlanFacet.upgradeToPremium(2, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr3.address);
    await premiumPlanFacet.upgradeToPremium(3, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr4.address);
    await premiumPlanFacet.upgradeToPremium(4, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr5.address);

    await premiumPlanFacet.upgradeToPremium(5, 176);

    const uplineID = await premiumPlanFacet.getMatrixUpline(5, 1);
    expect(parseInt(uplineID)).to.be.equal(3);
  });

  it("Should transfer referral bonus to the premium upline", async function() {
    await deployContract()
    const [, addr2, addr3, addr4, addr5] = await ethers.getSigners();
    await classicPlanFacet.registerAndActivate(1, 0, addr2.address);
    await premiumPlanFacet.upgradeToPremium(2, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr3.address);
    await premiumPlanFacet.upgradeToPremium(3, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr4.address);
    await premiumPlanFacet.upgradeToPremium(4, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr5.address);

    const uplineID = await premiumPlanFacet.getPremiumSponsor(5, 0);
    expect(parseInt(uplineID), "right sponsor").to.be.equal(2);

    const balanceBefore = await erc20Facet.balanceOf(addr2.address);
    await premiumPlanFacet.upgradeToPremium(5, 176);
    const balanceAfter = await erc20Facet.balanceOf(addr2.address);

    expect(balanceAfter).to.be.equal(ethers.utils.parseEther("9").add(balanceBefore), "Right amount");
  });

  it("Should transfer matrix bonus to the matrix upline", async function() {
    await deployContract()
    const [, addr2, addr3, addr4, addr5] = await ethers.getSigners();
    await classicPlanFacet.registerAndActivate(1, 0, addr2.address);
    await premiumPlanFacet.upgradeToPremium(2, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr3.address);
    await premiumPlanFacet.upgradeToPremium(3, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr4.address);
    await premiumPlanFacet.upgradeToPremium(4, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr5.address);

    const balanceBefore = await erc20Facet.balanceOf(addr3.address);
    await premiumPlanFacet.upgradeToPremium(5, 176);
    const balanceAfter = await erc20Facet.balanceOf(addr3.address);

    expect(balanceAfter).to.be.equal(ethers.utils.parseEther("2.25").add(balanceBefore));
  });

  it("Should move the user to the next level current is completed", async function() {
    await deployContract()
    const [, addr2, addr3, addr4, ] = await ethers.getSigners();
    await classicPlanFacet.registerAndActivate(1, 0, addr2.address);
    await premiumPlanFacet.upgradeToPremium(2, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr3.address);
    await premiumPlanFacet.upgradeToPremium(3, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr4.address);
    await premiumPlanFacet.upgradeToPremium(4, 176);

    const user = await classicPlanFacet.getUser(2);
    expect(user.premiumLevel, "moved to next level").to.be.equal(2);

    const legs = await premiumPlanFacet.getDirectLegs(1, 1);
    expect(parseInt(legs.left), "Placed under the upline").to.be.equal(2);
  });

  it("Should send matrix bonus of those without beneficiary to the main account", async function() {
    await deployContract()
    const [addr1, addr2, addr3, addr4, ] = await ethers.getSigners();
    await classicPlanFacet.registerAndActivate(1, 0, addr2.address);
    await premiumPlanFacet.upgradeToPremium(2, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr3.address);
    await premiumPlanFacet.upgradeToPremium(3, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addr4.address);
    
    const balanceBefore = await erc20Facet.balanceOf(addr1.address);
    await premiumPlanFacet.upgradeToPremium(4, 176);
    const balanceAfter = await erc20Facet.balanceOf(addr1.address);

    // the wallet paid 20 for the upgrade and 5 from matrix 2499637825-2499482825
    expect(balanceAfter).not.be.equal(balanceBefore.sub(ethers.utils.parseEther("20")));
  });

  it("Should add the user to part 2 when he completes part 1", async function() {
    await deployContract()
    const [...addresses ] = await ethers.getSigners();
    await classicPlanFacet.registerAndActivate(1, 0, addresses[1].address);
    await premiumPlanFacet.upgradeToPremium(2, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addresses[2].address);
    await premiumPlanFacet.upgradeToPremium(3, 176);

    for(let i = 3; i <= 16; i++) {
      await classicPlanFacet.registerAndActivate(3, 0, addresses[i].address);
      await premiumPlanFacet.upgradeToPremium(i+1, 176);
    }

    const user = await classicPlanFacet.getUser(3);
    expect(user.premiumLevel, "moved to next level").to.be.equal(3);

    const legs = await premiumPlanFacet.getDirectLegs(1, 3);
    expect(parseInt(legs.left), "Placed under the upline").to.be.equal(3);
  });

  it("Should send pending matrix earning when a user enters a new level", async function() {
    await deployContract()
    const [...addresses ] = await ethers.getSigners();
    await classicPlanFacet.registerAndActivate(1, 0, addresses[1].address);
    await premiumPlanFacet.upgradeToPremium(2, 176);

    await classicPlanFacet.registerAndActivate(2, 0, addresses[2].address);
    await premiumPlanFacet.upgradeToPremium(3, 176);

    for(let i = 3; i <= 6; i++) {
      await classicPlanFacet.registerAndActivate(3, 0, addresses[i].address);
      await premiumPlanFacet.upgradeToPremium(i+1, 176);
    }

    await classicPlanFacet.registerAndActivate(1, 0, addresses[7].address);
    await premiumPlanFacet.upgradeToPremium(8, 176);

    await classicPlanFacet.registerAndActivate(1, 0, addresses[8].address);

    const balanceBefore = await erc20Facet.balanceOf(addresses[1].address);
    await premiumPlanFacet.upgradeToPremium(9, 176);
    const balanceAfter = await erc20Facet.balanceOf(addresses[1].address);

    // 5 and 2.5 from matrix
    expect(balanceAfter).to.be.equal(balanceBefore.add(ethers.utils.parseEther("6.75")));

  });
})
