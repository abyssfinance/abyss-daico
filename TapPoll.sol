pragma solidity ^0.4.18;

import './poll/BasePoll.sol';
import './fund/IPollManagedFund.sol';


/**
 * @title TapPoll
 * @dev Poll to increase tap amount
 */
contract TapPoll is BasePoll {
    uint256 tap;

    /**
     * TapPoll constructor
     * @param _tap New tap value
     * @param _tokenAddress ERC20 compatible token contract address
     * @param _fundAddress Fund contract address
     * @param _startTime Poll start time
     * @param _endTime Poll end time
     */
    function TapPoll(uint256 _tap, address _tokenAddress, address _fundAddress, uint256 _startTime, uint256 _endTime) public
        BasePoll(_tokenAddress, _fundAddress, _startTime, _endTime, false)
    {
        tap = _tap;
    }

    function onPollFinish(bool agree) internal {
        IPollManagedFund fund = IPollManagedFund(fundAddress);
        fund.onTapPollFinish(agree, tap);
    }
}
