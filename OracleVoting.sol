pragma solidity ^0.4.18;

import './math/SafeMath.sol';
import './fund/IVotingManagedFund.sol';


/**
 * @title OracleVoting
 * @dev OracleVoting - enables creation of RefundingVoting. Only oracles can take part in voting.
 */
contract OracleVoting is SafeMath {
    struct OracleVote {
        uint256 time;
        bool agree;
    }

    bool public finalized;

    uint256 public startTime;
    uint256 public endTime;
    uint256 public minTotalVoted;
    uint256 public yesCounter = 0;
    uint256 public noCounter = 0;

    mapping(address => bool) public oracles;
    mapping(address => OracleVote) public oracleVote;
    address[] public oraclesAddresses;
    address public fundAddress;

    modifier canVote {
        require(oracles[msg.sender]);
        require(!finalized);
        require(now >= startTime && now <= endTime);
        _;
    }

    /**
     * @dev OracleVoting constructor
     * @param _oraclesAddresses Oracles wallets addresses
     * @param _minTotalVoted Min number of oracles took part in voting where voting is considered to be fulfilled
     * @param _fundAddress IVotingManagedFund address
     * @param _startTime Voting start time
     * @param _endTime Voting end time
     */
    function OracleVoting(address[] _oraclesAddresses, uint256 _minTotalVoted, address _fundAddress, uint256 _startTime, uint256 _endTime) public {
        for (uint i = 0; i < _oraclesAddresses.length; i++) {
            oracles[_oraclesAddresses[i]] = true;
        }
        oraclesAddresses = _oraclesAddresses;
        minTotalVoted = _minTotalVoted;
        fundAddress = _fundAddress;
        startTime = _startTime;
        endTime = _endTime;
        finalized = false;
    }

    /**
     * @dev Process oracle`s vote
     * @param agree True if oracle endorses the proposal else False
     */
    function vote(bool agree) public canVote {
        if(oracleVote[msg.sender].time != 0) {
            revokeVote();
        }
        if(agree) {
            yesCounter = safeAdd(yesCounter, 1);
        } else {
            noCounter = safeAdd(noCounter, 1);
        }

        oracleVote[msg.sender].time = now;
        oracleVote[msg.sender].agree = agree;
    }

    /**
     * @dev Revoke oracle`s vote
     */
    function revokeVote() public canVote {
        require(oracleVote[msg.sender].time > 0);
        if(oracleVote[msg.sender].agree) {
            yesCounter = safeSub(yesCounter, 1);
        } else {
            noCounter = safeSub(noCounter, 1);
        }
        oracleVote[msg.sender].time = 0;
        oracleVote[msg.sender].agree = false;
    }

    /**
     * Finalize voting and call fund`s onOracleVotingFinish callback with result
     */
    function tryToFinalize() public returns(bool) {
        require(!finalized && now >= endTime);

        finalized = true;
        IVotingManagedFund fund = IVotingManagedFund(fundAddress);
        fund.onOracleVotingFinish(isSubjectApproved());
        return true;
    }

    function isSubjectApproved() internal view returns(bool){
        if(safeSub(yesCounter, noCounter) > 0 && safeAdd(yesCounter, noCounter) >= minTotalVoted) {
            return true;
        }
        return false;
    }

}
