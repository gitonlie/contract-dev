// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./TaxHandler.sol";

contract MemeCoin is IERC20 , Ownable{

    // 固定总供应量 - 1万亿代币（带18位小数）
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000_000 * 1e18;

    //余额
    mapping(address => uint256) private _balances;

    //授权
    mapping(address => mapping(address => uint256)) private _allowances;

    // 记录每个地址最近一次转账时间 (按天计算)
    mapping(address => uint256) private lastTransactionDay;
    
    // 记录每个地址每日转账次数
    mapping(address => uint256) public dailyTransactionCount;

    //单笔额度限制100万
    uint256 private limitOnce = 1000000 * 1e18;
    //每日转账次数限制
    uint256 public maxDailyTransactions = 10;

    string private _name;
    string private _symbol;
    uint256 private _totalSupply;
    TaxHandler private _taxHandler;

    //构造函数
    constructor(string memory name_, string memory symbol_) Ownable(msg.sender) {
        _name = name_;
        _symbol = symbol_;
        _totalSupply = TOTAL_SUPPLY;
        _taxHandler = new TaxHandler();

        _balances[msg.sender] = totalSupply();
        emit Transfer(address(0), msg.sender, totalSupply());
    }

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    modifier checkLimit(uint256 value) {
        //检查转账额度是否超过单笔额度限制
        require(value <= limitOnce, "Transfer amount exceeds limit");
        //检查并更新每日交易计数
        _checkAndUpdateDailyCount(_msgSender());
        _;
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
    function _transfer(address from, address to, uint256 value) internal virtual checkLimit(value) {

        if (from == owner() && to != address(0) || from != address(0) && to == owner()) {
            //由部署转账或者转账给部署者不收代币税
            _balances[from] -= value;
            _balances[to] += value;
            emit Transfer(from, to, value);
            return;
        }


        if(from == address(0)){
            _totalSupply += value;
        }else{
            uint256 fromBalance = _balances[from];
            require(fromBalance >= value, "ERC20: transfer amount exceeds balance");
            // 从发送者余额中减去转账金额
            _balances[from] = fromBalance - value;
        }

        if(to == address(0)){
            _totalSupply -= value;
        }else{
            // 计算税费
            uint256 tax = _taxHandler.getTax(from, to, value);
            uint256 taxAmount = value - tax;
            // 向接收者余额中增加转账金额
            _balances[to] += taxAmount;

            //转移代币税到特殊地址
            _balances[address(0)] += tax;
            //销毁代币
            _totalSupply -= tax;
        }
        emit Transfer(from, to, value);
    }

    //销毁代币(针对此合约实际是将当前账户余额释放给合约部署者)
    function _burn(address from, uint256 amount)public virtual {
        _transfer(from, owner(), amount);
        emit Burn(from, amount);
    }

    //铸造代币(针对此合约实际是拥有者将余额转移给当前账户)
    function _mint(address to, uint256 amount)public virtual {
        _transfer(owner(), to, amount);
        emit Mint(to, amount);
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

        /**
     * @dev 检查并更新每日交易计数
     */
    function _checkAndUpdateDailyCount(address _address) private {
        // 获取当前日期 (按天计算)
        uint256 currentDay = block.timestamp / 1 days;
        
        // 如果是新的一天，重置计数
        if (lastTransactionDay[_address] != currentDay) {
            dailyTransactionCount[_address] = 0;
            lastTransactionDay[_address] = currentDay;
        }
        
        // 检查是否超过每日交易次数限制
        require(
            dailyTransactionCount[_address] < maxDailyTransactions,
            "Daily transaction limit exceeded"
        );
        
        // 增加交易计数
        dailyTransactionCount[_address]++;
    }

}