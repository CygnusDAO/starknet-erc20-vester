/// Testing only OZ's camelCase ERC20 implementation
/// The tests follow the original TokenVesting.sol tests:
/// https://github.com/AbdelStark/token-vesting-contracts/blob/main/test/TokenVesting.js

/// Imports
use snforge_std::{
    declare, ContractClass, ContractClassTrait, start_prank, stop_prank, CheatTarget, start_warp, stop_warp, store
};
// use starknet::{ContractAddress, SyscallResultTrait, deploy_syscall};
// use core::{integer::BoundedInt, poseidon::poseidon_hash_span, num::traits::Zero};
use starknet::{ContractAddress, deploy_syscall, SyscallResultTrait};

/// Token vesting
use token_vesting::contracts::interface::{ITokenVestingDispatcher, ITokenVestingDispatcherTrait};

/// Mock erc20 token (NOTE: if panicking then get safe dispatchers)
use token_vesting::mock::camel_erc20::{ICamelERC20MockDispatcher, ICamelERC20MockDispatcherTrait};

/// Test constants
const INITIAL_SUPPLY: u256 = 1000;
const NAME: felt252 = 'Mock Token';
const SYMBOL: felt252 = 'MKTKN';

/// ---------------------------------------------------------------------------------------------- ///
///                                             TESTS                                              ///
/// ---------------------------------------------------------------------------------------------- ///

#[test]
fn test_deploy_mock() {
    let mock_token = deploy_mock_token();
    assert(mock_token.name() == NAME, 'wrong_name');
    assert(mock_token.symbol() == SYMBOL, 'wrong_symbol');
}

#[test]
fn test_totalSupply() {
    let mock_token = deploy_mock_token();
    assert(mock_token.totalSupply() == INITIAL_SUPPLY, 'wrong_totalSupply');
    assert(mock_token.balanceOf(admin()) == INITIAL_SUPPLY, 'wrong_admin_balance');
}

#[test]
fn test_transfer() {
    let mock_token = deploy_mock_token();
    assert(mock_token.balanceOf(admin()) == INITIAL_SUPPLY, 'wrong_admin_balance');
    start_prank(CheatTarget::One(mock_token.contract_address), admin());
    mock_token.transfer(rando(), INITIAL_SUPPLY / 2);
    stop_prank(CheatTarget::One(mock_token.contract_address));
    assert(mock_token.balanceOf(admin()) == INITIAL_SUPPLY / 2, 'wrong_admin_balance');
    assert(mock_token.balanceOf(rando()) == INITIAL_SUPPLY / 2, 'wrong_rando_balance');
}

#[test]
fn test_vesting_admin_and_token() {
    let (token, token_vesting) = deploy_mock_and_token_vesting();
    assert(token_vesting.get_token() == token.contract_address, 'wrong vesting token');
    assert(token_vesting.owner() == admin(), 'wrong_vesting_admin');
}

#[test]
fn test_fund_token_vesting() {
    let (mock_token, token_vesting) = deploy_mock_and_token_vesting();
    assert(token_vesting.get_token() == mock_token.contract_address, 'wrong vesting token');
    assert(token_vesting.owner() == admin(), 'wrong_vesting_admin');

    /// Transfer all supply to the vester (1000 tokens)
    start_prank(CheatTarget::One(mock_token.contract_address), admin());
    mock_token.transfer(token_vesting.contract_address, INITIAL_SUPPLY);
    stop_prank(CheatTarget::One(mock_token.contract_address));

    assert(mock_token.balanceOf(token_vesting.contract_address) == INITIAL_SUPPLY, 'vester_didnt_receive_tokens');
    assert(mock_token.balanceOf(admin()) == 0, 'wrong_admin_balance');

    assert(token_vesting.get_withdrawable_amount() == INITIAL_SUPPLY, 'wrong_withdrawable_amount');
}

#[test]
fn test_create_token_vesting() {
    /// Deploy mock token and vesting contract.
    let (mock_token, token_vesting) = deploy_mock_and_token_vesting();
    assert(token_vesting.get_token() == mock_token.contract_address, 'wrong vesting token');
    assert(token_vesting.owner() == admin(), 'wrong_vesting_admin');

    let duration = 1000_u256;
    fund_vesting_token(mock_token, token_vesting);
    create_schedule_for_holder(token_vesting, duration);

    // Get vesting ID
    let vesting_schedule_id = token_vesting.compute_vesting_schedule_id_for_address_and_index(vested_user(), 0);
    assert(token_vesting.compute_releasable_amount(vesting_schedule_id) == 0, 'wrong_releasable_amount');
    assert(token_vesting.get_vesting_schedule(vesting_schedule_id).amount == 100, 'wrong_vesting_amount');

    /// Check counts
    assert(token_vesting.get_vesting_schedules_count() == 1, 'wrong_vesting_schedules_count');
    assert(token_vesting.get_vesting_schedules_count_by_beneficiary(vested_user()) == 1, 'wrong_count');
}

