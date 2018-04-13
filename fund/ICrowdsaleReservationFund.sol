pragma solidity ^0.4.21;

/**
 * @title ICrowdsaleReservationFund
 * @dev ReservationFund methods used by crowdsale contract
 */
interface ICrowdsaleReservationFund {
    /**
     * @dev Check if contributor has transactions
     */
    function canCompleteContribution(address contributor) external returns(bool);
    /**
     * @dev Complete contribution
     * @param contributor Contributor`s address
     */
    function completeContribution(address contributor) external;
    /**
     * @dev Function accepts user`s contributed ether and amount of tokens to issue
     * @param contributor Contributor wallet address.
     * @param _tokensToIssue Token amount to issue
     * @param _bonusTokensToIssue Bonus token amount to issue
     */
    function processContribution(address contributor, uint256 _tokensToIssue, uint256 _bonusTokensToIssue) external payable;

    /**
     * @dev Function returns current user`s contributed ether amount
     */
    function contributionsOf(address contributor) external returns(uint256);

    /**
     * @dev Function is called on the end of successful crowdsale
     */
    function onCrowdsaleEnd() external;
}
