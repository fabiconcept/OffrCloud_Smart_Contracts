// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title KYC Token Contract
 * @dev ERC20 token with KYC functionality, dividend period, and role-based access control
 */
contract KYCToken is ERC20Capped, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant KYC_ROLE = keccak256("KYC_ROLE");

    uint8 private _decimals;
    uint256 private _rate;
    address payable private _owner;
    address private _beneficiary;
    
    bool private _dividendPeriod;
    
    // KYC tracking
    address[] private _kycUsers;
    mapping(address => bool) private _isKYCed;
    mapping(address => uint256) private _kycUserIndices;
    
    // Token ownership tracking
    mapping(address => bool) private _ownsTokens;
    
    // Events
    event KYCUserAdded(address indexed userAddress);
    event KYCUserRemoved(address indexed userAddress);
    
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 cap_,
        uint256 rate_,
        address beneficiary_
    ) ERC20(name_, symbol_) ERC20Capped(cap_) {
        require(beneficiary_ != address(0), "Invalid beneficiary address");
        
        _decimals = decimals_;
        _rate = rate_;
        _beneficiary = beneficiary_;
        _owner = payable(msg.sender);
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(KYC_ROLE, msg.sender);
        
        // Set role admins
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(KYC_ROLE, DEFAULT_ADMIN_ROLE);
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    function rate() public view returns (uint256) {
        return _rate;
    }
    
    function owner() public view returns (address payable) {
        return _owner;
    }
    
    function getBeneficiary() public view returns (address) {
        return _beneficiary;
    }
    
    receive() external payable {}
    
    modifier onlyOwner() {
        require(msg.sender == _owner, "Only the Owner can call this function");
        _;
    }
    
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid new owner address.");
        _owner = payable(newOwner);
    }
    
    function addMinter(address newMinter) public onlyOwner nonReentrant {
        _grantRole(MINTER_ROLE, newMinter);
    }
    
    function sendTokens(address buyer, uint256 amount) public onlyRole(MINTER_ROLE) nonReentrant {
        require(buyer != address(0), "buyer is a zero address");
        require(amount > 0, "weiAmount is 0");
        
        uint256 tokenAmount = amount * _rate;
        _mint(buyer, tokenAmount);
    }
    
    /**
     * @dev Override transfer function with KYC and dividend period checks
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _validateTransfer(msg.sender, recipient);
        bool success = super.transfer(recipient, amount);
        _updateTokenOwnership(msg.sender, recipient);
        return success;
    }
    
    /**
     * @dev Override transferFrom function with KYC and dividend period checks
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _validateTransfer(sender, recipient);
        bool success = super.transferFrom(sender, recipient, amount);
        _updateTokenOwnership(sender, recipient);
        return success;
    }
    
    /**
     * @dev Internal function to validate transfer conditions
     */
    function _validateTransfer(address sender, address recipient) private view {
        require(!_dividendPeriod, "Dividend Period is ongoing, all transfers will resume after dividend period.");
        require(_isKYCed[sender], "Sender is not KYCed");
        require(_isKYCed[recipient], "Recipient is not KYCed");
    }
    
    /**
     * @dev Internal function to update token ownership status
     */
    function _updateTokenOwnership(address sender, address recipient) private {
        _ownsTokens[recipient] = true;
        _ownsTokens[sender] = balanceOf(sender) > 0;
    }
    
    function burnMyBalance(address _tokenOwner, uint256 _amount) public onlyRole(MINTER_ROLE) returns (bool) {
        require(_tokenOwner != address(0), "ERC20: burn from the zero address");
        
        _burn(_tokenOwner, _amount);
        
        if (balanceOf(_tokenOwner) == 0) {
            _ownsTokens[_tokenOwner] = false;
        }
        
        return true;
    }
    
    function updateDividendPeriodStatus(bool state) public onlyRole(MINTER_ROLE) nonReentrant {
        _dividendPeriod = state;
    }
    
    function getDividendPaymentPeriodState() public view returns (bool) {
        return _dividendPeriod;
    }
    
    function addKYCUser(address user) public onlyRole(KYC_ROLE) nonReentrant {
        require(user != address(0), "Invalid address");
        require(!_isKYCed[user], "User is already KYCed");
        
        _isKYCed[user] = true;
        _kycUsers.push(user);
        _kycUserIndices[user] = _kycUsers.length - 1;
        _ownsTokens[user] = false;
        
        emit KYCUserAdded(user);
    }
    
    function removeKYCUser(address user) public onlyRole(KYC_ROLE) nonReentrant {
        require(_isKYCed[user], "User is not KYCed");
        require(!_ownsTokens[user], "User owns tokens, cannot remove from KYC list");
        
        bool found = false;
        if (_kycUserIndices[user] < _kycUsers.length) {
            found = _kycUsers[_kycUserIndices[user]] == user;
        }
        require(found, "User not found in KYC list");
        
        uint256 lastIndex = _kycUsers.length - 1;
        if (_kycUserIndices[user] != lastIndex) {
            _kycUsers[_kycUserIndices[user]] = _kycUsers[lastIndex];
            _kycUserIndices[_kycUsers[lastIndex]] = _kycUserIndices[user];
        }
        _kycUsers.pop();
        
        _isKYCed[user] = false;
        _kycUserIndices[user] = 0;
        
        emit KYCUserRemoved(user);
    }
    
    function isKYCed(address _stakeHolder) public view returns (bool) {
        return _isKYCed[_stakeHolder];
    }
    
    function getKYCList() public view returns (address[] memory) {
        return _kycUsers;
    }
    
    function kycUsersListLength() public view returns (uint256) {
        return _kycUsers.length;
    }
    
    function getOwnedTokens(address _stakeHolder) public view returns (bool) {
        return _ownsTokens[_stakeHolder];
    }
    
    function updateOwnsToken(address stakeHolder) public onlyRole(MINTER_ROLE) {
        _ownsTokens[stakeHolder] = true;
    }
}