#[test]
#[should_panic(expected: ('not_enough_vested_tokens',))]
fn test_cannot_release_more_than_releasable() {
    /// Deploy mock token and vesting contract.
    let (mock_token, token_vesting) = deploy_mock_and_token_vesting();

    /// Fund the vesting contract with tokens and set a vesting schedule for `vested_user`
    let duration = 1000_u256;
    fund_vesting_token(mock_token, token_vesting);
    create_schedule_for_holder(token_vesting, duration);

    // Get vesting ID for `vested_user` at index 0
    let vesting_schedule_id = token_vesting.compute_vesting_schedule_id_for_address_and_index(vested_user(), 0);

    // Increase time by 50% of the vesting duration.
    // User tries to release more than releasable, panics.
    start_warp(CheatTarget::One(token_vesting.contract_address), (duration / 2).try_into().unwrap());
    {
        start_prank(CheatTarget::One(token_vesting.contract_address), vested_user());
        assert(token_vesting.compute_releasable_amount(vesting_schedule_id) == 50, 'wrong_halftime_releasable');
        token_vesting.release(vesting_schedule_id, 100);
        stop_prank(CheatTarget::One(token_vesting.contract_address));
    }
    stop_warp(CheatTarget::One(token_vesting.contract_address));
}

#[test]
fn test_vests_tokens_gradually() {
    /// Deploy mock token and vesting contract.
    let (mock_token, token_vesting) = deploy_mock_and_token_vesting();

    /// Fund the vesting contract with tokens and set a vesting schedule for `vested_user`
    let duration = 1000_u256;
    fund_vesting_token(mock_token, token_vesting);
    create_schedule_for_holder(token_vesting, duration);

    // Get vesting ID for `vested_user` at index 0
    let vesting_schedule_id = token_vesting.compute_vesting_schedule_id_for_address_and_index(vested_user(), 0);

    // Increase time byt 50% of the vesting duration.
    start_warp(CheatTarget::One(token_vesting.contract_address), (duration / 2).try_into().unwrap());
    {
        // User releases 10 tokens.
        start_prank(CheatTarget::One(token_vesting.contract_address), vested_user());
        token_vesting.release(vesting_schedule_id, 10);
        // Check storage updates correctly.
        assert(mock_token.balanceOf(vested_user()) == 10, 'incorrect_user_balance');
        assert(token_vesting.compute_releasable_amount(vesting_schedule_id) == 40, 'wrong_new_releasable');
        assert(token_vesting.get_vesting_schedule(vesting_schedule_id).released == 10, 'vesting_schedule_didnt_update');
        stop_prank(CheatTarget::One(token_vesting.contract_address));
    }
    stop_warp(CheatTarget::One(token_vesting.contract_address));

    // Increase time 100% + 1 second
    start_warp(CheatTarget::One(token_vesting.contract_address), (duration + 1).try_into().unwrap());
    {
        /// Check releasable amount before release
        assert(token_vesting.compute_releasable_amount(vesting_schedule_id) == 90, 'wrong_vested_amount_before');

        /// Beneficiary releases 45 tokens
        start_prank(CheatTarget::One(token_vesting.contract_address), vested_user());
        token_vesting.release(vesting_schedule_id, 45);
        stop_prank(CheatTarget::One(token_vesting.contract_address));

        /// Check releasable amount after beneficiary release
        assert(mock_token.balanceOf(vested_user()) == 55, 'wrong_new_balance_55');
        assert(token_vesting.compute_releasable_amount(vesting_schedule_id) == 45, 'wrong_vested_amount_45');

        // Owner releases 45 vested tokens for beneficiary
        start_prank(CheatTarget::One(token_vesting.contract_address), admin());
        token_vesting.release(vesting_schedule_id, 45);
        stop_prank(CheatTarget::One(token_vesting.contract_address));

        /// Check releasable amount after owner release
        assert(mock_token.balanceOf(vested_user()) == 100, 'wrong_new_balance_100');
        assert(token_vesting.compute_releasable_amount(vesting_schedule_id) == 0, 'wrong_vested_amount_0');

        // Check vesting schedule updates  correctly
        assert(token_vesting.get_vesting_schedule(vesting_schedule_id).released == 100, 'released_should_be_max');
    }
    stop_warp(CheatTarget::One(token_vesting.contract_address));
}

