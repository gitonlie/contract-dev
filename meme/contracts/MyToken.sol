// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 0xb27A31f1b0AF2946B7F582768f03239b1eC07c2c
contract MyToken is ERC20 {
    event Transfer(address, uint256);

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 9999 ether);
    }

    function transfer(address to, uint256 value) public virtual override returns (bool) {
        super.transfer(to, value);
        emit Transfer(to, value); 
        return true;
    }
}