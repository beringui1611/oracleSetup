// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./IStableCoin.sol";

contract AlgoDollar is ERC20, ERC20Burnable,IStableCoin {

    address public rebase;
    address public immutable owner;

    constructor() ERC20("AlgoDollar", "USDA"){
        owner = msg.sender;
    }

    function setRebase(address newRebase) external onlyOwner {
        rebase = newRebase;
    }

    function mint(address to, uint amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function burn(address from, uint amount) external onlyOwner {
        _burn(from, amount);
    }

    function decimals() public view virtual override returns (uint8){
        return 2;
    }

    modifier onlyOwner(){
        require(msg.sender == owner,
        "Unauthorized!");
        _;
    }

}