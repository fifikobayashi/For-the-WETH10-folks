# For the WETH10 folks
Barebones Flash Mint friendly WETH10 compatible DEX that swaps 1 to 1 between WETH10 and ETH

- WETH10Dex 0x00233651d6b1b4F2886Cd7b7E4658B8FA7fCc699

- TestFlashMinter 0x957968A01ce61B5c5201a274264Da2d3151CE50C

[Sample Tx on Ropsten](https://ropsten.etherscan.io/tx/0x3ab95479a3f59710edfe666a09ce64392b8bbbf26eefabf07303270220c35cb7
): 
1. TestFlashMinter flash mints 1 WETH10
2. Swap 1 WETH10 to ETH on DEX
3. Swaps 1 ETH back to WETH10 on DEX
4. The 1 WETH10 is burned to complete the flash mint Tx


