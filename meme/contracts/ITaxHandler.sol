// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

/**
 * @title Tax handler interface
 * @dev Any class that implements this interface can be used for protocol-specific tax calculations.
 */
 
interface ITaxHandler {
    /**
     * @notice 计算交易应缴纳的税费
     * @param token 代币合约地址
     * @param from 发送者地址
     * @param to 接收者地址
     * @param amount 交易金额
     * @return 计算后的税费金额
     */
    function getTax(
        address token,
        address from,
        address to,
        uint256 amount
    ) external returns (uint256);

}