#[test]
#[should_panic(expected: ('only_owner',))]
fn only_owner_can_revoke() {
    /// Deploy mock token and vesting contract.
    let (mock_token, token_vesting) = deploy_mock_and_token_vesting();

    /// Fund the vesting contract with tokens and set a vesting schedule for `vested_user`
    let duration = 1000_u256;
    fund_vesting_token(mock_token, token_vesting);
    create_schedule_for_holder(token_vesting, duration);

    let vesting_schedule_id = token_vesting.compute_vesting_schedule_id_for_address_and_index(vested_user(), 0);

    // Beneficiary revokes.
    start_prank(CheatTarget::One(token_vesting.contract_address), rando());
    token_vesting.revoke(vesting_schedule_id);
    stop_prank(CheatTarget::One(token_vesting.contract_address));
}

#[test]
fn test_should_release_tokens_if_revoked() {
    /// Deploy mock token and vesting contract.
    let (mock_token, token_vesting) = deploy_mock_and_token_vesting();

    /// Fund the vesting contract with tokens and set a vesting schedule for `vested_user`
    let duration = 1000_u256;
    fund_vesting_token(mock_token, token_vesting);
    create_schedule_for_holder(token_vesting, duration);

    let vesting_schedule_id = token_vesting.compute_vesting_schedule_id_for_address_and_index(vested_user(), 0);

    // Increase time byt 50% of the vesting duration.
    start_warp(CheatTarget::One(token_vesting.contract_address), (duration / 2).try_into().unwrap());
    {
        // Owner revokes beneficiarys tokens, releasing the amount up to now
        start_prank(CheatTarget::One(token_vesting.contract_address), admin());
        token_vesting.revoke(vesting_schedule_id);
        stop_prank(CheatTarget::One(token_vesting.contract_address));
    }
    stop_warp(CheatTarget::One(token_vesting.contract_address));

    assert(token_vesting.get_vesting_schedule(vesting_schedule_id).revoked, 'not_revoked');
    assert(mock_token.balanceOf(vested_user()) == 50, 'beneficiary_no_receive_tokens')
}

/// ID 0 for vested_user: 2861464285068197485634434631575674888643713143111203583297985950701137739193
#[test]
fn computes_vesting_schedule_ids_correctly() {
    /// Deploy mock token and vesting contract.
    let (mock_token, token_vesting) = deploy_mock_and_token_vesting();
    /// Fund the vesting contract with tokens and set a vesting schedule for `vested_user`
    fund_vesting_token(mock_token, token_vesting);
    let duration = 1000_u256;

    /// vesting schedule 0
    let expected_schedule_id = token_vesting.compute_next_vesting_schedule_id_for_holder(vested_user());
    create_schedule_for_holder(token_vesting, duration);
    let vesting_schedule_id = token_vesting.compute_vesting_schedule_id_for_address_and_index(vested_user(), 0);

    assert(expected_schedule_id == vesting_schedule_id, 'wrong_expected_id');

    /// vesting schedule 1
    let expected_schedule_id_b = token_vesting.compute_next_vesting_schedule_id_for_holder(vested_user());
    create_schedule_for_holder(token_vesting, duration);
    let vesting_schedule_id_b = token_vesting.compute_vesting_schedule_id_for_address_and_index(vested_user(), 1);

    assert(expected_schedule_id_b == vesting_schedule_id_b, 'wrong_expected_id_b');

    /// vesting schedule at index 4
    let vesting_schedule_id_e = token_vesting.compute_vesting_schedule_id_for_address_and_index(vested_user(), 4);
    create_schedule_for_holder(token_vesting, duration);
    create_schedule_for_holder(token_vesting, duration);

    /// Compute 4
    let expected_schedule_id_e = token_vesting.compute_next_vesting_schedule_id_for_holder(vested_user());
    create_schedule_for_holder(token_vesting, duration);

    assert(token_vesting.get_vesting_schedules_count_by_beneficiary(vested_user()) == 5, 'wrong_count');
    assert(vesting_schedule_id_e == expected_schedule_id_e, 'wrong_last_vesting_id');
}

#[test]
#[should_panic(expected: ('duration_cant_be_zero',))]
fn create_schedule_duration_cant_be_zero() {
    /// Deploy mock token and vesting contract.
    let (mock_token, token_vesting) = deploy_mock_and_token_vesting();
    /// Fund the vesting contract with tokens and set a vesting schedule for `vested_user`
    fund_vesting_token(mock_token, token_vesting);

    let duration = 0;

    /// Default
    let base_time = 0;
    let beneficiary = vested_user();
    let start_time = base_time;
    let cliff = 0;
    let slice_period_seconds = 1;
    let revokable = true;
    let amount = 100;

    /// Create vesting schedule
    start_prank(CheatTarget::One(token_vesting.contract_address), admin());
    token_vesting
        .create_vesting_schedule(beneficiary, start_time, cliff, duration, slice_period_seconds, revokable, amount);
    stop_prank(CheatTarget::One(token_vesting.contract_address));
}

