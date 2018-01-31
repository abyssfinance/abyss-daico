pragma solidity ^0.4.18;

/**
 * @title ICrowdsaleFund
 * @dev Fund methods used by crowdsale contract
 */
interface ICrowdsaleFund {
    /**
    * @dev Function accepts user`s contributed ether and logs contribution
    * @param _from Contributor wallet address.
    */
    function processContribution(address _from) external payable;
    /**
    * @dev Function is called on the end of successful crowdsale
    */
    function onCrowdsaleEnd() external;
    /**
    * @dev Function is called if crowdsale failed to reach soft cap
    */
    function enableCrowdsaleRefund() external;
    /**
    * @dev Function is called by contributor to refund payments if crowdsale failed to reach soft cap
    */
    function refundCrowdsaleContributor() external;
}
