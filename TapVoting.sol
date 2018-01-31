pragma solidity ^0.4.18;

import './voting/BaseVoting.sol';
import './fund/IVotingManagedFund.sol';


/**
 * @title TapVoting
 * @dev Voting to increase tap amount
 */
contract TapVoting is BaseVoting {
    uint256 tap;

    /**
     * TapVoting constructor
     * @param _tap New tap value
     * @param _tokenAddress ERC20 compatible token contract address
     * @param _fundAddress Fund contract address
     * @param _startTime Voting start time
     * @param _endTime Voting end time
     * @param _minTokensPerc - Min percent of tokens from totalSupply where voting is considered to be fulfilled
     */
    function TapVoting(uint256 _tap, address _tokenAddress, address _fundAddress, uint256 _startTime, uint256 _endTime, uint256 _minTokensPerc) public
        BaseVoting(_tokenAddress, _fundAddress, _startTime, _endTime, _minTokensPerc)
    {
        tap = _tap;
    }

    function onVotingFinish(bool agree) internal {
        IVotingManagedFund fund = IVotingManagedFund(fundAddress);
        fund.onTapVotingFinish(agree, tap);
    }
}
