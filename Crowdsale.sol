pragma solidity ^0.4.21;

import './fund/ICrowdsaleFund.sol';
import './fund/ICrowdsaleReservationFund.sol';
import './token/IERC20Token.sol';
import './token/TransferLimitedToken.sol';
import './token/LockedTokens.sol';
import './ownership/Ownable.sol';
import './Pausable.sol';
import './ISimpleCrowdsale.sol';


contract TheAbyssDAICO is Ownable, SafeMath, Pausable, ISimpleCrowdsale {
    enum AdditionalBonusState {
        Unavailable,
        Active,
        Applied
    }

    uint256 public constant ADDITIONAL_BONUS_NUM = 3;
    uint256 public constant ADDITIONAL_BONUS_DENOM = 100;

    uint256 public constant ETHER_MIN_CONTRIB = 0.2 ether;
    uint256 public constant ETHER_MAX_CONTRIB = 20 ether;

    uint256 public constant ETHER_MIN_CONTRIB_PRIVATE = 100 ether;
    uint256 public constant ETHER_MAX_CONTRIB_PRIVATE = 3000 ether;

    uint256 public constant ETHER_MIN_CONTRIB_USA = 0.2 ether;
    uint256 public constant ETHER_MAX_CONTRIB_USA = 20 ether;

    uint256 public constant SALE_START_TIME = 1524060000; // 18.04.2018 14:00:00 UTC
    uint256 public constant SALE_END_TIME = 1526479200; // 16.05.2018 14:00:00 UTC

    uint256 public constant BONUS_WINDOW_1_END_TIME = SALE_START_TIME + 2 days;
    uint256 public constant BONUS_WINDOW_2_END_TIME = SALE_START_TIME + 7 days;
    uint256 public constant BONUS_WINDOW_3_END_TIME = SALE_START_TIME + 14 days;
    uint256 public constant BONUS_WINDOW_4_END_TIME = SALE_START_TIME + 21 days;

    uint256 public constant MAX_CONTRIB_CHECK_END_TIME = SALE_START_TIME + 1 days;

    uint256 public constant BNB_TOKEN_PRICE_NUM = 169;
    uint256 public constant BNB_TOKEN_PRICE_DENOM = 1;

    uint256 public tokenPriceNum = 0;
    uint256 public tokenPriceDenom = 0;
    
    TransferLimitedToken public token;
    ICrowdsaleFund public fund;
    ICrowdsaleReservationFund public reservationFund;
    LockedTokens public lockedTokens;

    mapping(address => bool) public whiteList;
    mapping(address => bool) public privilegedList;
    mapping(address => AdditionalBonusState) public additionalBonusOwnerState;
    mapping(address => uint256) public userTotalContributed;

    address public bnbTokenWallet;
    address public referralTokenWallet;
    address public foundationTokenWallet;
    address public advisorsTokenWallet;
    address public companyTokenWallet;
    address public reserveTokenWallet;
    address public bountyTokenWallet;

    uint256 public totalEtherContributed = 0;
    uint256 public rawTokenSupply = 0;

    // BNB
    IERC20Token public bnbToken;
    uint256 public BNB_HARD_CAP = 300000 ether; // 300K BNB
    uint256 public BNB_MIN_CONTRIB = 1000 ether; // 1K BNB
    mapping(address => uint256) public bnbContributions;
    uint256 public totalBNBContributed = 0;
    bool public bnbWithdrawEnabled = false;

    uint256 public hardCap = 0; // World hard cap will be set right before Token Sale
    uint256 public softCap = 0; // World soft cap will be set right before Token Sale

    bool public bnbRefundEnabled = false;

    event LogContribution(address contributor, uint256 amountWei, uint256 tokenAmount, uint256 tokenBonus, bool additionalBonusApplied, uint256 timestamp);
    event ReservationFundContribution(address contributor, uint256 amountWei, uint256 tokensToIssue, uint256 bonusTokensToIssue, uint256 timestamp);
    event LogBNBContribution(address contributor, uint256 amountBNB, uint256 tokenAmount, uint256 tokenBonus, bool additionalBonusApplied, uint256 timestamp);

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

    modifier checkTime() {
        require(now >= SALE_START_TIME && now <= SALE_END_TIME);
        _;
    }

    function TheAbyssDAICO(
        address bnbTokenAddress,
        address tokenAddress,
        address fundAddress,
        address reservationFundAddress,
        address _bnbTokenWallet,
        address _referralTokenWallet,
        address _foundationTokenWallet,
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
        reservationFund = ICrowdsaleReservationFund(reservationFundAddress);

        bnbTokenWallet = _bnbTokenWallet;
        referralTokenWallet = _referralTokenWallet;
        foundationTokenWallet = _foundationTokenWallet;
        advisorsTokenWallet = _advisorsTokenWallet;
        companyTokenWallet = _companyTokenWallet;
        reserveTokenWallet = _reserveTokenWallet;
        bountyTokenWallet = _bountyTokenWallet;
    }

    /**
     * @dev check if address can contribute
     */
    function isContributorInLists(address contributor) external view returns(bool) {
        return whiteList[contributor] || privilegedList[contributor] || token.limitedWallets(contributor);
    }

    /**
     * @dev check contribution amount and time
     */
    function isValidContribution() internal view returns(bool) {
        uint256 currentUserContribution = safeAdd(msg.value, userTotalContributed[msg.sender]);
        if(whiteList[msg.sender] && msg.value >= ETHER_MIN_CONTRIB) {
            if(now <= MAX_CONTRIB_CHECK_END_TIME && currentUserContribution > ETHER_MAX_CONTRIB ) {
                    return false;
            }
            return true;

        }
        if(privilegedList[msg.sender] && msg.value >= ETHER_MIN_CONTRIB_PRIVATE) {
            if(now <= MAX_CONTRIB_CHECK_END_TIME && currentUserContribution > ETHER_MAX_CONTRIB_PRIVATE ) {
                    return false;
            }
            return true;
        }

        if(token.limitedWallets(msg.sender) && msg.value >= ETHER_MIN_CONTRIB_USA) {
            if(now <= MAX_CONTRIB_CHECK_END_TIME && currentUserContribution > ETHER_MAX_CONTRIB_USA) {
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
        if(msg.value <= safeSub(hardCap, totalEtherContributed)) {
            return true;
        }
        return false;
    }

    /**
     * @dev Set token price once before start of crowdsale
     */
    function setTokenPrice(uint256 _tokenPriceNum, uint256 _tokenPriceDenom) public onlyOwner {
        require(tokenPriceNum == 0 && tokenPriceDenom == 0);
        require(_tokenPriceNum > 0 && _tokenPriceDenom > 0);
        tokenPriceNum = _tokenPriceNum;
        tokenPriceDenom = _tokenPriceDenom;
    }

    /**
     * @dev Set hard cap.
     * @param _hardCap - Hard cap value
     */
    function setHardCap(uint256 _hardCap) public onlyOwner {
        require(hardCap == 0);
        hardCap = _hardCap;
    }

    /**
     * @dev Set soft cap.
     * @param _softCap - Soft cap value
     */
    function setSoftCap(uint256 _softCap) public onlyOwner {
        require(softCap == 0);
        softCap = _softCap;
    }

    /**
     * @dev Get soft cap amount
     **/
    function getSoftCap() external view returns(uint256) {
        return softCap;
    }

    /**
     * @dev Check bnb contribution time, amount and hard cap overflow
     */
    function isValidBNBContribution() internal view returns(bool) {
        if(token.limitedWallets(msg.sender)) {
            return false;
        }
        if(!whiteList[msg.sender] && !privilegedList[msg.sender]) {
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

        if(now < BONUS_WINDOW_1_END_TIME) {
            numerator = 25;
        } else if(now < BONUS_WINDOW_2_END_TIME) {
            numerator = 15;
        } else if(now < BONUS_WINDOW_3_END_TIME) {
            numerator = 10;
        } else if(now < BONUS_WINDOW_4_END_TIME) {
            numerator = 5;
        } else {
            numerator = 0;
        }

        return (numerator, denominator);
    }

    function addToLists(
        address _wallet,
        bool isInWhiteList,
        bool isInPrivilegedList,
        bool isInLimitedList,
        bool hasAdditionalBonus
    ) public onlyOwner {
        if(isInWhiteList) {
            whiteList[_wallet] = true;
        }
        if(isInPrivilegedList) {
            privilegedList[_wallet] = true;
        }
        if(isInLimitedList) {
            token.addLimitedWalletAddress(_wallet);
        }
        if(hasAdditionalBonus) {
            additionalBonusOwnerState[_wallet] = AdditionalBonusState.Active;
        }
        if(reservationFund.canCompleteContribution(_wallet)) {
            reservationFund.completeContribution(_wallet);
        }
    }

    /**
     * @dev Add wallet to whitelist. For contract owner only.
     */
    function addToWhiteList(address _wallet) public onlyOwner {
        whiteList[_wallet] = true;
    }

    /**
     * @dev Add wallet to additional bonus members. For contract owner only.
     */
    function addAdditionalBonusMember(address _wallet) public onlyOwner {
        additionalBonusOwnerState[_wallet] = AdditionalBonusState.Active;
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
    function () payable public whenNotPaused {
        if(whiteList[msg.sender] || privilegedList[msg.sender] || token.limitedWallets(msg.sender)) {
            processContribution(msg.sender, msg.value);
        } else {
            processReservationContribution(msg.sender, msg.value);
        }
    }

    function processReservationContribution(address contributor, uint256 amount) private checkTime checkCap {
        require(amount >= ETHER_MIN_CONTRIB);

        if(now <= MAX_CONTRIB_CHECK_END_TIME) {
            uint256 currentUserContribution = safeAdd(amount, reservationFund.contributionsOf(contributor));
            require(currentUserContribution <= ETHER_MAX_CONTRIB);
        }
        uint256 bonusNum = 0;
        uint256 bonusDenom = 100;
        (bonusNum, bonusDenom) = getBonus();
        uint256 tokenBonusAmount = 0;
        uint256 tokenAmount = safeDiv(safeMul(amount, tokenPriceNum), tokenPriceDenom);

        if(bonusNum > 0) {
            tokenBonusAmount = safeDiv(safeMul(tokenAmount, bonusNum), bonusDenom);
        }

        reservationFund.processContribution.value(amount)(
            contributor,
            tokenAmount,
            tokenBonusAmount
        );
        ReservationFundContribution(contributor, amount, tokenAmount, tokenBonusAmount, now);
    }

    /**
     * @dev Process BNB token contribution
     * Transfer all amount of tokens approved by sender. Calc bonuses and issue tokens to contributor.
     */
    function processBNBContribution() public whenNotPaused checkTime checkBNBContribution {
        bool additionalBonusApplied = false;
        uint256 bonusNum = 0;
        uint256 bonusDenom = 100;
        (bonusNum, bonusDenom) = getBonus();
        uint256 amountBNB = bnbToken.allowance(msg.sender, address(this));
        bnbToken.transferFrom(msg.sender, address(this), amountBNB);
        bnbContributions[msg.sender] = safeAdd(bnbContributions[msg.sender], amountBNB);

        uint256 tokenBonusAmount = 0;
        uint256 tokenAmount = safeDiv(safeMul(amountBNB, BNB_TOKEN_PRICE_NUM), BNB_TOKEN_PRICE_DENOM);
        rawTokenSupply = safeAdd(rawTokenSupply, tokenAmount);
        if(bonusNum > 0) {
            tokenBonusAmount = safeDiv(safeMul(tokenAmount, bonusNum), bonusDenom);
        }

        if(additionalBonusOwnerState[msg.sender] ==  AdditionalBonusState.Active) {
            additionalBonusOwnerState[msg.sender] = AdditionalBonusState.Applied;
            uint256 additionalBonus = safeDiv(safeMul(tokenAmount, ADDITIONAL_BONUS_NUM), ADDITIONAL_BONUS_DENOM);
            tokenBonusAmount = safeAdd(tokenBonusAmount, additionalBonus);
            additionalBonusApplied = true;
        }

        uint256 tokenTotalAmount = safeAdd(tokenAmount, tokenBonusAmount);
        token.issue(msg.sender, tokenTotalAmount);
        totalBNBContributed = safeAdd(totalBNBContributed, amountBNB);

        LogBNBContribution(msg.sender, amountBNB, tokenAmount, tokenBonusAmount, additionalBonusApplied, now);
    }

    /**
     * @dev Process ether contribution. Calc bonuses and issue tokens to contributor.
     */
    function processContribution(address contributor, uint256 amount) private checkTime checkContribution checkCap {
        bool additionalBonusApplied = false;
        uint256 bonusNum = 0;
        uint256 bonusDenom = 100;
        (bonusNum, bonusDenom) = getBonus();
        uint256 tokenBonusAmount = 0;

        uint256 tokenAmount = safeDiv(safeMul(amount, tokenPriceNum), tokenPriceDenom);
        rawTokenSupply = safeAdd(rawTokenSupply, tokenAmount);

        if(bonusNum > 0) {
            tokenBonusAmount = safeDiv(safeMul(tokenAmount, bonusNum), bonusDenom);
        }

        if(additionalBonusOwnerState[contributor] ==  AdditionalBonusState.Active) {
            additionalBonusOwnerState[contributor] = AdditionalBonusState.Applied;
            uint256 additionalBonus = safeDiv(safeMul(tokenAmount, ADDITIONAL_BONUS_NUM), ADDITIONAL_BONUS_DENOM);
            tokenBonusAmount = safeAdd(tokenBonusAmount, additionalBonus);
            additionalBonusApplied = true;
        }

        processPayment(contributor, amount, tokenAmount, tokenBonusAmount, additionalBonusApplied);
    }

    /**
     * @dev Process ether contribution before KYC. Calc bonuses and tokens to issue after KYC.
     */
    function processReservationFundContribution(
        address contributor,
        uint256 tokenAmount,
        uint256 tokenBonusAmount
    ) external payable checkCap {
        require(msg.sender == address(reservationFund));
        require(msg.value > 0);
        rawTokenSupply = safeAdd(rawTokenSupply, tokenAmount);
        processPayment(contributor, msg.value, tokenAmount, tokenBonusAmount, false);
    }

    function processPayment(address contributor, uint256 etherAmount, uint256 tokenAmount, uint256 tokenBonusAmount, bool additionalBonusApplied) internal {
        uint256 tokenTotalAmount = safeAdd(tokenAmount, tokenBonusAmount);

        token.issue(contributor, tokenTotalAmount);
        fund.processContribution.value(etherAmount)(contributor);
        totalEtherContributed = safeAdd(totalEtherContributed, etherAmount);
        userTotalContributed[contributor] = safeAdd(userTotalContributed[contributor], etherAmount);
        LogContribution(contributor, etherAmount, tokenAmount, tokenBonusAmount, additionalBonusApplied, now);
    }

    /**
     * @dev Force crowdsale refund
     */
    function forceCrowdsaleRefund() public onlyOwner {
        pause();
        fund.enableCrowdsaleRefund();
        reservationFund.onCrowdsaleEnd();
        token.finishIssuance();
        bnbRefundEnabled = true;
    }

    /**
     * @dev Finalize crowdsale if we reached hard cap or current time > SALE_END_TIME
     */
    function finalizeCrowdsale() public onlyOwner {
        if(
            totalEtherContributed >= safeSub(hardCap, 1000 ether) ||
            (now >= SALE_END_TIME && totalEtherContributed >= softCap)
        ) {
            fund.onCrowdsaleEnd();
            reservationFund.onCrowdsaleEnd();
            bnbWithdrawEnabled = true;

            // Referral
            uint256 referralTokenAmount = safeDiv(rawTokenSupply, 10);
            token.issue(referralTokenWallet, referralTokenAmount);

            // Foundation
            uint256 foundationTokenAmount = safeDiv(token.totalSupply(), 2); // 20%
            token.issue(address(lockedTokens), foundationTokenAmount);
            lockedTokens.addTokens(foundationTokenWallet, foundationTokenAmount, now + 365 days);
            uint256 suppliedTokenAmount = token.totalSupply();

            // Reserve
            uint256 reservedTokenAmount = safeDiv(safeMul(suppliedTokenAmount, 3), 10); // 18%
            token.issue(address(lockedTokens), reservedTokenAmount);
            lockedTokens.addTokens(reserveTokenWallet, reservedTokenAmount, now + 183 days);

            // Advisors
            uint256 advisorsTokenAmount = safeDiv(suppliedTokenAmount, 10); // 6%
            token.issue(advisorsTokenWallet, advisorsTokenAmount);

            // Company
            uint256 companyTokenAmount = safeDiv(suppliedTokenAmount, 4); // 15%
            token.issue(address(lockedTokens), companyTokenAmount);
            lockedTokens.addTokens(companyTokenWallet, companyTokenAmount, now + 730 days);

            // Bounty
            uint256 bountyTokenAmount = safeDiv(suppliedTokenAmount, 60); // 1%
            token.issue(bountyTokenWallet, bountyTokenAmount);
            token.finishIssuance();
        } else if(now >= SALE_END_TIME) {
            // Enable fund`s crowdsale refund if soft cap is not reached
            fund.enableCrowdsaleRefund();
            reservationFund.onCrowdsaleEnd();
            token.finishIssuance();
            bnbRefundEnabled = true;
        }
    }

    /**
     * @dev Withdraw bnb after crowdsale if crowdsale is not in refund mode
     */
    function withdrawBNB() public onlyOwner {
        require(bnbWithdrawEnabled);
        // BNB transfer
        if(bnbToken.balanceOf(address(this)) > 0) {
            bnbToken.transfer(bnbTokenWallet, bnbToken.balanceOf(address(this)));
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
