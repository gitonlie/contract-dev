// scripts/deploy.js
const { ethers, upgrades } = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {
  const [signer,user1] = await ethers.getSigners();

  // 部署质押合约的奖励代币合约
  const MetaNodeToken = await ethers.getContractFactory('MetaNodeToken');
  const metaNodeToken = await MetaNodeToken.deploy();

  await metaNodeToken.waitForDeployment();
  const metaNodeTokenAddress = await metaNodeToken.getAddress();
  console.log("MetaNodeToken deployed to:", metaNodeTokenAddress);

  // 1. 获取合约工厂
  const MetaNodeStake = await ethers.getContractFactory("MetaNodeStake");

  // 2. 设置初始化参数（根据你的initialize函数）
  // const startBlock = 9327130; // 替换为实际起始区块
  // const endBlock = 11955130; // 替换为实际结束区块
  const startBlock = 1; // 替换为实际起始区块
  const endBlock = 9327130; // 替换为实际结束区块
  const metaNodePerBlock = ethers.parseUnits("1", 18); // 每区块奖励1个MetaNode（18位精度）

  // 3. 部署可升级代理合约
  const stake = await upgrades.deployProxy(
    MetaNodeStake,
    [metaNodeTokenAddress, startBlock, endBlock, metaNodePerBlock],
    { initializer: "initialize" }
  );

  await stake.waitForDeployment();

  // 质押合约的奖励代币转移给质押合约
  const stakeAddress = await stake.getAddress();
  const tokenAmount = await metaNodeToken.balanceOf(signer.address);
  let tx = await metaNodeToken.connect(signer).transfer(stakeAddress, tokenAmount)
  await tx.wait()
  console.log("MetaNodeStake (proxy) deployed to:", stakeAddress);

  //部署一个测试用的ERC20代币合约 用于质押
  const MyToken = await ethers.getContractFactory("MyToken");
  const baseToken = await MyToken.deploy("BaseToken", "RUSD");
  await baseToken.waitForDeployment();
  const baseTokenAddress = await baseToken.getAddress();
  console.log("BaseToken deployed to:", baseTokenAddress);
  // 为user1转账一些代币
  const signerAmount = await baseToken.balanceOf(signer.address);
  tx = await baseToken.connect(signer).transfer(user1.address, signerAmount)
  await tx.wait()

  //最后将上述合约地址写入文件
  const filePath = path.join(__dirname, '../deploy-address.json');
  const contractAddresses = {
    MetaNodeToken: metaNodeTokenAddress,
    MetaNodeStake: stakeAddress,
    BaseToken: baseTokenAddress,
    abi: MetaNodeStake.interface.format('json'),
  };
  fs.writeFileSync(filePath, JSON.stringify(contractAddresses, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


// MetaNodeToken deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
// MetaNodeStake (proxy) deployed to: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
// BaseToken deployed to: 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9