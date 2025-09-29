const { ethers } = require('hardhat');

describe("MemeCoin",async function () {

    it("Should deploy the contract", async function () {
        const [owner, addr1, addr2] = await ethers.getSigners();
        
        console.log("owner.address:", owner.address);
        console.log("addr1.address:", addr1.address);
        console.log("addr2.address:", addr2.address);

        //ERC20 代币合约部署
        const MyToken = await ethers.getContractFactory("MyToken");

        const token1 = await MyToken.deploy("BP_TOKEN", "BPSD");
        await token1.waitForDeployment();
        const token1Address = await token1.getAddress();
        console.log("MyToken1 deployed to:", token1Address);

        const token1Balance = await token1.balanceOf(owner.address);
        console.log("token1Balance:", token1Balance);


        const token2 = await MyToken.deploy("RCP_TOKEN", "RUSD");
        await token2.waitForDeployment();
        const token2Address = await token2.getAddress();
        console.log("MyToken2 deployed to:", token2Address);

        const token2Balance = await token2.balanceOf(owner.address);
        console.log("token2Balance:", token2Balance);

        //部署流动性池合约 使用账户 addr1
        const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
        const liquidityPool = await LiquidityPool.connect(addr1).deploy(token1Address, token2Address);
        await liquidityPool.waitForDeployment();
        const liquidityPoolAddress = await liquidityPool.getAddress();
        console.log("LiquidityPool deployed to:", liquidityPoolAddress);

        //授权流动性池合约操作代币1和代币2
        await token1.connect(owner).approve(liquidityPoolAddress, 10000000);
        await token2.connect(owner).approve(liquidityPoolAddress, 20000000);

        //添加流动性
        await liquidityPool.connect(owner).addLiquidity(10000000, 20000000, 99999, 99999);

        //查询流动性池中的代币余额
        const reserves = await liquidityPool.getReserves();
        console.log("reserves:", reserves);

        //查询流动性池中的流动性代币总供应量
        const totalSupplyLiquidity = await liquidityPool.getTotalSupplyLiquidity();
        console.log("totalSupplyLiquidity:", totalSupplyLiquidity);

        //查询流动性池中的流动性代币余额
        const token1LiquidityPoolBalanceBefore = await token1.balanceOf(liquidityPoolAddress);
        console.log("token1LiquidityPoolBalanceBefore:", token1LiquidityPoolBalanceBefore);
        const token2LiquidityPoolBalanceBefore = await token2.balanceOf(liquidityPoolAddress);
        console.log("token2LiquidityPoolBalanceBefore:", token2LiquidityPoolBalanceBefore);

        //移除流动性
        await liquidityPool.connect(owner).removeLiquidity(2135, 1200, 1200);

        //查询流动性池中的流动性代币余额
        const token1LiquidityPoolBalanceAfter = await token1.balanceOf(liquidityPoolAddress);
        console.log("token1LiquidityPoolBalanceAfter:", token1LiquidityPoolBalanceAfter);
        const token2LiquidityPoolBalanceAfter = await token2.balanceOf(liquidityPoolAddress);
        console.log("token2LiquidityPoolBalanceAfter:", token2LiquidityPoolBalanceAfter);
    });
});