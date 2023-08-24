// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract RakePool {
    address public owner;
    uint256 public totalRake;

    constructor() {
        owner = msg.sender;
        totalRake = 0;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function addRake() external payable {
        totalRake += msg.value;
    }

    function withdraw() external onlyOwner {
        require(totalRake > 0, "No rake to withdraw");
        
        uint256 amountToWithdraw = totalRake;
        totalRake = 0; // Reset the totalRake after withdrawing
        
        payable(owner).transfer(amountToWithdraw);
    }

    function withdrawSpecificAmount(uint256 amount, address to) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient contract balance");

        payable(to).transfer(amount);
    }
}
