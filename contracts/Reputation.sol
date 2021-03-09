pragma solidity 0.7.5;

import "./interfaces/IReputation.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Reputation is IReputation {
    using SafeMath for uint256;

    string internal constant _name = "ERC1329";
    string internal constant _symbol = "REP";
    uint256 internal constant _granularity = 1;

    // key : owner , value : balance
    mapping(address => uint256) internal _balances;
    // key : auth  , value : duration (blocks)
    mapping(address => uint256) internal _authorized_duration;
    // key : owner , value : auth
    mapping(address => address) internal _authorized_addresses;
    // key : auth  , value : owner
    mapping(address => address) internal _owner_addresses;
    // key : owner , value : banned
    mapping(address => bool) internal _banneds;

    mapping(address => bool) public complianceOfficers;

    mapping(address => bool) members;

    uint256 internal _totalLimit;
    uint256 internal _currentSupply;

    address public votingEngineAddress;
    address public failSafeAddress;
    address public etaAddress;

    event FailSafeRemoved(address remover);
    event MemberAdded(address newMember);
    event ComplianceOfficerAddition(address newComplianceOfficerAddress);
    event ComplianceOfficerRemoval(address complianceOfficerAddressToRemove);

    modifier onlyVotingEngine() {
        require(msg.sender == votingEngineAddress, "Only voting engine is authorized");
        _;
    }

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    constructor(
        address _votingEngineAddress,
        address _failSafeAddress,
        address _etaAddress
    ) {
        // no tokens minted on deploy
        _currentSupply = 0;
        _totalLimit = 2**256 - 1;
        require(_votingEngineAddress != address(0), "No zero address allowed");
        require(_failSafeAddress != address(0), "No zero address allowed");
        require(_etaAddress != address(0), "No zero address allowed");
        votingEngineAddress = _votingEngineAddress;
        failSafeAddress = _failSafeAddress;
        etaAddress = _etaAddress;
        complianceOfficers[etaAddress] = true;
        members[_etaAddress] = true;
        members[_failSafeAddress] = true;
    }

    // ------------------------------------------------------------------------
    // Functions
    // ------------------------------------------------------------------------
    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function granularity() public view override returns (uint256) {
        return _granularity;
    }

    /// Reputation may be limited or unlimited by the supply. These functions
    /// provide information whether the supply is limited and, if not, the
    /// `totalLimit()` and `currentSupply()` will be returning the maximum amount
    /// of the tokens that can be produced and current token issuance
    function hasLimit() public view override returns (bool) {
        return false;
    }

    function totalLimit() public view override returns (uint256) {
        return _totalLimit; /// max value for uint256
    }

    function currentSupply() public view override returns (uint256) {
        return _currentSupply; /// max value for uint256
    }

    function balanceOf(address owner) public view override returns (uint256) {
        return _balances[owner]; /// return requested owner balance
    }

    /// Authorizes address to interact with the contract on behalf
    /// of the balance owner for a some duration (amount of blocks)
    function authAddress(address owner) public view override returns (address, uint256) {
        address auth = _authorized_addresses[owner];
        return (auth, _authorized_duration[auth]);
    }

    /// Authorizes address to interact with the contract on behalf
    /// of the balance owner for a some duration (amount of blocks)
    function grantAddressAuth(address auth, uint256 duration) public override returns (address) {
        require(tx.origin == msg.sender);
        require(auth != address(0));
        require(_owner_addresses[auth] == address(0));

        address prev = _authorized_addresses[tx.origin];
        delete _authorized_duration[prev];
        delete _owner_addresses[prev];

        _authorized_addresses[tx.origin] = auth;
        _authorized_duration[auth] = duration.add(block.number);
        _owner_addresses[auth] = tx.origin;

        emit AuthGranted(msg.sender, auth, duration);
        return prev;
    }

    /// Extends authorized duration for the registered authorized address
    function extendAuthDuration(uint256 forDuration) public override {
        require(tx.origin == msg.sender);
        require(_authorized_addresses[tx.origin] != address(0));

        address auth = _authorized_addresses[tx.origin];

        uint256 old_duration = _authorized_duration[auth];

        if (old_duration < block.number) {
            _authorized_duration[auth] = block.number.add(forDuration);
        } else {
            _authorized_duration[auth] = _authorized_duration[auth].add(forDuration);
        }

        emit AuthGranted(tx.origin, auth, forDuration);
    }

    function revokeAddressAuth() public override {
        require(tx.origin == msg.sender);
        require(_authorized_addresses[tx.origin] != address(0));

        address auth = _authorized_addresses[tx.origin];
        delete _authorized_addresses[tx.origin];
        delete _owner_addresses[auth];
        delete _authorized_duration[auth];

        emit AuthRevoked(tx.origin, auth);
    }

    function mint(address account, uint256 amount) external onlyVotingEngine {
        require(account != address(0), "ERC-1329: No zero address allowed");
        _currentSupply = _currentSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Issued(account, amount);
    }

    function burn(address account, uint256 amount) external onlyVotingEngine {
        require(account != address(0), "ERC-1329: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC-1329: burn amount exceeds balance");
        _balances[account] = accountBalance.sub(amount);
        _currentSupply = _currentSupply.sub(amount);

        emit Burned(account, amount);
    }

    function isMember(address account) external view override returns (bool) {
        return members[account];
    }

    function addMember(address account) external onlyVotingEngine {
        members[account] = true;
        emit MemberAdded(account);
    }

    function addComplianceOfficer(address newComplianceOfficerAddress) external override onlyVotingEngine {
        complianceOfficers[newComplianceOfficerAddress] = true;
        emit ComplianceOfficerAddition(newComplianceOfficerAddress);
    }

    function removeComplianceOfficer(address complianceOfficerAddressToRemove) external override onlyVotingEngine {
        complianceOfficers[complianceOfficerAddressToRemove] = false;
        emit ComplianceOfficerRemoval(complianceOfficerAddressToRemove);
    }

    // Returns true if compliance member, false otherwise
    function isComplianceOfficer(address account) external view override returns (bool) {
        return complianceOfficers[account];
    }
}
