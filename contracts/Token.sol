// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
* --description contract--
*/
contract Token is ERC20("Avalanch", "AVAX"){
    
    /*
    * --description constructor--
    */
    constructor(address sender, uint256 value) {
        _mint(sender, value);
    }
}
