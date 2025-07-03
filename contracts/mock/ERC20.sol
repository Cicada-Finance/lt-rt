// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {
    constructor() ERC20("USD1", "USD1") {
        _mint(msg.sender, 1000000000000 * 10 ** 18);
    }
    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
