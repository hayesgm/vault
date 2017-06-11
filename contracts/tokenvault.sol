pragma solidity ^0.4.10;

// Token selling smart contract
// Inspired by https://github.com/bokkypoobah/TokenTrader

// https://github.com/ethereum/EIPs/issues/20
contract ERC20 {
    function totalSupply() constant returns (uint totalSupply);
    function balanceOf(address _owner) constant returns (uint balance);
    function transfer(address _to, uint _value) returns (bool success);
    function transferFrom(address _from, address _to, uint _value) returns (bool success);
    function approve(address _spender, uint _value) returns (bool success);
    function allowance(address _owner, address _spender) constant returns (uint remaining);
    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}

// standard owner controls
contract Owned {
    address public owner;
    event OwnershipTransferred(address indexed _from, address indexed _to);

    function Owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        if (msg.sender != owner) throw;
        _;
    }

    function transferOwnership(address newOwner) onlyOwner {
        OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

// contract can buy or sell tokens for ETH
// prices are in amount of wei per batch of token units

contract TokenVault is Owned {

    address public asset;       // address of token
    uint256 public sellPrice;   // contract sells lots at this price
    uint256 public units;       // lot size (token-wei)

    event MakerChangedAsset(address newAddress);
    event MakerWithdrewAsset(uint256 tokens);
    event MakerWithdrewERC20Token(address tokenAddress, uint256 tokens);
    event MakerWithdrewEther(uint256 ethers);
    event SoldTokens(uint256 tokens);

    // Constructor - only to be called by the TokenTraderFactory contract
    function TokenVault (
        address _asset,
        uint256 _sellPrice,
        uint256 _units
    ) {
        asset       = _asset;
        sellPrice   = _sellPrice;
        units       = _units;
    }
    
    function makerChangeAsset(address newAddress) onlyOwner{
        MakerChangedAsset(newAddress);
        asset = newAddress;
        return;
    }

    // Withdraw asset ERC20 Token
    function makerWithdrawAsset(uint256 tokens) onlyOwner returns (bool ok) {
        MakerWithdrewAsset(tokens);
        return ERC20(asset).transfer(owner, tokens);
    }

    // Withdraw other ERC20 Token
    function makerWithdrawERC20Token(
        address tokenAddress,
        uint256 tokens
    ) onlyOwner returns (bool ok) {
        MakerWithdrewERC20Token(tokenAddress, tokens);
        return ERC20(tokenAddress).transfer(owner, tokens);
    }

    // Withdraw ether
    function makerWithdrawEther(uint256 ethers) onlyOwner returns (bool ok) {
        if (this.balance >= ethers) {
            MakerWithdrewEther(ethers);
            return owner.send(ethers);
        }
    }

    // Primary function; called with Ether sent to contract
    function takerBuyAsset() payable {
        if (msg.sender == owner) {
            return;
        }
        else {
            // need to validate that units and price are valid and positive
            uint order    = msg.value / sellPrice;
            uint can_sell = ERC20(asset).balanceOf(address(this)) / units;
            // start with no change
            uint256 change = 0;
            if (msg.value > (can_sell * sellPrice)) {
                change  = msg.value - (can_sell * sellPrice);
                order = can_sell;
            }
            if (change > 0) {
                if (!msg.sender.send(change)) throw;
            }
            if (order > 0) {
                if (!ERC20(asset).transfer(msg.sender, order * units)) throw;
            }
            SoldTokens(order);
        }
    }

    // Ether is sent to the contract; can be either Maker or Taker
    function () payable {
        takerBuyAsset();
    }
}