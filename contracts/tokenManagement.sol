// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./tokenContract.sol";
import "./tokenSaleContract.sol";


contract DividendManagement is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    KYCToken public token;
    TokenSale public tokenSaleContract;
    IUSDC public usdcInstance;
    IUniswapV2Router02 public uniswapRouter;
    address payable public admin;

    struct DividendPeriod {
        uint256 period;
        uint256 interval;
        uint256 percent;
        uint256 startTime;
        uint256 lastDistributionTime;
        uint256 totalDistributed;
        uint256 intervalCount;
        bool isActive;
    }

    struct StakeholderInfo {
        uint256 lastClaimTime;
        uint256 totalClaimed;
        uint256 lastClaimAmount;
    }

    DividendPeriod public currentDividendPeriod;
    mapping(address => StakeholderInfo) public stakeholders;
    uint256 public totalDividendsDistributed;

    event DividendPeriodStarted(uint256 _period, uint256 _interval, uint256 _percent);
    event DividendPeriodEnded(uint256 timestamp);
    event DividendsDistributed(address indexed project_owner, uint256 amountUSDC);
    event DividendsClaimed(address indexed _stakeHolder, uint256 amountClaimed);

    constructor(KYCToken _token, TokenSale _tokenSaleContract) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);

        token = _token;
        tokenSaleContract = _tokenSaleContract;
        admin = payable(msg.sender);
    }

    function setUSDCInstance(IUSDC _usdcInstance) external onlyRole(DEFAULT_ADMIN_ROLE) {
        usdcInstance = _usdcInstance;
    }

    function setUniswapRouter(IUniswapV2Router02 _uniswapRouter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uniswapRouter = _uniswapRouter;
    }

    function startDividendPaymentPeriod(
        uint256 _period,
        uint256 _interval,
        uint256 _percent
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!currentDividendPeriod.isActive, "Dividend period already active");
        require(_percent <= 100, "Percent cannot exceed 100");
        require(_interval > 0, "Interval must be greater than 0");

        currentDividendPeriod = DividendPeriod({
            period: _period,
            interval: _interval,
            percent: _percent,
            startTime: block.timestamp,
            lastDistributionTime: 0,
            totalDistributed: 0,
            intervalCount: 0,
            isActive: true
        });

        token.updateDividendPeriodStatus(true);
        emit DividendPeriodStarted(_period, _interval, _percent);
    }

    function endDividendPaymentPeriod() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(currentDividendPeriod.isActive, "No active dividend period");
        
        currentDividendPeriod.isActive = false;
        token.updateDividendPeriodStatus(false);
        
        emit DividendPeriodEnded(block.timestamp);
    }

    function payDividends() external onlyRole(DISTRIBUTOR_ROLE) nonReentrant {
        require(currentDividendPeriod.isActive, "No active dividend period");
        require(
            block.timestamp >= currentDividendPeriod.lastDistributionTime + currentDividendPeriod.interval,
            "Distribution interval not reached"
        );

        uint256 contractBalance = usdcInstance.balanceOf(address(this));
        require(contractBalance > 0, "No USDC balance to distribute");

        uint256 distributionAmount = (contractBalance * currentDividendPeriod.percent) / 100;
        require(usdcInstance.transfer(admin, distributionAmount), "USDC transfer failed");

        currentDividendPeriod.lastDistributionTime = block.timestamp;
        currentDividendPeriod.totalDistributed += distributionAmount;
        currentDividendPeriod.intervalCount++;

        emit DividendsDistributed(admin, distributionAmount);
    }

    function claimDividend() external nonReentrant whenNotPaused {
        require(currentDividendPeriod.isActive, "No active dividend period");
        require(token.balanceOf(msg.sender) > 0, "No tokens held");
        require(token.isKYCed(msg.sender), "Not KYC verified");

        uint256 claimable = calculateClaimableDividends(msg.sender);
        require(claimable > 0, "No dividends to claim");

        stakeholders[msg.sender].lastClaimTime = block.timestamp;
        stakeholders[msg.sender].totalClaimed += claimable;
        stakeholders[msg.sender].lastClaimAmount = claimable;

        require(usdcInstance.transfer(msg.sender, claimable), "USDC transfer failed");

        emit DividendsClaimed(msg.sender, claimable);
    }

    function calculateClaimableDividends(address _stakeholder) public view returns (uint256) {
        if (!currentDividendPeriod.isActive || token.balanceOf(_stakeholder) == 0) {
            return 0;
        }

        uint256 totalTokens = token.totalSupply();
        uint256 stakeholderShare = (token.balanceOf(_stakeholder) * 1e18) / totalTokens;
        uint256 shareOfDistributions = (currentDividendPeriod.totalDistributed * stakeholderShare) / 1e18;

        if (shareOfDistributions <= stakeholders[_stakeholder].totalClaimed) {
            return 0;
        }

        return shareOfDistributions - stakeholders[_stakeholder].totalClaimed;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // View functions
    function accumulatedDividendsOf(address _stakeholder) external view returns (uint256) {
        return stakeholders[_stakeholder].totalClaimed;
    }

    function claimableDividendsOf(address _stakeholder) external view returns (uint256) {
        return calculateClaimableDividends(_stakeholder);
    }

    function claimedDividendsHistoryOf(address _stakeholder) external view returns (uint256) {
        return stakeholders[_stakeholder].lastClaimAmount;
    }

    function getDividendInterval() external view returns (uint256) {
        return currentDividendPeriod.interval;
    }

    function getDividendIntervalCount() external view returns (uint256) {
        return currentDividendPeriod.intervalCount;
    }

    function getDividendPercent() external view returns (uint256) {
        return currentDividendPeriod.percent;
    }

    function getDividendPeriod() external view returns (uint256) {
        return currentDividendPeriod.period;
    }

    function getLastDividendTime() external view returns (uint256) {
        return currentDividendPeriod.lastDistributionTime;
    }

    function getTotalDividendCount() external view returns (uint256) {
        return totalDividendsDistributed;
    }

    function isDividendPaymentPeriodActive() external view returns (bool) {
        return currentDividendPeriod.isActive;
    }

    function lastClaimDateOf(address _stakeholder) external view returns (uint256) {
        return stakeholders[_stakeholder].lastClaimTime;
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}