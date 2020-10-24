pragma solidity 0.5.16;

// forked from Austin William's fWETH concept and customized for the WETH10 implementation

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/token/ERC20/SafeERC20.sol";

interface IWETH10 {

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function totalSupply() external view returns (uint256);
    function deposit() external payable;
    function depositTo(address to) external payable;
    function depositToAndCall(address to, bytes calldata data) external payable returns (bool success);
    function flashMint(uint256 value, bytes calldata data) external;
    function withdraw(uint256 value) external;
    function withdrawTo(address to, uint256 value) external;
    function withdrawFrom(address from, address to, uint256 value) external;
    function approve(address spender, uint256 value) external returns (bool);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transferAndCall(address to, uint value, bytes calldata data) external returns (bool success);
    
}

// @notice A constant-sum market for ETH and WETH10
contract WETH10DEX {

    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    address constant public WETH10 = 0xD25f374A2d7d40566b006eC21D82b9655865F941; // address of WETH10 contract on ropsten

    // users get "credits" for depositing ETH or WETH10
    // credits can be redeemed for an equal number of ETH or WETH10
    // e.g.: You can deposit 5 WETH10 to get 5 "credits", and then immediately use those credits to
    // withdrawl 5 ETH.
    mapping (address => uint256) public credits;

   // fallback must be payable and empty to receive ETH from the WETH10 contract
    function () external payable {}

    // ==========
    //  DEPOSITS
    // ==========

    // Gives depositor credits for ETH
    function depositETH() public payable {
        credits[msg.sender] = credits[msg.sender].add(msg.value);
    }

    // Gives depositor credits for WETH10
    function depositWETH10(uint256 amount) public payable {
        ERC20(WETH10).safeTransferFrom(msg.sender, address(this), amount);
        credits[msg.sender] = credits[msg.sender].add(amount);
    }

    // =============
    //  WITHDRAWALS
    // =============

    // Redeems credits for ETH
    function withdrawETH(uint256 amount) public {
        credits[msg.sender] = credits[msg.sender].sub(amount);
        // if the contract doesn't have enough ETH then try to get some
        uint256 ethBalance = address(this).balance;
        if (amount > ethBalance) {
            internalSwapToETH(amount.sub(ethBalance));
        }
        msg.sender.transfer(amount);
    }

    // Redeems credits for WETH10
    function withdrawWETH10(uint256 amount) public {
        credits[msg.sender] = credits[msg.sender].sub(amount);
        // if the contract doesn't have enough WETH10 then try to get some
        uint256 weth10Balance = ERC20(WETH10).balanceOf(address(this));
        if (amount > weth10Balance) {
            internalSwapToWETH10(amount.sub(weth10Balance));
        }
        ERC20(WETH10).safeTransfer(msg.sender, amount);
    }

    // ===================
    //  INTERNAL EXCHANGE (not secure, for demo purposes only)
    // ===================

    // Forces this contract to convert some of its own WETH10 to ETH
    function internalSwapToETH(uint256 amount) public {
        // redeem WETH10 for ETH via the FlashWETH contract
        IWETH10(WETH10).withdraw(amount);
    }

    // Forces this contract to convert some of its own ETH to WETH10
    function internalSwapToWETH10(uint256 amount) public {
        // deposit ETH for WETH10 via the FlashWETH contract
        IWETH10(WETH10).deposit.value(amount)();
    }

}

// note: sum of all credits should be at most address(this).balance.add(ERC20(WETH10).balanceOf(address(this)));