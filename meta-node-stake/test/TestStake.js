const { ethers } = require("hardhat");
const { expect } = require("chai");
const fs = require('fs');
const path = require('path');

describe("测试质押合约的质押功能", async () => {

  //质押合约奖励token地址
  let metaNodeTokenAddress;
  //质押合约地址
  let metaNodeStakeAddress;

  //用于测试质押的ERC20地址
  let baseTokenAddress;

  //供测试的用户地址
  let deployer, user1, user2, user3;

  beforeEach("读取合约地址", async () => {
    const filePath = path.join(__dirname, '../deploy-address.json');
    const contractAddresses = JSON.parse(fs.readFileSync(filePath));
    metaNodeTokenAddress = contractAddresses.MetaNodeToken;
    metaNodeStakeAddress = contractAddresses.MetaNodeStake;
    baseTokenAddress = contractAddresses.BaseToken;

    [deployer, user1, user2, user3] = await ethers.getSigners();
  });


  it("测试质押合约的池子添加或者更新", async () => {
    //通过代理获取MetaNodeStake合约实例
    const stake = await ethers.getContractAt("MetaNodeStake", metaNodeStakeAddress);
    //添加ETH池子
    const tx1 = await stake.addPool(ethers.ZeroAddress, 60, 1000, 20, true);
    await tx1.wait();
    //添加ERC20池子
    const tx2 = await stake.addPool(baseTokenAddress, 40, 1000, 20, true);
    await tx2.wait();

    expect(await stake.poolLength()).to.equal(2);

    //更新ERC20池子
    const tx3 = await stake.updatePool(1, 2000, 50);
    await tx3.wait();

    const _pool = await stake.pool(1);
    expect(_pool.minDepositAmount).to.equal(2000);
    expect(_pool.unstakeLockedBlocks).to.equal(50);

  });


  it.only("测试质押合约的质押功能", async () => {

    const units = BigInt(1e18);

    //通过代理获取MetaNodeStake合约实例
    const stake = await ethers.getContractAt("MetaNodeStake", metaNodeStakeAddress);

    const _pool0 = await stake.pool(0);
    const _stTokenAmount_ = _pool0.stTokenAmount;
    //质押ETH
    const depositAmount = 2000;
    const tx1 = await stake.connect(user1).depositETH({ value: depositAmount });
    await tx1.wait();

    //校验
    const pool0_ = await stake.pool(0);
    expect(pool0_.stTokenAmount,"ETH池子质押金额增加校验错误").to.equal(_stTokenAmount_ + BigInt(depositAmount));

    const user01 = await stake.user(0, user1.address);
    const finishedMetaNode = BigInt(user01.stAmount) * BigInt(pool0_.accMetaNodePerST) / units;
    expect(finishedMetaNode,"ETH池子已领取奖励校验错误").to.equal(user01.finishedMetaNode);
    console.log("用户1质押ETH金额", user01.stAmount);
    console.log("用户1已领取奖励", user01.finishedMetaNode);
    console.log("用户1未领取奖励", user01.pendingMetaNode);

    //质押ERC20
    const baseToken = await ethers.getContractAt("MyToken", baseTokenAddress);

    //给质押合约授权
    const depositTokenAmount = 6000;
    await baseToken.connect(user1).approve(metaNodeStakeAddress, depositTokenAmount);
    const tx2 = await stake.connect(user1).deposit(1, depositTokenAmount);
    await tx2.wait();

    //接口实际未领取的ERC20代币奖励
    const pendingERC20Reward = await stake.pendingMetaNode(1, user1.address);

    //手动验证用户1领取奖励是否正确
    const pool1 = await stake.pool(1);
    console.log("ERC20池子质押金额", pool1.stTokenAmount);
    //首先查看当前区块高度
    const currentBlock_ = await ethers.provider.getBlockNumber();
    //计算质押ERC20合约奖励 multiplier
    const metaNodePerBlock = await stake.MetaNodePerBlock();
    const rewardAmount_ = (BigInt(currentBlock_) - BigInt(pool1.lastRewardBlock)) * BigInt(metaNodePerBlock);
    //根据权重占比计算ERC20池子奖励
    const totalPoolWeight_ = await stake.totalPoolWeight();
    const pool1Reward = BigInt(rewardAmount_) * BigInt(pool1.poolWeight) / BigInt(totalPoolWeight_);
    //累计每个抵押代币的奖励perST
    const accMetaNodePerST_ERC20 = BigInt(pool1.accMetaNodePerST) + pool1Reward * units / BigInt(pool1.stTokenAmount);
    console.log("ERC20池子accMetaNodePerST", accMetaNodePerST_ERC20);

    //计算用户1未领取ERC20奖励
    const _user11 = await stake.user(1, user1.address);
    const pendingMetaNode_ERC20 = BigInt(_user11.stAmount) * accMetaNodePerST_ERC20 / units - BigInt(_user11.finishedMetaNode) + BigInt(_user11.pendingMetaNode);

    console.log("用户1未领取ERC20奖励", pendingMetaNode_ERC20, pendingERC20Reward);
    //对比接口计算结果与手动计算结果是否一致
    expect(pendingERC20Reward, "用户1领取ERC20奖励校验失败").to.equal(pendingMetaNode_ERC20);

  });


  it("测试质押合约的解押并且提现", async () => {
    //通过代理获取MetaNodeStake合约实例
    const stake = await ethers.getContractAt("MetaNodeStake", metaNodeStakeAddress);

    const pool1 = await stake.pool(1);
    const c = pool1.stTokenAmount;

    // //解压质押ERC20
    const tx4 = await stake.connect(user1).unstake(1, 500);
    await tx4.wait();

    const _pool1 = await stake.pool(1);
    expect(_pool1.stTokenAmount, "解压后剩余ERC20池子质押金额").to.equal(c - BigInt(500));
    console.log("用户1解押后质押金额", _pool1.stTokenAmount);

    //提现前查询user1的余额
    const baseToken = await ethers.getContractAt("MyToken", baseTokenAddress);
    const user1BalanceBefore = await baseToken.balanceOf(user1.address);
    console.log("用户1解押前ERC20余额", user1BalanceBefore);

    // 挖矿 51 个区块
    await ethers.provider.send("hardhat_mine", ["0x32"]);

    //ERC20提现
    const tx5 = await stake.connect(user1).withdraw(1);
    await tx5.wait();

    //提现后查询user1的余额
    const user1BalanceAfter = await baseToken.balanceOf(user1.address);
    console.log("用户1解押后ERC20余额", user1BalanceAfter);

    const diff = user1BalanceAfter - user1BalanceBefore;
    expect(diff, "用户1解押后ERC20余额校验失败").to.equal(BigInt(500));
  });

  it("测试领取奖励功能", async () => {
    //通过代理获取MetaNodeStake合约实例
    const stake = await ethers.getContractAt("MetaNodeStake", metaNodeStakeAddress);
    //领取奖励
    const tx6 = await stake.connect(user1).claim(1);
    await tx6.wait();

    const user11 = await stake.user(1, user1.address);
    const poo11 = await stake.pool(1);
    expect(user11.pendingMetaNode, "用户1未领取的奖励不为0").to.equal(0);

    const finishedMetaNode = BigInt(user11.stAmount) * BigInt(poo11.accMetaNodePerST) / BigInt(1e18);
    expect(finishedMetaNode, "用户1已领取的奖励校验失败").to.equal(BigInt(user11.finishedMetaNode));
  })
});
