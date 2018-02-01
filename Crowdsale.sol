pragma solidity ^0.4.18;

import './fund/ICrowdsaleFund.sol';
import './token/IERC20Token.sol';
import './token/TransferLimitedToken.sol';
import './token/LockedTokens.sol';
import './ownership/Ownable.sol';
import './Pausable.sol';


contract TheAbyssDAICO is Ownable, SafeMath, Pausable {
    uint256 public constant TOKEN_PRICE_NUM = 5000;
    uint256 public constant TOKEN_PRICE_DENOM = 1;

    uint256 public constant ETHER_MIN_CONTRIB = 0.1 ether;
    uint256 public constant ETHER_MAX_CONTRIB = 10 ether;

    uint256 public constant ETHER_MIN_CONTRIB_PRIVATE = 100 ether;
    uint256 public constant ETHER_MAX_CONTRIB_PRIVATE = 3000 ether;

    uint256 public constant ETHER_MIN_CONTRIB_USA = 1 ether;
    uint256 public constant ETHER_MAX_CONTRIB_USA = 100 ether;

    uint256 public constant SOFT_CAP = 5000 ether;
    uint256 public constant HARD_CAP = 30000 ether; // World
    uint256 public constant USA_HARD_CAP = 20000 ether; // USA

    uint256 public constant SALE_START_TIME = 1517961600; // 07.02.2018
    uint256 public constant SALE_END_TIME = 1522540800; // 01.04.2018
    uint256 public constant HARD_CAP_MERGE_TIME = 1519862400; // 01.03.2018

    TransferLimitedToken public token;
    ICrowdsaleFund public fund;
    LockedTokens public lockedTokens;

    mapping(address => bool) public whiteList;
    mapping(address => bool) public privilegedList;
    mapping(address => bool) public telegramMembers;
    mapping(address => bool) public telegramMemberHadPayment;

    address public bnbTokenWallet;
    address public referralTokenWallet;
    address public advisorsTokenWallet;
    address public companyTokenWallet;
    address public reserveTokenWallet;
    address public bountyTokenWallet;

    uint256 public totalWorldEtherContributed = 0;
    uint256 public totalUSAEtherContributed = 0;

    uint256 public bonusWindow1EndTime = 0;
    uint256 public bonusWindow2EndTime = 0;
    uint256 public bonusWindow3EndTime = 0;
    uint256 public bonusWindow4EndTime = 0;

    // BNB
    IERC20Token public bnbToken;
    uint256 public BNB_HARD_CAP = 300000*10**18; // 300K BNB
    uint256 public BNB_MIN_CONTRIB = 1000*10**18; // 1K BNB
    mapping(address => uint256) public bnbContributions;
    uint256 public totalBNBContributed = 0;
    uint256 public constant BNB_TOKEN_PRICE_NUM = 50; // Price will be set right before Token Sale
    uint256 public constant BNB_TOKEN_PRICE_DENOM = 1;
    bool public bnbRefundEnabled = false;

    event LogContribution(address contributor, uint256 amountWei, uint256 tokenAmount, uint256 tokenBonus, uint256 timestamp);
    event LogBNBContribution(address contributor, uint256 amountBNB, uint256 tokenAmount, uint256 tokenBonus, uint256 timestamp);

    modifier checkContribution() {
        require(isValidContribution());
        _;
    }

    modifier checkBNBContribution() {
        require(isValidBNBContribution());
        _;
    }

    modifier checkCap() {
        require(validateCap());
        _;
    }

    function TheAbyssDAICO(
        address bnbTokenAddress,
        address tokenAddress,
        address fundAddress,
        address _bnbTokenWallet,
        address _referralTokenWallet,
        address _advisorsTokenWallet,
        address _companyTokenWallet,
        address _reserveTokenWallet,
        address _bountyTokenWallet,
        address _owner
    ) public
        Ownable(_owner)
    {
        require(tokenAddress != address(0));

        bnbToken = IERC20Token(bnbTokenAddress);
        token = TransferLimitedToken(tokenAddress);
        fund = ICrowdsaleFund(fundAddress);

        bnbTokenWallet = _bnbTokenWallet;
        referralTokenWallet = _referralTokenWallet;
        advisorsTokenWallet = _advisorsTokenWallet;
        companyTokenWallet = _companyTokenWallet;
        reserveTokenWallet = _reserveTokenWallet;
        bountyTokenWallet = _bountyTokenWallet;

        bonusWindow1EndTime = SALE_START_TIME + 1 days;
        bonusWindow2EndTime = SALE_START_TIME + 7 days;
        bonusWindow3EndTime = SALE_START_TIME + 22 days;
        bonusWindow4EndTime = SALE_START_TIME + 40 days;
    }

    /**
     * @dev check contribution amount and time
     */
    function isValidContribution() internal view returns(bool) {
        if(now < SALE_START_TIME || now > SALE_END_TIME) {
            return false;

        }
        if(whiteList[msg.sender] && msg.value >= ETHER_MIN_CONTRIB) {
            if(now <= SALE_START_TIME + 7 days && msg.value > ETHER_MAX_CONTRIB ) {
                    return false;
            }
            return true;

        }
        if(privilegedList[msg.sender] && msg.value >= ETHER_MIN_CONTRIB_PRIVATE) {
            if(now <= SALE_START_TIME + 7 days && msg.value > ETHER_MAX_CONTRIB_PRIVATE ) {
                    return false;
            }
            return true;
        }
        if(token.limitedWallets(msg.sender) && msg.value >= ETHER_MIN_CONTRIB_USA) {
            if(now <= SALE_START_TIME + 7 days && msg.value > ETHER_MAX_CONTRIB_USA) {
                    return false;
            }
            return true;
        }

        return false;
    }

    /**
     * @dev Check hard cap overflow
     */
    function validateCap() internal view returns(bool){
        if(now <= HARD_CAP_MERGE_TIME) {
            if(token.limitedWallets(msg.sender)) {
                if(safeAdd(totalUSAEtherContributed, msg.value) <= USA_HARD_CAP) {
                    return true;
                }
                return false;
            }
            if(safeAdd(totalWorldEtherContributed, msg.value) <= HARD_CAP) {
                return true;
            }
            return false;
        }

        uint256 totalHardCap = safeAdd(USA_HARD_CAP, HARD_CAP);
        uint256 totalEtherContributed = safeAdd(totalWorldEtherContributed, totalUSAEtherContributed);
        if(msg.value <= safeSub(totalHardCap, totalEtherContributed)) {
            return true;
        }
        return false;
    }

    /**
     * @dev Check bnb contribution time, amount and hard cap overflow
     */
    function isValidBNBContribution() internal view returns(bool) {
        if(now < SALE_START_TIME || now > SALE_END_TIME) {
            return false;
        }
        if(!whiteList[msg.sender] && !privilegedList[msg.sender] && !token.limitedWallets(msg.sender)) {
            return false;
        }
        uint256 amount = bnbToken.allowance(msg.sender, address(this));
        if(amount < BNB_MIN_CONTRIB || safeAdd(totalBNBContributed, amount) > BNB_HARD_CAP) {
            return false;
        }
        return true;

    }

    /**
     * @dev Calc bonus amount by contribution time
     */
    function getBonus() internal constant returns (uint256, uint256) {
        uint256 numerator = 0;
        uint256 denominator = 100;

        if(now < bonusWindow1EndTime) {
            numerator = 25;
        } else if(now < bonusWindow2EndTime) {
            numerator = 15;
        } else if(now < bonusWindow3EndTime) {
            numerator = 10;
        } else if(now < bonusWindow4EndTime) {
            numerator = 5;
        } else {
            numerator = 0;
        }

        return (numerator, denominator);
    }

    /**
     * @dev Add wallet to whitelist. For contract owner only.
     */
    function addToWhiteList(address _wallet) public onlyOwner {
        whiteList[_wallet] = true;
    }

    /**
     * @dev Add wallet to telegram members. For contract owner only.
     */
    function addTelegramMember(address _wallet) public onlyOwner {
        telegramMembers[_wallet] = true;
    }

    /**
     * @dev Add wallet to privileged list. For contract owner only.
     */
    function addToPrivilegedList(address _wallet) public onlyOwner {
        privilegedList[_wallet] = true;
    }

    /**
     * @dev Set LockedTokens contract address
     */
    function setLockedTokens(address lockedTokensAddress) public onlyOwner {
        lockedTokens = LockedTokens(lockedTokensAddress);
    }

    /**
     * @dev Fallback function to receive ether contributions
     */
    function () payable public {
        processContribution();
    }

    /**
     * @dev Process BNB token contribution
     * Transfer all amount of tokens approved by sender. Calc bonuses and issue tokens to contributor.
     */
    function processBNBContribution() public whenNotPaused checkBNBContribution {
        uint256 bonusNum = 0;
        uint256 bonusDenom = 100;
        (bonusNum, bonusDenom) = getBonus();
        uint256 amountBNB = bnbToken.allowance(msg.sender, address(this));
        bnbToken.transferFrom(msg.sender, address(this), amountBNB);
        bnbContributions[msg.sender] = safeAdd(bnbContributions[msg.sender], amountBNB);

        uint256 tokenBonusAmount = 0;
        uint256 tokenAmount = safeDiv(safeMul(amountBNB, BNB_TOKEN_PRICE_NUM), BNB_TOKEN_PRICE_DENOM);
        if(bonusNum > 0) {
            tokenBonusAmount = safeDiv(safeMul(tokenAmount, bonusNum), bonusDenom);
        }

        if(telegramMembers[msg.sender] && !telegramMemberHadPayment[msg.sender]) {
            telegramMemberHadPayment[msg.sender] = true;
            uint256 telegramBonus = safeDiv(safeMul(tokenAmount, 3), 100);
            tokenBonusAmount = safeAdd(tokenBonusAmount, telegramBonus);
        }

        uint256 tokenTotalAmount = safeAdd(tokenAmount, tokenBonusAmount);
        token.issue(msg.sender, tokenTotalAmount);
        totalBNBContributed = safeAdd(totalBNBContributed, amountBNB);

        LogBNBContribution(msg.sender, amountBNB, tokenAmount, tokenBonusAmount, now);
    }

    /**
     * @dev Process ether contribution. Calc bonuses and issue tokens to contributor.
     */
    function processContribution() private whenNotPaused checkContribution checkCap {
        uint256 bonusNum = 0;
        uint256 bonusDenom = 100;
        (bonusNum, bonusDenom) = getBonus();
        uint256 tokenBonusAmount = 0;
        uint256 tokenAmount = safeDiv(safeMul(msg.value, TOKEN_PRICE_NUM), TOKEN_PRICE_DENOM);

        if(bonusNum > 0) {
            tokenBonusAmount = safeDiv(safeMul(tokenAmount, bonusNum), bonusDenom);
        }

        if(telegramMembers[msg.sender] && !telegramMemberHadPayment[msg.sender]) {
            telegramMemberHadPayment[msg.sender] = true;
            uint256 telegramBonus = safeDiv(safeMul(tokenAmount, 3), 100);
            tokenBonusAmount = safeAdd(tokenBonusAmount, telegramBonus);
        }

        uint256 tokenTotalAmount = safeAdd(tokenAmount, tokenBonusAmount);

        token.issue(msg.sender, tokenTotalAmount);
        fund.processContribution.value(msg.value)(msg.sender);

        if(token.limitedWallets(msg.sender)) {
            totalUSAEtherContributed = safeAdd(totalUSAEtherContributed, msg.value);
        } else {
            totalWorldEtherContributed = safeAdd(totalWorldEtherContributed, msg.value);
        }

        LogContribution(msg.sender, msg.value, tokenAmount, tokenBonusAmount, now);
    }

    /**
     * @dev Finalize crowdsale if we reached all hard caps or current time > SALE_END_TIME
     */
    function finalizeCrowdsale() public onlyOwner {
        uint256 totalHardCap = safeAdd(USA_HARD_CAP, HARD_CAP);
        uint256 totalEtherContributed = safeAdd(totalWorldEtherContributed, totalUSAEtherContributed);
        if(
            (totalEtherContributed >= safeSub(totalHardCap, ETHER_MIN_CONTRIB_USA) && totalBNBContributed >= safeSub(BNB_HARD_CAP, BNB_MIN_CONTRIB)) ||
            (now >= SALE_END_TIME && totalEtherContributed >= SOFT_CAP)
        ) {
            fund.onCrowdsaleEnd();
            // BNB transfer
            bnbToken.transfer(bnbTokenWallet, bnbToken.balanceOf(address(this)));

            // Referral
            uint256 referralTokenAmount = safeDiv(token.totalSupply(), 10);
            token.issue(referralTokenWallet, referralTokenAmount);

            uint256 suppliedTokenAmount = token.totalSupply();

            // Reserve
            uint256 reservedTokenAmount = safeDiv(safeMul(suppliedTokenAmount, 3), 10); // 18%
            token.issue(address(lockedTokens), reservedTokenAmount);
            lockedTokens.addTokens(reserveTokenWallet, reservedTokenAmount,  now + 183 days);

            // Advisors
            uint256 advisorsTokenAmount = safeDiv(suppliedTokenAmount, 10); // 6%
            token.issue(advisorsTokenWallet, advisorsTokenAmount);

            // Company
            uint256 companyTokenAmount = safeDiv(suppliedTokenAmount, 4); // 15%
            token.issue(address(lockedTokens), companyTokenAmount);
            lockedTokens.addTokens(companyTokenWallet, safeDiv(companyTokenAmount, 2),  now + 183 days);
            lockedTokens.addTokens(companyTokenWallet, safeDiv(companyTokenAmount, 2),  now + 365 days);

            // Bounty
            uint256 bountyTokenAmount = safeDiv(suppliedTokenAmount, 60); // 1%
            token.issue(bountyTokenWallet, bountyTokenAmount);

            token.setAllowTransfers(true);

        } else if(now >= SALE_END_TIME) {
            // Enable fund`s crowdsale refund if soft cap is not reached
            fund.enableCrowdsaleRefund();
            bnbRefundEnabled = true;
        }
    }

    /**
     * @dev Function is called by contributor to refund BNB token payments if crowdsale failed to reach soft cap
     */
    function refundBNBContributor() public {
        require(bnbRefundEnabled);
        require(bnbContributions[msg.sender] > 0);
        uint256 amount = bnbContributions[msg.sender];
        bnbContributions[msg.sender] = 0;
        bnbToken.transfer(msg.sender, amount);
        token.destroy(msg.sender, token.balanceOf(msg.sender));
    }
}
