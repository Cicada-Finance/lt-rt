// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./utils/Ownable.sol";

contract ltMNER is ERC20, Ownable {
    constructor(address _receive, address _owner) ERC20("ltMNER", "ltMNER") Ownable(_owner) {
        _mint(_receive, 915910 * 10 ** 18);
    }

    function mintTo(uint256 _amt) external onlyOwner {
        _mint(msg.sender, _amt);
    }
}
