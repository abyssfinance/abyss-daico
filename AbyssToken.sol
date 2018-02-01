import './token/TransferLimitedToken.sol';


contract AbyssToken is TransferLimitedToken {
    uint256 public constant SALE_END_TIME = 1522540800; // 01.04.2018

    function AbyssToken(address _listener, address[] _owners, address manager) public
        TransferLimitedToken(SALE_END_TIME, _listener, _owners, manager)
    {
        name = "ABYSS";
        symbol = "ABYSS";
        decimals = 18;
    }
}