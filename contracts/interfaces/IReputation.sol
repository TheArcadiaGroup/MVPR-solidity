pragma solidity 0.7.5;

interface IReputation {
    /// ERC20-like properties providing general information
    /// about token name and symbol
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    /// ERC777-like granularity
    function granularity() external view returns (uint256);

    /// Reputation may be limited or onlimited by the supply. These functions
    /// provide information whether the supply is limited and, if not, the
    /// `totalLimit()` and `currentSupply()` will be returning the maximum amount
    /// of the tokens that can be produced and current token issuance
    function hasLimit() external view returns (bool);

    function totalLimit() external view returns (uint256);

    function currentSupply() external view returns (uint256);

    /// Function returns the balance of reputation tokens on an account
    function balanceOf(address owner) external view returns (uint256);

    /// Function returns the address that is authorised to sign transactions
    /// to this contract that can affect amount of the reputation on the account
    function authAddress(address owner)
        external
        view
        returns (address, uint256);

    /// Authorizes address to interact with the contract on behalf
    /// of the balance owner for a some duration (amount of blocks)
    function grantAddressAuth(address auth, uint256 duration)
        external
        returns (address);

    /// Extends authorized duration for the registered authorized address
    function extendAuthDuration(uint256 forDuration) external;

    /// Remokes authorisation right from the currently authorised address
    /// to interact with the contract on behalf of account owner
    function revokeAddressAuth() external;

    function isMember(address account) external returns (bool);
    function compliance() external returns (address);

    /// Produced when contract generates some about of reputation and assigns
    /// it to a certain account
    event Issued(address owner, uint256 amountProduced);
    /// Produced when contract burns some about of reputation on a certain account
    event Burned(address owner, uint256 amountBurned);

    /// Events for operations with authorised accounts
    event AuthGranted(address owner, address auth, uint256 duration);
    event AuthRevoked(address owner, address auth);
    event AuthExpired(address owner, address auth);
}
