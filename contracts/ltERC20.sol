// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ltCIC is ERC20 {
    constructor(address _receive) ERC20("ltCIC", "ltCIC") {
        _mint(_receive, 10000000000 * 10 ** 18);
    }
}
