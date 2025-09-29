// SPDX-License-Identifier: MIT 
pragma solidity ^0.8;

import "./MemeCoin.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "hardhat/console.sol";

/**
 * @title LiquidityPool
 * @dev 流动性池合约
 */
contract LiquidityPool is MemeCoin, ReentrancyGuard {
    // 代币1地址
    address public immutable token1;
    // 代币2地址
    address public immutable token2;
    // 流动性池代币总供应量
    uint256 private _totalSupplyLiquidity;

    // 记录流动性添加
    event LiquidityAdd(address provider,uint256 token1Amount,uint256 token2Amount,uint256 lpToken);

    // 记录流动性移除
    event LiquidityRemove(address provider,uint256 token1Amount,uint256 token2Amount,uint256 lpToken);

    // 构造函数
    constructor(address _token1, address _token2) MemeCoin("Liquidity Token", "LP") {
        require(_token1 != address(0) && _token2 != address(0), "Invalid token address");
        require(_token1 != _token2, "Tokens must be different");
        token1 = _token1;
        token2 = _token2;
    }

    // 查询流动性池中的代币余额
    function getReserves() public view returns (uint256 reserve1, uint256 reserve2) {
        reserve1 = IERC20(token1).balanceOf(address(this));
        reserve2 = IERC20(token2).balanceOf(address(this));
    }

    /**
     * @dev 添加流动性
     * @param token1Amount 代币1的数量
     * @param token2Amount 代币2的数量
     * @param minToken1Amount 最小接受的代币1数量
     * @param minToken2Amount 最小接受的代币2数量
     * @return _token1Amount 实际接收的代币1数量
     * @return _token2Amount 实际接收的代币2数量
     * @return liquidity 铸造的流动性代币数量
     */
    function addLiquidity(
        uint256 token1Amount, 
        uint256 token2Amount, 
        uint256 minToken1Amount, 
        uint256 minToken2Amount ) external nonReentrant returns (uint256 _token1Amount, uint256 _token2Amount, uint256 liquidity) {

        //获取当前流动性池中的代币余额
        (uint256 reserve1, uint256 reserve2) = getReserves();

        // 如果储备金为0，说明是首次添加流动性，直接返回添加的流动性数量
        if(reserve1 == 0 && reserve2 == 0){
            (_token1Amount, _token2Amount) = (token1Amount, token2Amount);
        } else {
           // 计算与 token1Amount 匹配的最优 token2 数量
           uint256 matchToken2Amount = quote(token1Amount, reserve1, reserve2);
           if (matchToken2Amount <= token2Amount) {
               require(matchToken2Amount >= minToken2Amount, "Token2 amount too low");
               (_token1Amount, _token2Amount) = (token1Amount, matchToken2Amount);
           } else {
                // 用户提供的 token2 不足，反推所需的 token1 数量
               uint256 matchToken1Amount = quote(token2Amount, reserve2, reserve1);
               assert(matchToken1Amount <= token1Amount);
               require(matchToken1Amount >= minToken1Amount, "Token1 amount too low");
               (_token1Amount, _token2Amount) = (matchToken1Amount, token2Amount);
           } 
        }

        //转账token1
        IERC20(token1).transferFrom(msg.sender, address(this), _token1Amount);

        //转账token2
        IERC20(token2).transferFrom(msg.sender, address(this), _token2Amount);

        // 计算流动性代币数量
        if (_totalSupplyLiquidity == 0) {
            liquidity = sqrt(_token1Amount * _token2Amount);
        } else {
            liquidity = min(
                (_token1Amount * _totalSupplyLiquidity) / reserve1,
                (_token2Amount * _totalSupplyLiquidity) / reserve2
            );
        }

        require(liquidity > 0, "Insufficient liquidity minted");

        _totalSupplyLiquidity += liquidity;
        // 铸造流动性代币
        _mint(msg.sender, liquidity);

        emit LiquidityAdd(msg.sender, _token1Amount, _token2Amount, liquidity);
    }

    /**
     * @dev 移除流动性
     * @param liquidity 要移除的流动性代币数量
     * @param minToken1Amount 最小接受的代币1数量
     * @param minToken2Amount 最小接受的代币2数量
     * @return token1Amount 实际移除的代币1数量
     * @return token2Amount 实际移除的代币2数量
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 minToken1Amount,
        uint256 minToken2Amount) external nonReentrant returns (uint256 token1Amount, uint256 token2Amount) {
        
        require(liquidity > 0, "Insufficient liquidity");
        // 检查流动性是否足够
        require(liquidity <= balanceOf(msg.sender), "Insufficient liquidity");

        // 计算移除的代币数量
        (uint256 reserve1, uint256 reserve2) = getReserves();
        token1Amount = (liquidity * reserve1) / _totalSupplyLiquidity;
        token2Amount = (liquidity * reserve2) / _totalSupplyLiquidity;

        console.log("token1Amount:", token1Amount);
        console.log("token2Amount:", token2Amount);

        // 检查移除的代币数量是否足够
        require(token1Amount >= minToken1Amount && token2Amount >= minToken2Amount, "Insufficient output amount");

        // 更新流动性池中的代币余额
        _totalSupplyLiquidity -= liquidity;
        // 销毁流动性代币
        _burn(msg.sender, liquidity);

        // 转账代币1
        IERC20(token1).transfer(msg.sender, token1Amount);

        // 转账代币2
        IERC20(token2).transfer(msg.sender, token2Amount);

        emit LiquidityRemove(msg.sender, token1Amount, token2Amount, liquidity);
    }

    /**
     * @dev 计算两种代币的兑换比例
     * @param amountA 代币A的数量
     * @param reserveA 代币A的储备量
     * @param reserveB 代币B的储备量
     * @return amountB 与amountA等值的代币B数量
     */
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB) {
        require(amountA > 0, "Invalid amount");
        require(reserveA > 0 && reserveB > 0, "Insufficient reserves");
        amountB = (amountA * reserveB) / reserveA;
    }

   /**
     * @dev 计算平方根（用于首次添加流动性时计算LP代币数量）
     */
    function sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
    
   /**
     * @dev 返回两个数中的较小值
     */
    function min(uint256 x, uint256 y) private pure returns (uint256) {
        return x < y ? x : y;
    }

    /**
     * @dev 返回流动性池中的流动性代币总供应量
     */
    function  getTotalSupplyLiquidity() public view returns (uint256) {
        return _totalSupplyLiquidity;
    }

}