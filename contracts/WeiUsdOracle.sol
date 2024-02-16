// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IOracle.sol";
import "./IOracleConsumer.sol";

contract WeiUsdOracle is IOracle {
    
    uint private lastRatio = 0;
    uint public lastUpdate = 0;
    address[] public subscribers;
    address public immutable owner;

    constructor(uint ethPriceInPenny)  {
        owner = msg.sender;
        uint weisPerPenny = calcWeiRatio(ethPriceInPenny);
        lastRatio = weisPerPenny;
        lastUpdate = block.timestamp;
    }

    function calcWeiRatio(uint ethPriceInPenny) internal pure returns (uint) {
        return (10 ** 18) / ethPriceInPenny;
    }

    function setEthPrice(uint ethPriceInPenny) external{
        require(ethPriceInPenny > 0, "ETH price cannot be zero");

        uint weisPerPenny = calcWeiRatio(ethPriceInPenny);
        require(weisPerPenny > 0, "Wei Ratio cannot be zero");

        lastRatio = weisPerPenny;
        lastUpdate = block.timestamp;

        for(uint i=0; i < subscribers.length; ++i){
            if(subscribers[i] != address(0)){
                IOracleConsumer(subscribers[i]).update(weisPerPenny);
            }
        }

        if(subscribers.length > 0)
            emit AllUpdated(subscribers);
    }

    function getWeiRatio() external view returns (uint){
        return lastRatio;
    }

    function subscribe(address subscriber) external onlyOwner {
        require(subscriber != address(0), "Subscriber cannot be zero");
        emit Subscribed(subscriber);

        for(uint i=0; i < subscribers.length; ++i){
            if(subscribers[i] == address(0)){
                subscribers[i] = subscriber;
                return;
            }
            else if(subscribers[i] == subscriber){
                return;
            }
        }

        subscribers.push(subscriber);
    }

    function unsubscribe(address subscriber) external onlyOwner {
        require(subscriber != address(0), "Subscriber cannot be zero");

        for(uint i=0; i < subscribers.length; ++i){
            if(subscribers[i] == subscriber){
                delete subscribers[i];
                emit Unsubscribed(subscriber);
                return;
            }
        }
    }

    modifier onlyOwner(){
        require(msg.sender == owner,
        "Unhauthorized!"
        );
        _;
    }

}