# Diamond-2-Hardhat Implementation

An MLM platform built on [EIP-2535 Diamonds](https://github.com/ethereum/EIPs/issues/2535). To learn about other implementations go here: https://github.com/mudgen/diamond

This implementation uses Hardhat and Solidity 0.8.*

## Disclaimer
This software may contain bug and vulnurabilities that can lead to financial lost. Please employ a professional developer for your smart contract works

## Installation

1. Clone this repo:
```console 
git clone git@github.com/ademuanthony/cgolddiamond
```

2. Install NPM packages:
```console
cd cgolddiamond
npm install
```

## Deployment

```console
npx hardhat run scripts/deploy.js
```

### How the scripts/deploy.js script works

1. DiamondCutFacet is deployed.
1. The diamond is deployed, passing as arguments to the diamond constructor the owner address of the diamond and the DiamondCutFacet address. DiamondCutFacet has the `diamondCut` external function which is used to upgrade the diamond to add more functions.
1. The `DiamondInit` contract is deployed. This contains an `init` function which is called on the first diamond upgrade to initialize state of some state variables. Information on how the `diamondCut` function works is here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface
1. Facets are deployed.
1. The diamond is upgraded. The `diamondCut` function is used to add functions from facets to the diamond. In addition the `diamondCut` function calls the `init` function from the `DiamondInit` contract using `delegatecall` to initialize state variables.

How a diamond is deployed is not part of the EIP-2535 Diamonds standard. This implementation shows a usable example. 

## Run tests:
```console
npx hardhat test
```

## Upgrade a diamond

Check the `scripts/update-all.js`

## Facet Information

Check the `contract/facets/*` folder

## Calling Diamond Functions

In order to call a function that exists in a diamond you need to use the ABI information of the facet that has the function.

Here is an example that uses web3.js:

```javascript
let myUsefulFacet = new web3.eth.Contract(MyUsefulFacet.abi, diamondAddress);
```

In the code above we create a contract variable so we can call contract functions with it.

In this example we know we will use a diamond because we pass a diamond's address as the second argument. But we are using an ABI from the MyUsefulFacet facet so we can call functions that are defined in that facet. MyUsefulFacet's functions must have been added to the diamond (using diamondCut) in order for the diamond to use the function information provided by the ABI of course.

Similarly you need to use the ABI of a facet in Solidity code in order to call functions from a diamond. Here's an example of Solidity code that calls a function from a diamond:

```solidity
string result = MyUsefulFacet(address(diamondContract)).getResult()
```

## Get Help and Join the Community

If you need help or would like to discuss diamonds then send me a message [on twitter](https://twitter.com/mudgen), or [email me](mailto:nick@perfectabstractions.com). Or join the [EIP-2535 Diamonds Discord server](https://discord.gg/kQewPw2).

## Useful Links
1. [Introduction to the Diamond Standard, EIP-2535 Diamonds](https://eip2535diamonds.substack.com/p/introduction-to-the-diamond-standard)
1. [EIP-2535 Diamonds](https://github.com/ethereum/EIPs/issues/2535)
1. [Understanding Diamonds on Ethereum](https://dev.to/mudgen/understanding-diamonds-on-ethereum-1fb)
1. [Solidity Storage Layout For Proxy Contracts and Diamonds](https://medium.com/1milliondevs/solidity-storage-layout-for-proxy-contracts-and-diamonds-c4f009b6903)
1. [New Storage Layout For Proxy Contracts and Diamonds](https://medium.com/1milliondevs/new-storage-layout-for-proxy-contracts-and-diamonds-98d01d0eadb)
1. [Upgradeable smart contracts using the Diamond Standard](https://hiddentao.com/archives/2020/05/28/upgradeable-smart-contracts-using-diamond-standard)
1. [buidler-deploy supports diamonds](https://github.com/wighawag/buidler-deploy/)

## Author

This example implementation was written by Nick Mudge.

Contact:

- https://twitter.com/Oxa2e

## License

MIT license. See the license file.
Anyone can use or modify this software for their purposes.

