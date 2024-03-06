# Starknet Token Vesting Contracts

> :warning: **These contracts are not audited.** Before using or contributing to this project, please be aware that it has not undergone a security audit. Use it at your own risk.

Vesting contracts written in Cairo1 for Starknet ERC20 tokens.

This is a fork of Solidity's [TokenVesting](https://github.com/AbdelStark/token-vesting-contracts/) which was released under the Apache-2.0.
We are not the original authors and this is just a Cairo1 re-write of the original.

All credit and gratitude to [AbdelStark](https://github.com/AbdelStark) for open-sourcing the original code.

## Motivation

Starknet season is upon us.

<p align="center">
  <a href="https://www.starknet-ecosystem.com" target="_blank">
    <img src="https://www.starknet-ecosystem.com/starknet-map.png">
  </a>
</p>

We found there were not many vesting contracts written in Cairo1 that were as easy to use
as the original written version in Solidity.

Also we've been pushing away learning Starknet components and upgrading our Scarb version, so this gave us good practice.

## Overview

There's 2 contracts that can be used depending on the ERC20 implementation:

- `camel_erc20_vesting.cairo` - This is for tokens which follow the ERC20 camelCase interface (mostly for already deployed tokens)
- `snake_erc20_vesting.cairo` - This is for newer Starknet tokens which follow the snake case standard.

As outlined in the [Great Interface Migration](https://community.starknet.io/t/the-great-interface-migration/92107) the camelCase
interfaces should be dropped in favour of the snake, all snake. We kept the camel here in case of tokens that have already been
launched and don't have plans on migrating.

It uses [OpenZeppelin Cairo contracts](https://github.com/OpenZeppelin/cairo-contracts/). We didn't include the dual case standard
as the dualCase dispatchers won’t work on live chains (mainnet or testnets) until there's syscall panic handlings on Starknet, we will add it then.

The only real difference in the implementation was on how we compute the vesting schedule ID's. On the original Solidity version the `keccak256`
hash is used to compute the ID's, in this case we used the `poseidon` hash which is natively supported in Starknet.

## License

Token Vesting Contracts is released under the Apache-2.0.

## Credits

This is a Cairo fork of https://github.com/AbdelStark/token-vesting-contracts/

- Original Author: [@AbdelStark](https://github.com/AbdelStark/token-vesting-contracts/)


Keep Starknet Strange!
