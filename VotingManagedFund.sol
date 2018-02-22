pragma solidity ^0.4.18;

import './Fund.sol';
import './TapVoting.sol';
import './BufferVoting.sol';
import './OracleVoting.sol';
import './RefundVoting.sol';
import './fund/IVotingManagedFund.sol';
import './token/ITokenEventListener.sol';

/**
 * @title VotingManagedFund
 * @dev Fund controlled by users and oracles voting
 */
contract VotingManagedFund is Fund, IVotingManagedFund, ITokenEventListener {
    uint256 public constant MAX_TAP_INC_PERC = 50;
    uint256 public constant VOTING_START_LATENCY = 4 days;
    uint256 public constant VOTING_DURATION = 3 days;

    uint256 public minVotedTokensPerc = 0;
    uint256 public constant MAX_VOTED_TOKEN_PERC = 10;

    TapVoting public tapVoting;
    uint256 public lastTapVotingTime;
    BufferVoting public bufferVoting;
    uint256 public lastBufferVotingTime;
    OracleVoting public oracleVoting;
    uint256 public lastOracleVotingTime;
    RefundVoting public refundVoting;

    address[] public oraclesAddresses;
    mapping(address => bool) oracles;
    uint8 public minOraclesVoted;

    bool public refundVotingEnabled = false;

    modifier onlyOracle() {
        require(oracles[msg.sender] == true);
        _;
    }

    /**
     * @dev VotingManagedFund constructor
     * params - see Fund constructor
     */
    function VotingManagedFund(
        address _teamWallet,
        address _referralTokenWallet,
        address _companyTokenWallet,
        address _reserveTokenWallet,
        address _bountyTokenWallet,
        address _advisorTokenWallet,
        address[] _owners
        ) public
    Fund(_teamWallet, _referralTokenWallet, _companyTokenWallet, _reserveTokenWallet, _bountyTokenWallet, _advisorTokenWallet, _owners)
    {

    }

    /**
     * @dev Sets oracles only once by owner
     */
    function setOracles(address[] _oraclesAddresses, uint8 _minOraclesVoted) public onlyOwner {
        require(oraclesAddresses.length == 0);
        oraclesAddresses = _oraclesAddresses;
        for(uint256 i = 0; i < oraclesAddresses.length; i++) {
                oracles[oraclesAddresses[i]] = true;
        }
        minOraclesVoted = _minOraclesVoted;
    }

    /**
     * @dev ITokenEventListener implementation. Notify active voting contracts about token transfers
     */
    function onTokenTransfer(address _from, address /*_to*/, uint256 _value) public {
        require(msg.sender == address(token));
        if(address(tapVoting) != address(0) && !tapVoting.finalized()) {
            tapVoting.onTokenTransfer(_from, _value);
        }
        if(address(bufferVoting) != address(0) && !bufferVoting.finalized()) {
            bufferVoting.onTokenTransfer(_from, _value);
        }
        if(address(refundVoting) != address(0) && !refundVoting.finalized()) {
            refundVoting.onTokenTransfer(_from, _value);
        }
    }

    /**
     * @dev Update minVotedTokensPerc value after tap and buffer votings.
     * Set new value == 50% from current voted tokens amount
     */
    function updateMinVotedTokens(uint256 _minVotedTokensPerc) internal {
        if(minVotedTokensPerc >= MAX_VOTED_TOKEN_PERC) {
            return;
        }

        uint256 newPerc = safeDiv(_minVotedTokensPerc, 2);
        if(newPerc > MAX_VOTED_TOKEN_PERC) {
            minVotedTokensPerc = MAX_VOTED_TOKEN_PERC;
            return;
        }
        minVotedTokensPerc = newPerc;
    }

    // Tap voting
    function createTapVoting(uint256 _tap) public onlyOwner {
        require(state == FundState.TeamWithdraw);
        require(tapVoting == address(0));
        require(lastTapVotingTime == 0 || now - lastTapVotingTime >= 2 weeks);
        require(_tap > tap);
        require(safeSub(_tap, tap) <= safeDiv(safeMul(tap, MAX_TAP_INC_PERC), 100));
        uint256 startTime = now + VOTING_START_LATENCY;
        uint256 endTime = startTime + VOTING_DURATION;
        tapVoting = new TapVoting(_tap, token, this, startTime, endTime, minVotedTokensPerc);
    }

    function onTapVotingFinish(bool agree, uint256 _tap) public {
        require(msg.sender == address(tapVoting) && tapVoting.finalized());
        if(agree) {
            tap = _tap;
        }
        lastTapVotingTime = now;
        updateMinVotedTokens(tapVoting.getVotedTokensPerc());
        delete tapVoting;
    }

    // Buffer voting
    function createBufferVoting(uint256 bufferAmount) public onlyOwner {
        require(state == FundState.TeamWithdraw);
        require(bufferVoting == address(0));
        require(lastBufferVotingTime == 0 || now - lastBufferVotingTime >= 2 weeks);
        require(bufferAmount <= safeMul(tap, 10 * 30 days));
        uint256 startTime = now + VOTING_START_LATENCY;
        uint256 endTime = startTime + VOTING_DURATION;
        bufferVoting = new BufferVoting(bufferAmount, token, this, startTime, endTime, minVotedTokensPerc);
    }

    function onBufferVotingFinish(bool agree, uint256 _bufferAmount) public {
        require(msg.sender == address(bufferVoting) && bufferVoting.finalized());
        if(agree) {
            overheadBufferAmount = safeAdd(overheadBufferAmount, _bufferAmount);
        }
        lastBufferVotingTime = now;
        updateMinVotedTokens(bufferVoting.getVotedTokensPerc());
        delete bufferVoting;
    }

    // Oracle voting
    function createOracleVoting() public onlyOracle {
        require(now <= crowdsaleEndDate + 730 days);
        require(state == FundState.TeamWithdraw);
        require(oracleVoting == address(0));
        require(lastOracleVotingTime == 0 || now - lastOracleVotingTime >= 2 weeks);
        uint256 startTime = now + VOTING_START_LATENCY;
        uint256 endTime = startTime + VOTING_DURATION;
        oracleVoting = new OracleVoting(oraclesAddresses, minOraclesVoted, address(this), startTime, endTime);
    }

    function onOracleVotingFinish(bool agree) public {
        require(msg.sender == address(oracleVoting) && oracleVoting.finalized());
        lastOracleVotingTime = now;
        if(agree) {
            refundVotingEnabled = true;
            return; // Do not del voting address
        }
        delete oracleVoting;
    }

    // Refund voting
    function createRefundVoting() public onlyOracle {
        require(state == FundState.TeamWithdraw);
        require(refundVoting == address(0) && refundVotingEnabled);
        uint256 startTime = now + VOTING_START_LATENCY;
        uint256 endTime = startTime + VOTING_DURATION;
        refundVoting = new RefundVoting(token, this, startTime, endTime, minVotedTokensPerc);
    }

    function onRefundVotingFinish(bool agree) public {
        require(msg.sender == address(refundVoting) && refundVoting.finalized());
        refundVotingEnabled = false;
        if(agree) {
            enableRefund();
            return; // Do not del voting address
        }
        delete oracleVoting;
        delete refundVoting;
    }

    function forceRefund() public onlyOwner {
        enableRefund();
    }
}