#[test]
#[should_panic(expected: ('slice_periods_is_zero',))]
fn create_schedule_slice_periods_cant_be_zero() {
    /// Deploy mock token and vesting contract.
    let (mock_token, token_vesting) = deploy_mock_and_token_vesting();
    /// Fund the vesting contract with tokens and set a vesting schedule for `vested_user`
    fund_vesting_token(mock_token, token_vesting);

    let duration = 1000;

    /// Default
    let base_time = 0;
    let beneficiary = vested_user();
    let start_time = base_time;
    let cliff = 0;
    let slice_period_seconds = 0;
    let revokable = true;
    let amount = 100;

    /// Create vesting schedule
    start_prank(CheatTarget::One(token_vesting.contract_address), admin());
    token_vesting
        .create_vesting_schedule(beneficiary, start_time, cliff, duration, slice_period_seconds, revokable, amount);
    stop_prank(CheatTarget::One(token_vesting.contract_address));
}

#[test]
#[should_panic(expected: ('cant_vest_zero_amount',))]
fn create_schedule_cant_vest_zero_amount() {
    /// Deploy mock token and vesting contract.
    let (mock_token, token_vesting) = deploy_mock_and_token_vesting();
    /// Fund the vesting contract with tokens and set a vesting schedule for `vested_user`
    fund_vesting_token(mock_token, token_vesting);

    let duration = 1000;

    /// Default
    let base_time = 0;
    let beneficiary = vested_user();
    let start_time = base_time;
    let cliff = 0;
    let slice_period_seconds = 1;
    let revokable = true;
    let amount = 0;

    /// Create vesting schedule
    start_prank(CheatTarget::One(token_vesting.contract_address), admin());
    token_vesting
        .create_vesting_schedule(beneficiary, start_time, cliff, duration, slice_period_seconds, revokable, amount);
    stop_prank(CheatTarget::One(token_vesting.contract_address));
}


/// ---------------------------------------------------------------------------------------------- ///
///                                           TEST SETUP                                           ///
/// ---------------------------------------------------------------------------------------------- ///

fn deploy_mock_token() -> ICamelERC20MockDispatcher {
    /// Declare mock
    let contract = declare('CamelERC20Mock');
    /// ERC20 Constructor = { name: felt252, symbol: felt252, initial_supply: u256, recipient: ContractAddress }
    /// Note the initial_supply is a u256, so we pass 2 params for `initial_supply`: 
    /// uint256.low = INITIAL_SUPPLY, uint256.high = 0
    let constructor_calldata = array![NAME, SYMBOL, INITIAL_SUPPLY.try_into().unwrap(), 0, admin().into()];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    ICamelERC20MockDispatcher { contract_address }
}

fn deploy_mock_and_token_vesting() -> (ICamelERC20MockDispatcher, ITokenVestingDispatcher) {
    /// Deploy token
    let token = deploy_mock_token();
    /// Declare mock
    let contract = declare('CamelTokenVesting');
    /// TokenVesting Constructor = { admin: ContractAddress, token: ContractAddress }
    let constructor_calldata = array![admin().into(), token.contract_address.into()];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    let token_vesting = ITokenVestingDispatcher { contract_address };

    (token, token_vesting)
}

fn fund_vesting_token(mock_token: ICamelERC20MockDispatcher, token_vesting: ITokenVestingDispatcher) {
    /// Transfer all supply to the vester (1000 tokens)
    start_prank(CheatTarget::One(mock_token.contract_address), admin());
    mock_token.transfer(token_vesting.contract_address, INITIAL_SUPPLY);
    stop_prank(CheatTarget::One(mock_token.contract_address));
}

fn create_schedule_for_holder(token_vesting: ITokenVestingDispatcher, duration: u256) {
    /// Default
    let base_time = 0;
    let beneficiary = vested_user();
    let start_time = base_time;
    let cliff = 0;
    let slice_period_seconds = 1;
    let revokable = true;
    let amount = 100;

    /// Create vesting schedule
    start_prank(CheatTarget::One(token_vesting.contract_address), admin());
    token_vesting
        .create_vesting_schedule(beneficiary, start_time, cliff, duration, slice_period_seconds, revokable, amount);
    stop_prank(CheatTarget::One(token_vesting.contract_address));
}

/// ---------------------------------------------------------------------------------------------- ///
///                                           TEST USERS                                           ///
/// ---------------------------------------------------------------------------------------------- ///

fn admin() -> ContractAddress {
    0x666.try_into().unwrap()
}

fn rando() -> ContractAddress {
    0x1332.try_into().unwrap()
}

fn vested_user() -> ContractAddress {
    0x1998.try_into().unwrap()
}
