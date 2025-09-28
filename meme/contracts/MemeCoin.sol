// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./TaxHandler.sol";

contract MemeCoin is IERC20 , Ownable{

    //余额
    mapping(address => uint256) private _balances;

    //授权
    mapping(address => mapping(address => uint256)) private _allowances;

    string private _name;
    string private _symbol;
    uint256 private _totalSupply;
    TaxHandler private _taxHandler;
    // 销毁地址
    address private _burnAddress;

    //构造函数
    constructor() Ownable(msg.sender) {
        _name = "MemeCoin";
        _symbol = "SHBC";
        _totalSupply = 1e10 * 1e18;

        _taxHandler = new TaxHandler();
        _burnAddress = address(0);

        _balances[msg.sender] = totalSupply();
        emit Transfer(address(0), msg.sender, totalSupply());
    }

    //代币名称
    function name() public view virtual returns (string memory) {
        return _name;
    }

    //代币符号
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    //小数位数
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    //代币总供应量
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    //查询余额
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    //转账
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    //内部转账
    function _transfer(address from, address to, uint256 value) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= value, "ERC20: transfer amount exceeds balance");
        // 从发送者余额中减去转账金额
        _balances[from] = fromBalance - value;

        // 计算税费
        uint256 tax = _taxHandler.getTax(address(this), from, to, value);
        uint256 taxAmount = value - tax;
        // 向接收者余额中增加转账金额
        _balances[to] += taxAmount;

        //销毁
        _burn(_burnAddress, tax);
        //总供应量
        _totalSupply -= tax;

        emit Transfer(from, to, value);
    }

    //转移到特殊地址
    function _burn(address target, uint256 amount)internal {
        _balances[target] += amount;
    }

    //授权转账额度设置
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    //授权
    function _approve(address owner, address spender, uint256 value) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    //授权额度查询
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    //授权转账
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    //检查授权
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - value);
            }
        }
    }

}