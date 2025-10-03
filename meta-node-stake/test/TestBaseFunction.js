const { ethers } = require("hardhat");
const { expect } = require("chai");
const fs = require('fs');
const path = require('path');

describe("测试基础功能", async ()=>{

    let metaNodeTokenAddress;
    let metaNodeStakeAddress;
    let baseTokenAddress;
    let deployer, user1, user2, user3;
    
    beforeEach("读取合约地址", async ()=>{
        const filePath = path.join(__dirname, '../deploy-address.json');
        const contractAddresses = JSON.parse(fs.readFileSync(filePath));
        metaNodeTokenAddress = contractAddresses.MetaNodeToken;
        metaNodeStakeAddress = contractAddresses.MetaNodeStake;
        baseTokenAddress = contractAddresses.BaseToken;
        
        [deployer, user1, user2, user3] = await ethers.getSigners();

    });

    it("正确初始化", async ()=>{
        const baseTokenContract = await ethers.getContractAt("MyToken", baseTokenAddress);
        const balance = await baseTokenContract.balanceOf(user1.address);
        console.log("user1 balance", balance);
        
    })
    
    
  it.only("查看当前区块号码", async () => {
    const currentBlock = await ethers.provider.getBlockNumber();
    console.log("当前区块号码", currentBlock)
  })

    it("区块号应随挖矿增长", async ()=>{
        const initialBlock = await ethers.provider.getBlockNumber();
        console.log("initialBlock", initialBlock)
        // 挖矿 5 个区块
        await ethers.provider.send("hardhat_mine", ["0x5"]);
        
        const finalBlock = await ethers.provider.getBlockNumber();
        expect(finalBlock).to.equal(initialBlock + 5);
    })
})