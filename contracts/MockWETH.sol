// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockWETH is ERC20, Ownable {
    using SafeMath for uint256;

    constructor() ERC20("WETH", "WETH") {}

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
