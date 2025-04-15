// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./tokenContract.sol"; // Importing your KYCToken contract

interface IUSDC is IERC20 {
    // USDC specific functions if any
}

contract TokenSale is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    KYCToken public token;
    IUSDC public usdcInstance;
    IUniswapV2Router02 public uniswapRouter;
    
    address payable public admin;
    string public tokenBatchName;
    uint256 public tokenSold;
    uint256 public startTimestamp;
    uint256 public endTimestamp;
    bool public fundingReleased;
    bool public isDividendPaymentPeriodActive;
    bool public tokensaleOpen;
    uint256 public tokenPrice; // Price in USDC (e.g., 1e6 = 1 USDC per token)
    
    event FundsReleased(address indexed beneficiary, uint256 amountUSDC);
    event TokenSaleEnded(string indexed batchName, uint256 tokenSold);
    event TokenSaleStarted(uint256 indexed startDate, uint256 endDate);
    event TokensPurchased(
        address indexed transmitter,
        address indexed buyer,
        uint256 amountUSDC,
        uint256 amountToken
    );

    constructor(KYCToken _token, IUSDC _usdc, uint256 _tokenPrice) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        
        token = _token;
        usdcInstance = _usdc;
        tokenPrice = _tokenPrice;
        admin = payable(msg.sender);
        tokensaleOpen = false;
        fundingReleased = false;
        isDividendPaymentPeriodActive = false;
    }

    function setUniswapRouter(IUniswapV2Router02 _uniswapRouter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uniswapRouter = _uniswapRouter;
    }

    function setTokenPrice(uint256 newPrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenPrice = newPrice;
    }

    function startSale(
        uint256 start,
        uint256 end,
        string memory _batchName
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(start < end, "Start time must be before end time");
        require(!tokensaleOpen, "Sale is already open");
        
        startTimestamp = start;
        endTimestamp = end;
        tokenBatchName = _batchName;
        tokensaleOpen = true;
        
        emit TokenSaleStarted(start, end);
    }

    function buyTokens(uint256 usdcAmount) external payable whenNotPaused nonReentrant {
        require(tokensaleOpen, "Token sale is not open");
        require(block.timestamp >= startTimestamp && block.timestamp <= endTimestamp, "Sale is not active");
        require(usdcAmount > 0, "USDC amount must be greater than 0");
        require(token.isKYCed(msg.sender), "Buyer is not KYC verified");
        
        uint256 tokenAmount = (usdcAmount * (10 ** token.decimals())) / tokenPrice;
        require(tokenAmount > 0, "Token amount must be greater than 0");
        
        // Transfer USDC from buyer to this contract
        require(usdcInstance.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");
        
        // Ensure the buyer is KYCed before transferring tokens
        if (!token.isKYCed(msg.sender)) {
            revert("Buyer not KYC verified");
        }
        
        // Transfer tokens to buyer
        token.sendTokens(msg.sender, tokenAmount);
        
        tokenSold += tokenAmount;
        
        emit TokensPurchased(msg.sender, msg.sender, usdcAmount, tokenAmount);
    }

    function endSale() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tokensaleOpen, "Sale is not open");
        tokensaleOpen = false;
        emit TokenSaleEnded(tokenBatchName, tokenSold);
    }

    function releaseFunds() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(!fundingReleased, "Funds already released");
        require(!tokensaleOpen, "Sale must be ended first");
        
        uint256 balance = usdcInstance.balanceOf(address(this));
        require(balance > 0, "No funds to release");
        
        fundingReleased = true;
        require(usdcInstance.transfer(admin, balance), "Transfer failed");
        
        emit FundsReleased(admin, balance);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function updateDividendPeriodStatus(bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isDividendPaymentPeriodActive = status;
        token.updateDividendPeriodStatus(status);
    }

    // View functions
    function getAdmin() external view returns (address) {
        return admin;
    }

    function getName() external view returns (string memory) {
        return tokenBatchName;
    }

    function getSaleEndDate() external view returns (uint256) {
        return endTimestamp;
    }

    function getTokenBatchName() external view returns (string memory) {
        return tokenBatchName;
    }

    function getTokenSold() external view returns (uint256) {
        return tokenSold;
    }

    function getTokenPrice() external view returns (uint256) {
        return tokenPrice;
    }

    function getAvailableTokens() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    // Required override for AccessControl
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}