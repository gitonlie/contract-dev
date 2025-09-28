// SPDX-License-Identifier: MIT 
pragma solidity ^0.8;

import "./ITaxHandler.sol";

contract TaxHandler is ITaxHandler {

    // 通缩率：交易金额的1%会被销毁
    uint256 public constant BURN_RATE = 100;

    // 交易税费事件
    event TaxPaid(address indexed from, address indexed to, uint256 amount, uint256 tax);

    // 计算交易应缴纳的税费
    function getTax(address from, address to,uint256 amount) public returns (uint256) {
        // 计算税费
        uint256 tax = (amount * BURN_RATE) / 10000;

        emit TaxPaid(from, to, amount, tax);
        return tax;
    }

}
