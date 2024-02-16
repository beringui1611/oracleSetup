// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "./IOracleConsumer.sol";
import "./IStableCoin.sol";
import "./IOracle.sol";

contract Rebase is IOracleConsumer,Pausable {
    address public oracle;
    address public stablecoin;
    uint public lastUpdate = 0; // timestamp em segundos
    uint private updateTolerance = 300; // segundos
    address public owner;

    mapping(address => uint) public ethBalance; // customer => saldo em wei

    constructor(address oracleAddress, address stablecoinAddress) {
        owner = msg.sender;
        oracle = oracleAddress;
        stablecoin = stablecoinAddress;
    }

    function initialize(uint weisPerPenny) external payable onlyOwner {
        require(weisPerPenny > 0, "Wei ratio cannot be zero");
        require(msg.value >= weisPerPenny, "Value cannot be less than wei ratio");

        ethBalance[msg.sender] = msg.value;
        IStableCoin(stablecoin).mint(msg.sender, msg.value / weisPerPenny);
        lastUpdate = block.timestamp;
    }

    function setOracle(address newOracle) external onlyOwner {
        require(newOracle != address(0), "Oracle address cannot be zero");
        oracle = newOracle;
    }

    function setUpdateTolerance(uint toleranceInSeconds) external onlyOwner {
        require(toleranceInSeconds > 0, "toleranceInSeconds cannot be zero");
        updateTolerance = toleranceInSeconds;
    }

    function update(uint weisPerPenny) external {
        require(msg.sender == oracle, "Only the oracle can make this call");
        uint oldSupply = IStableCoin(stablecoin).totalSupply();
        uint newSupply = adjustSupply(weisPerPenny);

        if (newSupply != 0) {
            lastUpdate = block.timestamp;
            emit Updated(lastUpdate, oldSupply, newSupply);
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // 100 = 1:1, 97 = 0.97, 104 = 1.04
    function getParity(uint weisPerPenny) public view returns (uint) {
        if (weisPerPenny == 0) weisPerPenny = IOracle(oracle).getWeiRatio();
        return (IStableCoin(stablecoin).totalSupply() * 100) / (address(this).balance / weisPerPenny);
    }

    function deposit() external payable whenNotPaused whenNotOutdated {
        uint weisPerPenny = IOracle(oracle).getWeiRatio();
        require(msg.value >= weisPerPenny, "Insufficient deposit");

        ethBalance[msg.sender] = msg.value;
        uint tokens = msg.value / weisPerPenny;
        IStableCoin(stablecoin).mint(msg.sender, tokens);
    }

    function withdrawEth(uint amountEth) external whenNotPaused whenNotOutdated {
        require(ethBalance[msg.sender] >= amountEth, "Insufficient ETH balance");

        ethBalance[msg.sender] -= amountEth;
        uint weisPerPenny = IOracle(oracle).getWeiRatio();
        IStableCoin(stablecoin).burn(msg.sender, amountEth / weisPerPenny);
        payable(msg.sender).transfer(amountEth);
    }

    function withdrawUsda(uint amountUsda) external whenNotPaused whenNotOutdated {
        require(IStableCoin(stablecoin).balanceOf(msg.sender) >= amountUsda, "Insufficient USDA balance");

        IStableCoin(stablecoin).burn(msg.sender, amountUsda);
        uint weisPerPenny = IOracle(oracle).getWeiRatio();
        uint amountEth = amountUsda * weisPerPenny;
        ethBalance[msg.sender] -= amountEth;
        payable(msg.sender).transfer(amountEth);
    }

    function adjustSupply(uint weisPerPenny) internal returns (uint) {
        uint parity = getParity(weisPerPenny);

        if (parity == 0) {
            _pause();
            return 0;
        }

        IStableCoin algoDollar = IStableCoin(stablecoin);
        uint totalSupply = algoDollar.totalSupply();

        if (parity == 100) return totalSupply;
        if (parity > 100) {
            algoDollar.burn(owner, (totalSupply * (parity - 100)) / 100);
        } else if (parity < 100) {
            algoDollar.mint(owner, (totalSupply * (100 - parity)) / 100);
        }

        return algoDollar.totalSupply();
    }

    modifier whenNotOutdated() {
        require(lastUpdate >= (block.timestamp - updateTolerance), "Rebase contract is paused. Try again later or contact the admin");
        _;
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "Unhauthorized.");
        _;
    }
}
