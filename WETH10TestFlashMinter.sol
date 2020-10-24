// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.0;

interface IWETH10Dex {
    function depositETH() external payable;
    function depositWETH10(uint256 amount) external payable;
    function withdrawETH(uint256 amount) external;
    function withdrawWETH10(uint256 amount) external;
    function internalSwapToETH(uint256 amount) external;
    function internalSwapToWETH10(uint256 amount) external;
    function WETH10() external returns (address);
}

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

interface FlashMintableLike {
    function flashMint(uint256, bytes calldata) external;
    function balanceOf(address) external returns (uint256);
    function deposit() external payable;
    function withdraw(uint256) external;
    function transfer(address, uint256) external;
}


// Ropster WETH10 Dex deployed at 0xF004C9DdcfAfD2a43998AB38e8525279b89128d2
contract TestFlashMinter {
    enum Action {NORMAL, STEAL, WITHDRAW, REENTER, OVERSPEND}

    uint256 public flashBalance;
    uint256 public flashValue;
    address public flashData;

    // Initialize flash mint interfaces
    IWETH10Dex public exchange = IWETH10Dex(0x00233651d6b1b4F2886Cd7b7E4658B8FA7fCc699); // address of WETH10 compatible DEX
    IWETH10 public weth10 = IWETH10(exchange.WETH10()); // address of WETH10 contract
    
    receive() external payable {}

    function executeOnFlashMint(uint256 value, bytes calldata data) external {
        flashValue = value;
        (Action action, address target) = abi.decode(data, (Action, address)); // Use this to unpack arbitrary data
        flashData = target;  // Here msg.sender is the weth contract, and target is the user
        if (action == Action.NORMAL) {
            flashBalance = FlashMintableLike(msg.sender).balanceOf(address(this));
        } else if (action == Action.WITHDRAW) {
            FlashMintableLike(msg.sender).withdraw(value);
            flashBalance = address(this).balance;
            FlashMintableLike(msg.sender).deposit{ value: value }();
        } else if (action == Action.STEAL) {
            FlashMintableLike(msg.sender).transfer(address(1), value);
        } else if (action == Action.REENTER) {
            flashMint(msg.sender, value * 2);
        } else if (action == Action.OVERSPEND) {
            FlashMintableLike(msg.sender).transfer(address(0), 1);
        }
        
        // *** interactions with the WETH10 Dex ***
        
        // grant the exchange WETH10 spending approval
        weth10.approve(address(exchange), value);
        
        // deposit the unbacked flash minted WETH10 onto the exchange to receive equal 'credits'
        exchange.depositWETH10(value);

        // redeem the 'credits' from the deposited WETH10 to withdraw the same amount of ETH
        exchange.withdrawETH(value);
        
        // then do the reverse so this WETH10 flash mint Tx won't revert
        exchange.depositETH{value: value}();
        exchange.withdrawWETH10(value);
        
    }

    function flashMint(address target, uint256 value) public {
        // Use this to pack arbitrary data to `executeOnFlashMint`
        bytes memory data = abi.encode(Action.NORMAL, msg.sender); // Here msg.sender is the user, and target is the weth contract
        FlashMintableLike(target).flashMint(value, data);
    }

    function flashMintAndWithdraw(address target, uint256 value) public {
        // Use this to pack arbitrary data to `executeOnFlashMint`
        bytes memory data = abi.encode(Action.WITHDRAW, msg.sender); // Here msg.sender is the user, and target is the weth contract
        FlashMintableLike(target).flashMint(value, data);
    }

    function flashMintAndSteal(address target, uint256 value) public {
        // Use this to pack arbitrary data to `executeOnFlashMint`
        bytes memory data = abi.encode(Action.STEAL, msg.sender); // Here msg.sender is the user, and target is the weth contract
        FlashMintableLike(target).flashMint(value, data);
    }

    function flashMintAndReenter(address target, uint256 value) public {
        // Use this to pack arbitrary data to `executeOnFlashMint`
        bytes memory data = abi.encode(Action.REENTER, msg.sender); // Here msg.sender is the user, and target is the weth contract
        FlashMintableLike(target).flashMint(value, data);
    }

    function flashMintAndOverspend(address target, uint256 value) public {
        bytes memory data = abi.encode(Action.OVERSPEND, msg.sender); // Here msg.sender is the user, and target is the weth contract
        FlashMintableLike(target).flashMint(value, data);
    }
}