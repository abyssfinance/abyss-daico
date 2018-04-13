pragma solidity ^0.4.21;

import './DateTime.sol';
import './Fund.sol';
import './TapPoll.sol';
import './RefundPoll.sol';
import './fund/IPollManagedFund.sol';
import './token/ITokenEventListener.sol';

/**
 * @title PollManagedFund
 * @dev Fund controlled by users
 */
contract PollManagedFund is Fund, DateTime, ITokenEventListener {
    uint256 public constant TAP_POLL_DURATION = 3 days;
    uint256 public constant REFUND_POLL_DURATION = 7 days;
    uint256 public constant MAX_VOTED_TOKEN_PERC = 10;

    TapPoll public tapPoll;
    RefundPoll public refundPoll;

    uint256 public minVotedTokensPerc = 0;
    uint256 public secondRefundPollDate = 0;
    bool public isWithdrawEnabled = true;

    uint256[] public refundPollDates = [
        1530403200, // 01.07.2018
        1538352000, // 01.10.2018
        1546300800, // 01.01.2019
        1554076800, // 01.04.2019
        1561939200, // 01.07.2019
        1569888000, // 01.10.2019
        1577836800, // 01.01.2020
        1585699200  // 01.04.2020
    ];

    modifier onlyTokenHolder() {
        require(token.balanceOf(msg.sender) > 0);
        _;
    }

    event TapPollCreated();
    event TapPollFinished(bool approved, uint256 _tap);
    event RefundPollCreated();
    event RefundPollFinished(bool approved);

    /**
     * @dev PollManagedFund constructor
     * params - see Fund constructor
     */
    function PollManagedFund(
        address _teamWallet,
        address _referralTokenWallet,
        address _foundationTokenWallet,
        address _companyTokenWallet,
        address _reserveTokenWallet,
        address _bountyTokenWallet,
        address _advisorTokenWallet,
        address[] _owners
        ) public
    Fund(_teamWallet, _referralTokenWallet, _foundationTokenWallet, _companyTokenWallet, _reserveTokenWallet, _bountyTokenWallet, _advisorTokenWallet, _owners)
    {
    }

    function canWithdraw() public returns(bool) {
        if(
            address(refundPoll) != address(0) &&
            !refundPoll.finalized() &&
            refundPoll.holdEndTime() > 0 &&
            now >= refundPoll.holdEndTime() &&
            refundPoll.isNowApproved()
        ) {
            return false;
        }
        return isWithdrawEnabled;
    }

    /**
     * @dev ITokenEventListener implementation. Notify active poll contracts about token transfers
     */
    function onTokenTransfer(address _from, address /*_to*/, uint256 _value) public {
        require(msg.sender == address(token));
        if(address(tapPoll) != address(0) && !tapPoll.finalized()) {
            tapPoll.onTokenTransfer(_from, _value);
        }
         if(address(refundPoll) != address(0) && !refundPoll.finalized()) {
            refundPoll.onTokenTransfer(_from, _value);
        }
    }

    /**
     * @dev Update minVotedTokensPerc value after tap poll.
     * Set new value == 50% from current voted tokens amount
     */
    function updateMinVotedTokens(uint256 _minVotedTokensPerc) internal {
        uint256 newPerc = safeDiv(_minVotedTokensPerc, 2);
        if(newPerc > MAX_VOTED_TOKEN_PERC) {
            minVotedTokensPerc = MAX_VOTED_TOKEN_PERC;
            return;
        }
        minVotedTokensPerc = newPerc;
    }

    // Tap poll
    function createTapPoll(uint8 tapIncPerc) public onlyOwner {
        require(state == FundState.TeamWithdraw);
        require(tapPoll == address(0));
        require(getDay(now) == 10);
        require(tapIncPerc <= 50);
        uint256 _tap = safeAdd(tap, safeDiv(safeMul(tap, tapIncPerc), 100));
        uint256 startTime = now;
        uint256 endTime = startTime + TAP_POLL_DURATION;
        tapPoll = new TapPoll(_tap, token, this, startTime, endTime, minVotedTokensPerc);
        TapPollCreated();
    }

    function onTapPollFinish(bool agree, uint256 _tap) external {
        require(msg.sender == address(tapPoll) && tapPoll.finalized());
        if(agree) {
            tap = _tap;
        }
        updateMinVotedTokens(tapPoll.getVotedTokensPerc());
        TapPollFinished(agree, _tap);
        delete tapPoll;
    }

    // Refund poll
    function checkRefundPollDate() internal view returns(bool) {
        if(secondRefundPollDate > 0 && now >= secondRefundPollDate && now <= safeAdd(secondRefundPollDate, 1 days)) {
            return true;
        }

        for(uint i; i < refundPollDates.length; i++) {
            if(now >= refundPollDates[i] && now <= safeAdd(refundPollDates[i], 1 days)) {
                return true;
            }
        }
        return false;
    }

    function createRefundPoll() public onlyTokenHolder {
        require(state == FundState.TeamWithdraw);
        require(address(refundPoll) == address(0));
        require(checkRefundPollDate());

        if(secondRefundPollDate > 0 && now > safeAdd(secondRefundPollDate, 1 days)) {
            secondRefundPollDate = 0;
        }

        uint256 startTime = now;
        uint256 endTime = startTime + REFUND_POLL_DURATION;
        bool isFirstRefund = secondRefundPollDate == 0;
        uint256 holdEndTime = 0;

        if(isFirstRefund) {
            holdEndTime = toTimestamp(
                getYear(startTime),
                getMonth(startTime) + 1,
                1
            );
        }
        refundPoll = new RefundPoll(token, this, startTime, endTime, holdEndTime, isFirstRefund);
        RefundPollCreated();
    }

    function onRefundPollFinish(bool agree) external {
        require(msg.sender == address(refundPoll) && refundPoll.finalized());
        if(agree) {
            if(secondRefundPollDate > 0) {
                enableRefund();
            } else {
                uint256 startTime = refundPoll.startTime();
                secondRefundPollDate = toTimestamp(
                    getYear(startTime),
                    getMonth(startTime) + 2,
                    1
                );
                isWithdrawEnabled = false;
            }
        } else {
            secondRefundPollDate = 0;
            isWithdrawEnabled = true;
        }
        RefundPollFinished(agree);

        delete refundPoll;
    }

    function forceRefund() public onlyOwner {
        enableRefund();
    }
}
